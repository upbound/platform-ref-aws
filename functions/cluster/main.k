
import models.io.upbound.platform.aws.v1alpha1 as awsplatformv1alpha1
import models.io.upbound.platform.observe.v1alpha1 as observev1alpha1
import models.io.upbound.platform.gitops.v1alpha1 as gitopsv1alpha1

oxr = option("params").oxr
_ocds = option("params").ocds
_dxr = option("params").dxr
dcds = option("params").dcds

params = oxr.spec.parameters
uid = oxr.metadata?.uid

_defaults = {
    managementPolicies = params.managementPolicies or ["*"]
    providerConfigName = params.providerConfigName
}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# Connection secret name
connectionSecretName = params.id + "-eks"

# Try to get VPC ID from observed Network status
_observedVpcId = _ocds?["Network"]?.Resource?.status?.vpcId

# Check if EKS is ready before creating any Helm releases (they all need kubeconfig)
_eksReadyCondition = [condition for condition in (_ocds?["EKS"]?.Resource?.status?.conditions or []) if condition.type == "Ready" and condition.status == "True"]
_isEksReady = len(_eksReadyCondition) > 0

# Check if AWSLBController already exists (safety check to prevent uninstalling)
_lbControllerExists = "AWSLBController" in _ocds

# Check if AWSLBController is ready before creating Flux and OSS (to avoid webhook conflicts)
_lbControllerReadyCondition = [condition for condition in (_ocds?["AWSLBController"]?.Resource?.status?.conditions or []) if condition.type == "Ready" and condition.status == "True"]
_isLbControllerReady = len(_lbControllerReadyCondition) > 0

# Check if dependent resources already exist (safety checks to prevent uninstalling)
_ossExists = "Oss" in _ocds
_fluxExists = "Flux" in _ocds

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

_availabilityZones = _regionAzMap[params.region] if params.region in _regionAzMap else ["us-west-2a", "us-west-2b"]

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
    # Network resource
    awsplatformv1alpha1.Network {
        metadata: _metadata("Network") | {
            name = params.id + "-network"
        }
        spec: {
            parameters: _defaults | {
                id = params.id
                region = params.region
                subnets = _regionSpecificSubnets
            }
        }
    }

    # EKS resource
    awsplatformv1alpha1.EKS {
        metadata: _metadata("EKS") | {
            name = params.id + "-eks"
            labels: {
                "platform.upbound.io/deletion-ordering" = oxr.metadata?.labels?["platform.upbound.io/deletion-ordering"]
            }
            annotations: {
                "crossplane.io/external-name" = params.id
            }
        }
        spec: {
            parameters: _defaults | {
                id = params.id
                region = params.region
                version = params.version
                nodes = params.nodes
            } | ({iam = params.iam} if params.iam else {})
        }
    }

    # AWSLBController resource - only create when EKS is ready (needs kubeconfig secret)
    # Also create if it already exists to prevent uninstalling
    if _isEksReady or _lbControllerExists:
        awsplatformv1alpha1.AWSLBController {
            metadata: _metadata("AWSLBController") | {
                name = params.id + "-lb-controller"
            }
            spec: {
                parameters: {
                    providerConfigName = params.providerConfigName
                    helm: {
                        providerConfigName = params.id
                    }
                    region = params.region
                    clusterNameSelector = {
                        matchLabels = {
                            "crossplane.io/claim-name" = params.id
                        } if oxr.spec?.claimRef?.name else {
                            "crossplane.io/composite" = params.id
                        }
                    }
                    # Pass VPC ID if available to avoid EC2 metadata discovery
                    if _observedVpcId:
                        vpcId = _observedVpcId
                    managementPolicies = params.managementPolicies or ["*"]
                }
            }
        }

    # Oss resource - only create when LB Controller is ready (to avoid webhook conflicts)
    # Also create if it already exists to prevent uninstalling
    if _isLbControllerReady or _ossExists:
        observev1alpha1.Oss {
            metadata: _metadata("Oss") | {
                name = params.id + "-oss"
            }
            spec: {
                parameters: {
                    id = params.id
                    operators: {
                        prometheus = params.operators?.prometheus
                    }
                    managementPolicies = params.managementPolicies or ["*"]
                }
            }
        }

    # Flux resource - only create when LB Controller is ready (to avoid webhook conflicts)
    # Also create if it already exists to prevent uninstalling
    if _isLbControllerReady or _fluxExists:
        gitopsv1alpha1.Flux {
            metadata: _metadata("Flux") | {
                name = params.id + "-flux"
            }
            spec: {
                parameters: _defaults | {
                    providerConfigName = params.id
                    operators: {
                        flux = params.operators?.flux
                        fluxSync = params.operators?.fluxSync
                    }
                    source = params.gitops
                }
            }
        }

    # Usage resources for dependency management (untyped objects)
    {
        apiVersion: "protection.crossplane.io/v1beta1"
        kind: "Usage"
        metadata: _metadata("usageXNetworkByEKS") | {
            name = params.id + "-network-by-eks"
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "EKS"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
            of: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "Network"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }

    {
        apiVersion: "protection.crossplane.io/v1beta1"
        kind: "Usage"
        metadata: _metadata("usageXEksByFlux") | {
            name = params.id + "-eks-by-flux"
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion = "gitops.platform.upbound.io/v1alpha1"
                kind = "Flux"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
            of: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "EKS"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }

    {
        apiVersion: "protection.crossplane.io/v1beta1"
        kind: "Usage"
        metadata: _metadata("usageXEksByOss") | {
            name = params.id + "-eks-by-oss"
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion = "observe.platform.upbound.io/v1alpha1"
                kind = "Oss"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
            of: {
                apiVersion = "aws.platform.upbound.io/v1alpha1"
                kind = "EKS"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }
    
    {
        apiVersion: "protection.crossplane.io/v1beta1"
        kind: "Usage"
        metadata: _metadata("usageEksByArbitraryLabeledRelease") | {
            name = params.id + "-eks-by-labeled-release"
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
                kind = "EKS"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }
    
    {
        apiVersion: "protection.crossplane.io/v1beta1"
        kind: "Usage"
        metadata: _metadata("usageAWSLBControllerByArbitraryLabeledApp") | {
            name = params.id + "-lb-controller-by-labeled-app"
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
                kind = "AWSLBController"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }
    
    # Usage resource to ensure Flux is deleted before AWSLBController
    {
        apiVersion: "protection.crossplane.io/v1beta1"
        kind: "Usage"
        metadata: _metadata("usageAWSLBControllerByFlux") | {
            name = params.id + "-lb-controller-by-flux"
            annotations = {
                "krm.kcl.dev/ready": "True"
            }
        }
        spec: {
            replayDeletion = True
            by: {
                apiVersion: "gitops.platform.upbound.io/v1alpha1"
                kind: "Flux"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
            of: {
                apiVersion: "aws.platform.upbound.io/v1alpha1"
                kind: "AWSLBController"
                resourceSelector: {
                    matchControllerRef = True
                }
            }
        }
    }

    # Forward connection details from EKS
    {
        apiVersion: "meta.krm.kcl.dev/v1alpha1"
        kind: "CompositeConnectionDetails"
        if "EKS" in _ocds:
            data: {
                kubeconfig = _ocds["EKS"].ConnectionDetails.kubeconfig
            }
        else:
            data: {}
    }
]

items = _items
