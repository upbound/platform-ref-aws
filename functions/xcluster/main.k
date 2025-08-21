
import models.io.upbound.platform.aws.v1alpha1 as awsplatformv1alpha1
import models.io.upbound.platform.observe.v1alpha1 as observev1alpha1
import models.io.upbound.platform.gitops.v1alpha1 as gitopsv1alpha1

oxr = option("params").oxr
_ocds = option("params").ocds
_dxr = option("params").dxr
dcds = option("params").dcds

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# Extract parameters from the observed XR
id = oxr.spec?.parameters?.id
region = oxr.spec?.parameters?.region
version = oxr.spec?.parameters?.version
nodes = oxr.spec?.parameters?.nodes
iam = oxr.spec?.parameters?.iam
deletionPolicy = oxr.spec?.parameters?.deletionPolicy
providerConfigName = oxr.spec?.parameters?.providerConfigName
operators = oxr.spec?.parameters?.operators
gitops = oxr.spec?.parameters?.gitops
uid = oxr.metadata?.uid

# Connection secret name
connectionSecretName = id + "-eks"

# Try to get VPC ID from observed XNetwork status
_observedVpcId = _ocds?["XNetwork"]?.Resource?.status?.vpcId

# Check if XEKS is ready before creating any Helm releases (they all need kubeconfig)
_eksReadyCondition = [condition for condition in (_ocds?["XEKS"]?.Resource?.status?.conditions or []) if condition.type == "Ready" and condition.status == "True"]
_isEksReady = len(_eksReadyCondition) > 0

# Check if XAWSLBController already exists (safety check to prevent uninstalling)
_lbControllerExists = "XAWSLBController" in _ocds

# Check if XAWSLBController is ready before creating Flux and OSS (to avoid webhook conflicts)
_lbControllerReadyCondition = [condition for condition in (_ocds?["XAWSLBController"]?.Resource?.status?.conditions or []) if condition.type == "Ready" and condition.status == "True"]
_isLbControllerReady = len(_lbControllerReadyCondition) > 0

# Check if dependent resources already exist (safety checks to prevent uninstalling)
_ossExists = "XOss" in _ocds
_fluxExists = "XFlux" in _ocds

# Generate region-specific availability zones for subnets
_regionAzMap = {
    "us-east-1": ["us-east-1a", "us-east-1b"]
    "us-east-2": ["us-east-2a", "us-east-2b"]
    "us-west-1": ["us-west-1a", "us-west-1c"]
    "us-west-2": ["us-west-2a", "us-west-2b"]
    "eu-west-1": ["eu-west-1a", "eu-west-1b"]
    "eu-west-2": ["eu-west-2a", "eu-west-2b"]
    "eu-central-1": ["eu-central-1a", "eu-central-1b"]
    "ap-southeast-1": ["ap-southeast-1a", "ap-southeast-1b"]
    "ap-southeast-2": ["ap-southeast-2a", "ap-southeast-2b"]
    "ap-northeast-1": ["ap-northeast-1a", "ap-northeast-1c"]
    "ca-central-1": ["ca-central-1a", "ca-central-1b"]
}

_availabilityZones = _regionAzMap[region] if region in _regionAzMap else ["us-west-2a", "us-west-2b"]

# Generate subnets configuration based on the region's availability zones
_regionSpecificSubnets = [
    {
        availabilityZone = _availabilityZones[0]
        type = "public"
        cidrBlock = "192.168.0.0/18"
    }
    {
        availabilityZone = _availabilityZones[1]
        type = "public"
        cidrBlock = "192.168.64.0/18"
    }
    {
        availabilityZone = _availabilityZones[0]
        type = "private"
        cidrBlock = "192.168.128.0/18"
    }
    {
        availabilityZone = _availabilityZones[1]
        type = "private"
        cidrBlock = "192.168.192.0/18"
    }
]

