import models.io.upbound.aws.v1beta1 as awsv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
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
                            version: "1.31"
                            networkSelector: "basic"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            nodes= {
                                count: 1
                                instanceType: "t3.small"
                            }
                            operators= {
                                flux= {
                                    version: "2.10.6"
                                }
                                fluxSync= {
                                    version: "1.7.2"
                                }
                                prometheus= {
                                    version: "52.1.0"
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
                            name: "platform-ref-aws-connection-secret"
                        }
                    }
                }
            ]
            extraResources = [
                # Define the provider configuration
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
            timeoutSeconds: 3600
        }
    }
]
items= _items
