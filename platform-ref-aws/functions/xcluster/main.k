
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
_id = oxr.spec?.parameters?.id
_region = oxr.spec?.parameters?.region
_version = oxr.spec?.parameters?.version
_nodes = oxr.spec?.parameters?.nodes
_iam = oxr.spec?.parameters?.iam
_networkSelector = oxr.spec?.parameters?.networkSelector
_deletionPolicy = oxr.spec?.parameters?.deletionPolicy
_providerConfigName = oxr.spec?.parameters?.providerConfigName
_operators = oxr.spec?.parameters?.operators
_gitops = oxr.spec?.parameters?.gitops
_uid = oxr.metadata?.uid

# Connection secret name
_connectionSecretName = _id + "-eks"

# Try to get VPC ID from observed XNetwork status
_observedVpcId = _ocds?["XNetwork"]?.Resource?.status?.vpcId

# Check if XEKS is ready before creating any Helm releases (they all need kubeconfig)
_eksReadyCondition = [condition for condition in (_ocds?["XEKS"]?.Resource?.status?.conditions or []) if condition.type == "Ready" and condition.status == "True"]
_isEksReady = len(_eksReadyCondition) > 0

# Check if XAWSLBController is ready before creating Flux and OSS (to avoid webhook conflicts)
_lbControllerReadyCondition = [condition for condition in (_ocds?["XAWSLBController"]?.Resource?.status?.conditions or []) if condition.type == "Ready" and condition.status == "True"]
_isLbControllerReady = len(_lbControllerReadyCondition) > 0

_items = [
    # XNetwork resource
    awsplatformv1alpha1.XNetwork {
        metadata: _metadata("XNetwork") | {
            name = _id + "-network"
        }
        spec: {
            parameters: {
                id = _id
                region = _region
                deletionPolicy = _deletionPolicy
                providerConfigName = _providerConfigName
            }
        }
    }

    # XEKS resource
    awsplatformv1alpha1.XEKS {
        metadata: _metadata("XEKS") | {
            name = _id + "-eks"
            labels: {
                "platform.upbound.io/deletion-ordering" = oxr.metadata?.labels?["platform.upbound.io/deletion-ordering"]
            }
            annotations: {
                "crossplane.io/external-name" = _id
            }
        }
        spec: {
            parameters: {
                id = _id
                region = _region
                deletionPolicy = _deletionPolicy
                providerConfigName = _providerConfigName
                version = _version
                nodes = _nodes
            } | ({iam = _iam} if _iam else {})
            writeConnectionSecretToRef: {
                name = _connectionSecretName
                namespace = "crossplane-system"
            }
        }
    }

    # XAWSLBController resource - only create when XEKS is ready (needs kubeconfig secret)
    if _isEksReady:
        awsplatformv1alpha1.XAWSLBController {
            metadata: _metadata("XAWSLBController") | {
                name = _id + "-lb-controller"
            }
            spec: {
                parameters: {
                    providerConfigName = _providerConfigName
                    deletionPolicy = _deletionPolicy
                    helm: {
                        providerConfigName = _id
                    }
                    region = _region
                    clusterNameSelector = {
                        matchLabels = {
                            "crossplane.io/claim-name" = _id
                        } if oxr.spec?.claimRef?.name else {
                            "crossplane.io/composite" = _id
                        }
                    }
                    # Pass VPC ID if available to avoid EC2 metadata discovery
                    if _observedVpcId:
                        vpcId = _observedVpcId
                }
            }
        }

    # XOss resource - only create when LB Controller is ready (to avoid webhook conflicts)
    if _isLbControllerReady:
        observev1alpha1.XOss {
            metadata: _metadata("XOss") | {
                name = _id + "-oss"
            }
            spec: {
                parameters: {
                    deletionPolicy = _deletionPolicy
                    id = _id
                    operators: {
                        prometheus = _operators?.prometheus
                    }
                }
            }
        }

    # XFlux resource - only create when LB Controller is ready (to avoid webhook conflicts)
    if _isLbControllerReady:
        gitopsv1alpha1.XFlux {
            metadata: _metadata("XFlux") | {
                name = _id + "-flux"
            }
            spec: {
                parameters: {
                    deletionPolicy = _deletionPolicy
                    providerConfigName = _id
                    operators: {
                        flux = _operators?.flux
                        fluxSync = _operators?.fluxSync
                    }
                    source = _gitops
                }
            }
        }
    
    # Usage resources for dependency management (untyped objects)
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usageXNetworkByXEKS") | {
            name = _id + "-network-by-eks"
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
            name = _id + "-eks-by-flux"
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
            name = _id + "-eks-by-oss"
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
            name = _id + "-eks-by-labeled-release"
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
            name = _id + "-lb-controller-by-labeled-app"
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
            name = _id + "-lb-controller-by-flux"
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