_items = [
    # XNetwork resource
    awsplatformv1alpha1.XNetwork {
        metadata: _metadata("XNetwork") | {
            name = id + "-network"
        }
        spec: {
            parameters: {
                id = id
                region = region
                deletionPolicy = deletionPolicy
                providerConfigName = providerConfigName
                subnets = _regionSpecificSubnets
            }
        }
    }

    # XEKS resource
    awsplatformv1alpha1.XEKS {
        metadata: _metadata("XEKS") | {
            name = id + "-eks"
            labels: {
                "platform.upbound.io/deletion-ordering" = oxr.metadata?.labels?["platform.upbound.io/deletion-ordering"]
            }
            annotations: {
                "crossplane.io/external-name" = id
            }
        }
        spec: {
            parameters: {
                id = id
                region = region
                deletionPolicy = deletionPolicy
                providerConfigName = providerConfigName
                version = version
                nodes = nodes
            } | ({iam = iam} if iam else {})
            writeConnectionSecretToRef: {
                name = connectionSecretName
                namespace = "crossplane-system"
            }
        }
    }

    # XAWSLBController resource - only create when XEKS is ready (needs kubeconfig secret)
    # Also create if it already exists to prevent uninstalling
    if _isEksReady or _lbControllerExists:
        awsplatformv1alpha1.XAWSLBController {
            metadata: _metadata("XAWSLBController") | {
                name = id + "-lb-controller"
            }
            spec: {
                parameters: {
                    providerConfigName = providerConfigName
                    deletionPolicy = deletionPolicy
                    helm: {
                        providerConfigName = id
                    }
                    region = region
                    clusterNameSelector = {
                        matchLabels = {
                            "crossplane.io/claim-name" = id
                        } if oxr.spec?.claimRef?.name else {
                            "crossplane.io/composite" = id
                        }
                    }
                    # Pass VPC ID if available to avoid EC2 metadata discovery
                    if _observedVpcId:
                        vpcId = _observedVpcId
                }
            }
        }

    # XOss resource - only create when LB Controller is ready (to avoid webhook conflicts)
    # Also create if it already exists to prevent uninstalling
    if _isLbControllerReady or _ossExists:
        observev1alpha1.XOss {
            metadata: _metadata("XOss") | {
                name = id + "-oss"
            }
            spec: {
                parameters: {
                    deletionPolicy = deletionPolicy
                    id = id
                    operators: {
                        prometheus = operators?.prometheus
                    }
                }
            }
        }

    # XFlux resource - only create when LB Controller is ready (to avoid webhook conflicts)
    # Also create if it already exists to prevent uninstalling
    if _isLbControllerReady or _fluxExists:
        gitopsv1alpha1.XFlux {
            metadata: _metadata("XFlux") | {
                name = id + "-flux"
            }
            spec: {
                parameters: {
                    deletionPolicy = deletionPolicy
                    providerConfigName = id
                    operators: {
                        flux = operators?.flux
                        fluxSync = operators?.fluxSync
                    }
                    source = gitops
                }
            }
        }

    # Usage resources for dependency management (untyped objects)
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usageXNetworkByXEKS") | {
            name = id + "-network-by-eks"
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "XEKS"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
            of: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "XNetwork"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }

    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usageXEksByXFlux") | {
            name = id + "-eks-by-flux"
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion = "gitops.platform.upbound.io/v1alpha1"
                kind = "XFlux"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
            of: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "XEKS"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }

    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usageXEksByXOss") | {
            name = id + "-eks-by-oss"
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion = "observe.platform.upbound.io/v1alpha1"
                kind = "XOss"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
            of: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "XEKS"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }
    
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usageXEksByArbitraryLabeledRelease") | {
            name = id + "-eks-by-labeled-release"
            annotations = {
                "krm.kcl.dev/ready": "True"
            }
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion = "helm.crossplane.io/v1beta1"
                kind = "Release"
                resourceSelector: {
                    matchLabels: {
                        "platform.upbound.io/deletion-ordering" = "enabled"
                    }
                }
            }
            of: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "XEKS"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }
    
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usageXAWSLBControllerByArbitraryLabeledApp") | {
            name = id + "-lb-controller-by-labeled-app"
            annotations = {
                "krm.kcl.dev/ready": "True"
            }
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion = "platform.upbound.io/v1alpha1"
                kind = "XApp"
                resourceSelector: {
                    matchLabels: {
                        "platform.upbound.io/deletion-ordering" = "enabled"
                    }
                }
            }
            of: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "XAWSLBController"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }
    
    # Usage resource to ensure XFlux is deleted before XAWSLBController
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usageXAWSLBControllerByXFlux") | {
            name = id + "-lb-controller-by-flux"
            annotations = {
                "krm.kcl.dev/ready": "True"
            }
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion: "gitops.platform.upbound.io/v1alpha1"
                kind: "XFlux"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
            of: {
                apiVersion: "aws.platform.upbound.io/v1alpha1"
                kind: "XAWSLBController"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }

    # Forward connection details from XEKS
    {
        apiVersion: "meta.krm.kcl.dev/v1alpha1"
        kind: "CompositeConnectionDetails"
        if "XEKS" in _ocds:
            data: {
                kubeconfig = _ocds["XEKS"].ConnectionDetails.kubeconfig
            }
        else:
            data: {}
    }
]

items = _items
