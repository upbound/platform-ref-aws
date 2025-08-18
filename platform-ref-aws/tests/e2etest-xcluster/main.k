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
                # XCluster test instance
                platformrefawsv1alpha1.Cluster{
                    metadata= {
                        name: "test-cluster-e2e"
                        namespace: "default"
                        labels: {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                    }
                    spec= {
                        compositeDeletePolicy: "Foreground"
                        parameters= {
                            id: "test-cluster-e2e"
                            region: "us-west-2"
                            version: "1.33"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            nodes= {
                                count: 1
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
                        }
                    }
                },

                # 2. Database claim (MariaDB)
                platformawsv1alpha1.SQLInstance{
                    metadata = {
                        name: "test-cluster-e2e-db-mariadb"
                        namespace: "default"
                    }
                    spec = {
                        parameters = {
                            region: "us-west-2"
                            engine: "mariadb"
                            engineVersion: "10.11.6"
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
                        }
                    }
                },

                # 3. App claim (Ghost blog application)
                platformv1alpha1.App{
                    metadata = {
                        name: "test-cluster-e2e-ghost"
                        namespace: "default"
                        labels = {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                    }
                    spec = {
                        compositeDeletePolicy: "Foreground"
                        parameters = {
                            providerConfigName: "test-cluster-e2e"
                            helm = {
                                wait: True
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
                                namespace: "default"
                                name: "test-cluster-e2e-db-conn-mariadb"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "test-cluster-e2e-app-conn"
                        }
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
            timeoutSeconds: 4500
        }
    }
]
items= _items
