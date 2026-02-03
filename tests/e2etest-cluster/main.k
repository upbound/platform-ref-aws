import models.io.upbound.awsm.v1beta1 as awsv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.aws.v1alpha1 as platformawsv1alpha1
import models.io.upbound.platform.v1alpha1 as platformv1alpha1
import models.io.upbound.platformref.aws.v1alpha1 as platformrefawsv1alpha1


_items = [
    metav1alpha1.E2ETest{
        metadata.name: "e2etest-cluster"
        spec= {
            crossplane.autoUpgrade.channel: "None"
            crossplane.version = "2.0.2-up.5"
            defaultConditions: ["Ready"]
            manifests: [
                # Cluster test instance (XR)
                platformrefawsv1alpha1.Cluster{
                    metadata= {
                        name: "test-cluster-e2e"
                        namespace: "default"
                        labels: {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                    }
                    spec= {
                        parameters= {
                            id: "test-cluster-e2e"
                            region: "eu-central-1"
                            version: "1.33"
                            providerConfigName: "e2e-test-cluster"
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
                    }
                },

                # 2. Database XR (MariaDB)
                platformawsv1alpha1.SQLInstance{
                    metadata = {
                        name: "test-cluster-e2e-db-mariadb"
                        namespace: "default"
                    }
                    spec = {
                        parameters = {
                            region: "eu-central-1"
                            engine: "mariadb"
                            engineVersion: "10.11.14"
                            storageGB: 5
                            autoGeneratePassword: True
                            passwordSecretRef = {
                                name: "mariadbsecret"
                                key: "password"
                            }
                            networkRef = {
                                id: "test-cluster-e2e"
                            }
                        }
                    }
                },

                # 3. App XR (Ghost blog application)
                platformv1alpha1.App{
                    metadata = {
                        name: "test-cluster-e2e-ghost"
                        namespace: "default"
                        labels = {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                    }
                    spec = {
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
                                name: "test-cluster-e2e-db-conn-mariadb"
                                namespace: "default"
                            }
                        }
                    }
                }
            ]
            extraResources = [
                # AWS ProviderConfig for AWS resources
                awsv1beta1.ProviderConfig{
                    metadata = {
                        name = "e2e-test-cluster"
                        namespace = "default"
                    }
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
