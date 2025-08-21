import models.io.upbound.aws.v1beta1 as awsv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.aws.v1alpha1 as platformawsv1alpha1
import models.io.upbound.platform.v1alpha1 as platformv1alpha1
import models.io.upbound.platformref.aws.v1alpha1 as platformrefawsv1alpha1


_items = [
    metav1alpha1.E2ETest{
        metadata.name: "e2etest-cluster"
        spec= {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Ready"]
            manifests: [
                # XCluster test instance (XR)
                platformrefawsv1alpha1.XCluster{
                    metadata= {
                        name: "test-cluster-e2e"
                        labels: {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                    }
                    spec= {
                        compositionUpdatePolicy: "Automatic"
                        parameters= {
                            id: "test-cluster-e2e"
                            region: "eu-central-1"
                            version: "1.33"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            nodes= {
                                count: 3 # Single node is not enough for e2e test with lb-controller and rest of the helm charts
                                instanceType: "t3.small"
                            }
                            operators= {
                                flux= {
                                    version: "2.16.4"
                                }
                                fluxSync= {
                                    version: "1.13.4"
                                }
                                prometheus= {
                                    version: "76.3.0"
                                }
                            }
                            gitops= {
                                git= {
                                    interval: "5m0s"
                                    timeout: "60s"
                                    url: "https://github.com/upbound/platform-ref-aws/"
                                    path: "/"
                                    ref= {
                                        name: "refs/heads/main"
                                    }
                                }
                            }
                        }
                        writeConnectionSecretToRef: {
                            name: "platform-ref-aws-kubeconfig"
                            namespace: "crossplane-system"
                        }
                    }
                },

                # 2. Database XR (MariaDB)
                platformawsv1alpha1.XSQLInstance{
                    metadata = {
                        name: "test-cluster-e2e-db-mariadb"
                    }
                    spec = {
                        parameters = {
                            region: "eu-central-1"
                            engine: "mariadb"
                            engineVersion: "10.11.14"
                            storageGB: 5
                            autoGeneratePassword: True
                            passwordSecretRef = {
                                namespace: "default"
                                name: "mariadbsecret"
                                key: "password"
                            }
                            networkRef = {
                                id: "test-cluster-e2e"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "test-cluster-e2e-db-conn-mariadb"
                            namespace: "crossplane-system"
                        }
                    }
                },

                # 3. App XR (Ghost blog application)
                platformv1alpha1.XApp{
                    metadata = {
                        name: "test-cluster-e2e-ghost"
                        labels = {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                    }
                    spec = {
                        compositionUpdatePolicy: "Automatic"
                        parameters = {
                            providerConfigName: "test-cluster-e2e"
                            helm = {
                                wait: False
                                values = {
                                    ingress = {
                                        annotations = {
                                            "alb.ingress.kubernetes.io/scheme": "internet-facing"
                                            "alb.ingress.kubernetes.io/target-type": "ip"
                                        }
                                        enabled: True
                                        ingressClassName: "alb"
                                    }
                                    service = {
                                        type: "ClusterIP"
                                    }
                                }
                            }
                            passwordSecretRef = {
                                namespace: "crossplane-system"
                                name: "test-cluster-e2e-db-conn-mariadb"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "test-cluster-e2e-app-conn"
                            namespace: "crossplane-system"
                        }
                    }
                }
            ]
            initResources = [
                # Workaround for the e2e test early failure when providers are not ready
                # AWS Provider Family
                {
                    apiVersion: "pkg.crossplane.io/v1"
                    kind: "Provider"
                    metadata = {
                        name: "upbound-provider-family-aws"
                    }
                    spec = {
                        package: "xpkg.upbound.io/upbound/provider-family-aws:v1.23.2"
                        packagePullPolicy: "Always"
                    }
                },
                # AWS EC2 Provider
                {
                    apiVersion: "pkg.crossplane.io/v1"
                    kind: "Provider"
                    metadata = {
                        name: "upbound-provider-aws-ec2"
                    }
                    spec = {
                        package: "xpkg.upbound.io/upbound/provider-aws-ec2:v1.23.2"
                        packagePullPolicy: "Always"
                    }
                },
                # AWS EKS Provider
                {
                    apiVersion: "pkg.crossplane.io/v1"
                    kind: "Provider"
                    metadata = {
                        name: "upbound-provider-aws-eks"
                    }
                    spec = {
                        package: "xpkg.upbound.io/upbound/provider-aws-eks:v1.23.2"
                        packagePullPolicy: "Always"
                    }
                },
                # AWS IAM Provider
                {
                    apiVersion: "pkg.crossplane.io/v1"
                    kind: "Provider"
                    metadata = {
                        name: "upbound-provider-aws-iam"
                    }
                    spec = {
                        package: "xpkg.upbound.io/upbound/provider-aws-iam:v1.23.2"
                        packagePullPolicy: "Always"
                    }
                },
                # AWS RDS Provider
                {
                    apiVersion: "pkg.crossplane.io/v1"
                    kind: "Provider"
                    metadata = {
                        name: "upbound-provider-aws-rds"
                    }
                    spec = {
                        package: "xpkg.upbound.io/upbound/provider-aws-rds:v1.23.2"
                        packagePullPolicy: "Always"
                    }
                }
            ]
            extraResources = [
                # AWS ProviderConfig for AWS resources
                awsv1beta1.ProviderConfig{
                    metadata.name = "default"
                    spec = {
                        credentials = {
                            source = "Upbound"
                            upbound = {
                                webIdentity = {
                                    roleARN = "arn:aws:iam::609897127049:role/solutions-e2e-provider-aws"
                                }
                            }
                        }
                    }
                }
            ]
            skipDelete: False
            timeoutSeconds: 7200
        }
    }
]
items= _items
