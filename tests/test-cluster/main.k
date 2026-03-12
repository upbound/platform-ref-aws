
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.aws.v1alpha1 as awsplatformv1alpha1
import models.io.upbound.platform.observe.v1alpha1 as observev1alpha1
import models.io.upbound.platform.gitops.v1alpha1 as gitopsv1alpha1
import models.io.upbound.platformref.aws.v1alpha1 as platformrefawsv1alpha1

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-cluster"
        spec = {
            assertResources: [
                # Cluster for main composite resource
                platformrefawsv1alpha1.Cluster{
                    metadata.name: "platform-ref-aws"
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            version: "1.32"
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
                # Network for AWS networking
                awsplatformv1alpha1.Network{
                    metadata.name: "platform-ref-aws-network"
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            managementPolicies: ["*"]
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
                # EKS for Amazon EKS
                awsplatformv1alpha1.EKS{
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
                            managementPolicies: ["*"]
                            providerConfigName: "default"
                            version: "1.32"
                            nodes = {
                                count: 3
                                instanceType: "t3.small"
                            }
                        }
                    }
                },
                # Oss for observability stack
                observev1alpha1.Oss{
                    metadata.name: "platform-ref-aws-oss"
                    spec = {
                        parameters = {
                            managementPolicies: ["*"]
                            id: "platform-ref-aws"
                            operators = {
                                prometheus = {
                                    version: "52.1.0"
                                }
                            }
                        }
                    }
                },
                # Flux for GitOps
                gitopsv1alpha1.Flux{
                    metadata.name: "platform-ref-aws-flux"
                    spec = {
                        parameters = {
                            managementPolicies: ["*"]
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
                # AWSLBController for Load Balancer Controller
                awsplatformv1alpha1.AWSLBController{
                    metadata.name: "platform-ref-aws-lb-controller"
                    spec = {
                        parameters = {
                            providerConfigName: "default"
                            managementPolicies: ["*"]
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
                    apiVersion: "protection.crossplane.io/v1beta1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-network-by-eks"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "EKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "Network"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "protection.crossplane.io/v1beta1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-eks-by-flux"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "gitops.platform.upbound.io/v1alpha1"
                            kind: "Flux"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "EKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "protection.crossplane.io/v1beta1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-eks-by-oss"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "observe.platform.upbound.io/v1alpha1"
                            kind: "Oss"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "EKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "protection.crossplane.io/v1beta1"
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
                            kind: "EKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "protection.crossplane.io/v1beta1"
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
                            kind: "AWSLBController"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "protection.crossplane.io/v1beta1"
                    kind: "Usage"
                    metadata.name: "platform-ref-aws-lb-controller-by-flux"
                    spec = {
                        replayDeletion: True
                        by = {
                            apiVersion: "gitops.platform.upbound.io/v1alpha1"
                            kind: "Flux"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "aws.platform.upbound.io/v1alpha1"
                            kind: "AWSLBController"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                }
            ]
            observedResources: [
                # Network with VPC ID in status
                awsplatformv1alpha1.Network{
                    metadata = {
                        name: "platform-ref-aws-network"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "Network"
                        }
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            managementPolicies: ["*"]
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
                    status = {
                        vpcId: "vpc-test123"
                    }
                },
                # Flux with Ready condition to trigger AWSLBController creation
                gitopsv1alpha1.Flux{
                    metadata = {
                        name: "platform-ref-aws-flux"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "Flux"
                        }
                    }
                    spec = {
                        parameters = {
                            managementPolicies: ["*"]
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
                # EKS with Ready condition to trigger all Helm releases creation
                awsplatformv1alpha1.EKS{
                    metadata = {
                        name: "platform-ref-aws-eks"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "EKS"
                        }
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-aws"
                            region: "us-west-2"
                            managementPolicies: ["*"]
                            providerConfigName: "default"
                            version: "1.32"
                            nodes = {
                                count: 3
                                instanceType: "t3.small"
                            }
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
                # AWSLBController with Ready condition to trigger Flux and OSS creation
                awsplatformv1alpha1.AWSLBController{
                    metadata = {
                        name: "platform-ref-aws-lb-controller"
                        annotations = {
                            "crossplane.io/composition-resource-name" = "AWSLBController"
                        }
                    }
                    spec = {
                        parameters = {
                            providerConfigName: "default"
                            managementPolicies: ["*"]
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
            compositionPath: "apis/clusters/composition.yaml"
            xrPath: "examples/cluster-xr.yaml"
            xrdPath: "apis/clusters/definition.yaml"
            timeoutSeconds: 120
            validate: False
        }
    }
]
items = _items
