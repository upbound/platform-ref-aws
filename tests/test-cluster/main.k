
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.aws.v1alpha1 as awsplatformv1alpha1
import models.io.upbound.platform.observe.v1alpha1 as observev1alpha1
import models.io.upbound.platform.gitops.v1alpha1 as gitopsv1alpha1
import models.io.upbound.platformref.aws.v1alpha1 as platformrefawsv1alpha1

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-xcluster"
        spec = {
            assertResources: [
                # XCluster for main composite resource
                platformrefawsv1alpha1.XCluster{
                    metadata.name: "platform-ref-aws"
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            version: "1.32"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            nodes = {
                                count: 3
                                instanceType: "t3.small"
                            }
                            operators = {
                                flux = {
                                    version: "2.10.6"
                                }
                                fluxSync = {
                                    version: "1.7.2"
                                }
                                prometheus = {
                                    version: "52.1.0"
                                }
                            }
                            gitops = {
                                git = {
                                    interval: "5m0s"
                                    timeout: "60s"
                                    url: "https://github.com/upbound/platform-ref-aws/"
                                    path: "/"
                                    ref = {
                                        name: "refs/heads/main"
                                    }
                                }
                            }
                        }
                    }
                }
                # XNetwork for AWS networking
                awsplatformv1alpha1.XNetwork{
                    metadata.name: "platform-ref-aws-network"
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            subnets = [
                                {
                                    availabilityZone = "us-west-2a"
                                    type = "public"
                                    cidrBlock = "192.168.0.0/18"
                                }
                                {
                                    availabilityZone = "us-west-2b"
                                    type = "public"
                                    cidrBlock = "192.168.64.0/18"
                                }
                                {
                                    availabilityZone = "us-west-2a"
                                    type = "private"
                                    cidrBlock = "192.168.128.0/18"
                                }
                                {
                                    availabilityZone = "us-west-2b"
                                    type = "private"
                                    cidrBlock = "192.168.192.0/18"
                                }
                            ]
                        }
                    }
                },
                # XEKS for Amazon EKS
                awsplatformv1alpha1.XEKS{
                    metadata = {
                        name: "platform-ref-aws-eks"
                        labels = {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                        annotations = {
                            "crossplane.io/external-name": "platform-ref-aws"
                        }
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            version: "1.32"
                            nodes = {
                                count: 3
                                instanceType: "t3.small"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "platform-ref-aws-eks"
                            namespace: "crossplane-system"
                        }
                    }
                },
                # XOss for observability stack
                observev1alpha1.XOss{
                    metadata.name: "platform-ref-aws-oss"
                    spec = {
                        parameters = {
                            deletionPolicy: "Delete"
                            id: "platform-ref-aws"
                            operators = {
                                prometheus = {
                                    version: "52.1.0"
                                }
                            }
                        }
                    }
                },
                # XFlux for GitOps
                gitopsv1alpha1.XFlux{
                    metadata.name: "platform-ref-aws-flux"
                    spec = {
                        parameters = {
                            deletionPolicy: "Delete"
                            providerConfigName: "platform-ref-aws"
                            operators = {
                                flux = {
                                    version: "2.10.6"
                                }
                                fluxSync = {
                                    version: "1.7.2"
                                }
                            }
                            source = {
                                git = {
                                    interval: "5m0s"
                                    timeout: "60s"
                                    url: "https://github.com/upbound/platform-ref-aws/"
                                    path: "/"
                                    ref = {
                                        name: "refs/heads/main"
                                    }
                                }
                            }
                        }
                    }
                },
                # XAWSLBController for Load Balancer Controller
                awsplatformv1alpha1.XAWSLBController{
                    metadata.name: "platform-ref-aws-lb-controller"
                    spec = {
                        parameters = {
                            providerConfigName: "default"
                            deletionPolicy: "Delete"
                            helm = {
                                providerConfigName: "platform-ref-aws"
                            }
                            region: "us-west-2"
                            clusterNameSelector = {
                                matchLabels = {
                                    "crossplane.io/composite" = "platform-ref-aws"
                                }
                            }
                            vpcId: "vpc-test123"
                        }
                    }
                },
                # Usage resources for dependency management (untyped objects)
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-network-by-eks"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "XEKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "XNetwork"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-eks-by-flux"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "gitops.platform.upbound.io/v1alpha1"
                            kind: "XFlux"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "XEKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-eks-by-oss"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "observe.platform.upbound.io/v1alpha1"
                            kind: "XOss"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "XEKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-eks-by-labeled-release"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "helm.crossplane.io/v1beta1"
                            kind: "Release"
                            resourceSelector = {
                                matchLabels = {
                                    "platform.upbound.io/deletion-ordering": "enabled"
                                }
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "XEKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-lb-controller-by-labeled-app"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "platform.upbound.io/v1alpha1"
                            kind: "XApp"
                            resourceSelector = {
                                matchLabels = {
                                    "platform.upbound.io/deletion-ordering": "enabled"
                                }
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "XAWSLBController"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-lb-controller-by-flux"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "gitops.platform.upbound.io/v1alpha1"
                            kind: "XFlux"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "XAWSLBController"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                }
            ]
            observedResources: [
                # XNetwork with VPC ID in status
                awsplatformv1alpha1.XNetwork{
                    metadata = {
                        name: "platform-ref-aws-network"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "XNetwork"
                        }
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            subnets = [
                                {
                                    availabilityZone = "us-west-2a"
                                    type = "public"
                                    cidrBlock = "192.168.0.0/18"
                                }
                                {
                                    availabilityZone = "us-west-2b"
                                    type = "public"
                                    cidrBlock = "192.168.64.0/18"
                                }
                                {
                                    availabilityZone = "us-west-2a"
                                    type = "private"
                                    cidrBlock = "192.168.128.0/18"
                                }
                                {
                                    availabilityZone = "us-west-2b"
                                    type = "private"
                                    cidrBlock = "192.168.192.0/18"
                                }
                            ]
                        }
                        compositionSelector = {
                            matchLabels = {
                                type: "basic"
                            }
                        }
                    }
                    status = {
                        vpcId: "vpc-test123"
                    }
                },
                # XFlux with Ready condition to trigger XAWSLBController creation
                gitopsv1alpha1.XFlux{
                    metadata = {
                        name: "platform-ref-aws-flux"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "XFlux"
                        }
                    }
                    spec = {
                        parameters = {
                            deletionPolicy: "Delete"
                            providerConfigName: "platform-ref-aws"
                            operators = {
                                flux = {
                                    version: "2.10.6"
                                }
                                fluxSync = {
                                    version: "1.7.2"
                                }
                            }
                            source = {
                                git = {
                                    interval: "5m0s"
                                    timeout: "60s"
                                    url: "https://github.com/upbound/platform-ref-aws/"
                                    path: "/"
                                    ref = {
                                        name: "refs/heads/main"
                                    }
                                }
                            }
                        }
                    }
                    status = {
                        conditions = [
                            {
                                type = "Ready"
                                status = "True"
                                reason = "Available"
                                lastTransitionTime = "2025-08-13T22:30:00Z"
                            }
                        ]
                    }
                },
                # XEKS with Ready condition to trigger all Helm releases creation
                awsplatformv1alpha1.XEKS{
                    metadata = {
                        name: "platform-ref-aws-eks"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "XEKS"
                        }
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            version: "1.32"
                            nodes = {
                                count: 3
                                instanceType: "t3.small"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "platform-ref-aws-eks"
                            namespace: "crossplane-system"
                        }
                    }
                    status = {
                        conditions = [
                            {
                                type = "Ready"
                                status = "True"
                                reason = "Available"
                                lastTransitionTime = "2025-08-13T23:00:00Z"
                            }
                        ]
                        eks = {
                            clusterName: "platform-ref-aws-cluster"
                        }
                    }
                },
                # XAWSLBController with Ready condition to trigger Flux and OSS creation
                awsplatformv1alpha1.XAWSLBController{
                    metadata = {
                        name: "platform-ref-aws-lb-controller"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "XAWSLBController"
                        }
                    }
                    spec = {
                        parameters = {
                            providerConfigName: "default"
                            deletionPolicy: "Delete"
                            helm = {
                                providerConfigName: "platform-ref-aws"
                            }
                            region: "us-west-2"
                            clusterNameSelector = {
                                matchLabels = {
                                    "crossplane.io/composite" = "platform-ref-aws"
                                }
                            }
                            vpcId: "vpc-test123"
                        }
                    }
                    status = {
                        conditions = [
                            {
                                type = "Ready"
                                status = "True"
                                reason = "Available"
                                lastTransitionTime = "2025-08-13T23:15:00Z"
                            }
                        ]
                    }
                }
            ]
            compositionPath: "apis/composition.yaml"
            xrPath: "examples/xcluster.yaml"
            xrdPath: "apis/definition.yaml"
            timeoutSeconds: 120
            validate: False
        }
    }
]
items = _items
