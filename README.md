# AWS Reference Platform for Kubernetes + Data Services

This repository contains a reference AWS Platform
[Configuration](https://crossplane.io/docs/v1.9/getting-started/create-configuration.html)
for use as a starting point in working with [Upbound Universal Crossplane (UXP)](https://www.upbound.io/products/universal-crossplane)
and publishing to [Universal Marketplace](https://marketplace.upbound.io/).
It enables you to build, run and operate your own internal cloud platform and
offer a self-service API to your internal teams. It provides platform APIs to provision
fully configured EKS clusters, with secure networking, and stateful cloud
services (RDS) designed to securely connect to the nodes in each EKS cluster --
all composed using cloud service primitives from the [Official Upbound AWS
Provider](https://marketplace.upbound.io/providers/upbound/provider-aws). App
deployments can securely connect to the infrastructure they need using secrets
distributed directly to the app namespace.

## Contents

* [Universal Crossplane and Universal Marketplace](#universal-crossplane-and-universal-marketplace)
* [Build Your Own Internal Cloud Platform](#build-your-own-internal-cloud-platform)
* [Install Tools](#pre-requisite--optional-tools)
* [Platform Ops/SRE: Run your own internal cloud platform](#platform-opssre-run-your-own-internal-cloud-platform)
  * [App Dev/Ops: Consume the infrastructure you need using kubectl](#app-devops-consume-the-infrastructure-you-need-using-kubectl)
  * [APIs in this Configuration](#apis-in-this-configuration)
* [Customize for your Organization](#customize-for-your-organization)
* [Learn More](#learn-more)

## Universal Crossplane and Universal Marketplace

![Upbound Overview](docs/media/upbound.png)

What if you could eliminate infrastructure bottlenecks, security pitfalls, and
deliver apps faster by providing your teams with self-service APIs that
encapsulate your best practices and security policies, so they can quickly
provision the infrastructure they need using a custom cloud console, `kubectl`,
or deployment pipelines and GitOps workflows -- all without writing code?

[Upbound](https://upbound.io) enables you to do just that, powered by the
open source [Upbound Universal Crossplane](https://www.upbound.io/products/universal-crossplane) project.

The [Universal Marketplace](https://marketplace.upbound.io/) is a central hub for
finding Crossplane packages with verified content and auto-generated documentation.

Upbound curates a set of Official Providers which are actively maintained and
thoroughly tested to help you discover the best building blocks for your internal
cloud platform.

Consistent self-service APIs can be provided across dev, staging, and
production environments, making it easy for app teams to get the infrastructure
they need using vetted infrastructure configurations that meet the standards
of your organization.

## Build Your Own Internal Cloud Platform

App teams can provision the infrastructure they need with a single YAML file
alongside `Deployments` and `Services` using existing tools and workflows
including tools like `kubectl`, Flux and ArgoCD to consume your platform's self-service
APIs.

The Platform `Configuration` defines the self-service APIs and
classes-of-service for each API:

* `CompositeResourceDefinitions` (XRDs) define the platform's self-service
   APIs - e.g. `XPostgreSQLInstance`.
* `Compositions` offer the classes-of-service supported for each self-service
   API - e.g. `Standard`, `Performance`, `Replicated`.

![Upbound Overview](docs/media/compose.png)

Crossplane `Providers` include the cloud service primitives (AWS, Azure, GCP,
Alibaba) used in a `Composition`.

Learn more about `Composition` in the [Crossplane
Docs](https://crossplane.io/docs/v1.9/concepts/composition.html).

## Pre-Requisite & Optional Tools

Install the following command line tools:

* `up cli`

  There are multiple ways to [install up](https://cloud.upbound.io/docs/cli/#install-script), including Homebrew and Linux packages.

  ```console
  curl -sL https://cli.upbound.io | sh

  ```

## Platform Ops/SRE: Run your own internal cloud platform

The Universal Crossplane (UXP) can be provisioned to any Kubernetes cluster.

The AWS Reference platform will extend Kubernetes API with your own platform API
abstractions.

#### Installing UXP on a Kubernetes Cluster

The other option is installing UXP into a Kubernetes cluster you manage using `up`, which
is the official CLI for interacting with Upbound Cloud and Universal Crossplane (UXP).

Ensure that your kubectl context is pointing to the correct cluster:

```console
kubectl config current-context
```

Install UXP into the `upbound-system` namespace:

```console
up login
up uxp install
```

Validate the install using the following command:

```console
kubectl get all -n upbound-system
```

#### Install the Platform Configuration

Now that your kubectl context is configured to connect to a UXP Control Plane,
we can install this reference platform as a Crossplane package.

```console
# Check the latest version available in https://marketplace.upbound.io/configurations/upbound/platform-ref-aws/
kubectl apply -f examples/configuration.yaml
kubectl get pkg
```

#### Configure Providers in your Platform

Refer to [official Universal Marketplace documentation](https://marketplace.upbound.io/providers/upbound/provider-aws/latest/docs/configuration)

## Provision Resources

With the setup complete, we can now use platform-aws to provision resources in AWS.

#### Create EKS Cluster

The example cluster composition create an EKS cluster and includes a nested composite resource for the network, which creates a VPC, Subnet, Route Tables and a Gateway.

```console
kubectl apply -f examples/cluster-claim.yaml
```

Verify status:

```console
kubectl get claim
kubectl get composite
kubectl get managed
```

#### Provision a PostgreSQLInstance in your team Control Plane GUI console

1. Browse the available self-service APIs (XRDs) Control Plane
1. Provision a `CompositePostgreSQLInstance` using the custom generated GUI for your
Platform `Configuration`
1. View status / details in your `Control Plane` GUI console

#### Connect kubectl to your team Control Plane

1. Connect `kubectl` to a `Control Plane` from the self-service GUI console.

#### Provision a PostgreSQLInstance using kubectl

```console
kubectl apply -f examples/postgres-claim.yaml
```

Verify status:

```console
kubectl get claim
kubectl get composite
kubectl get managed
```

### Cleanup & Uninstall

#### Cleanup Resources

Delete resources created through the `Control Plane` Configurations menu:

* From the `Teams` GUI using the ellipsis menu in the resource view.
* Using `kubectl delete -n team1 <claim-name>`.

Delete resources created using `kubectl`:

```console
kubectl delete -f examples/cluster-claim.yaml
kubectl delete -f examples/postgres-claim.yaml
```

Verify all underlying resources have been cleanly deleted:

```console
kubectl get managed
```

#### Uninstall Provider & Platform Configuration

```console
kubectl delete configurations.pkg.crossplane.io platform-ref-aws
kubectl delete providers.pkg.crossplane.io provider-aws
kubectl delete providers.pkg.crossplane.io provider-helm
```

## APIs in this Configuration

* `Cluster` - provision a fully configured EKS cluster
  * [definition.yaml](package/cluster/definition.yaml)
  * [composition.yaml](package/cluster/composition.yaml) includes (transitively):
    * XEKS for EKS Cluster
    * XNetwork for network fabric
    * XServices for Prometheus and other cluster services
* `XEKS` Creates EKS cluster.
    * [definition.yaml](package/cluster/eks/definition.yaml)
    * [composition.yaml](package/cluster/eks/composition.yaml) includes:
    * `Cluster`
    * `ClusterAuth`
    * `XNetwork` for network fabric
    * `NodeGroup`
    * `Role`
    * `RolePolicyAttachment`
    * `OpenIDConnectProvider`
    * `ProviderConfig` of Helm Provider to install custome cluster services as
       a part of `XServices` abstraction
* `XNetwork` - fabric for a `Cluster` to securely connect to Data Services and
  the Internet.
  * [definition.yaml](package/cluster/network/definition.yaml)
  * [composition.yaml](package/cluster/network/composition.yaml) includes:
    * `VPC`
    * `Subnet`
    * `InternetGateway`
    * `MainRouteTableAssociation`
    * `Route`
    * `RouteTable`
    * `RouteTableAssociation`
    * `SecurityGroup`
    * `SecurityGroupRule`
* `XServices` - Helm Provider abstraction to control installation of
   Prometheus operator and other cluster services
    * [definition.yaml](package/cluster/services/definition.yaml)
    * [composition.yaml](package/cluster/services/composition.yaml) includes:
    * `Release`
* `PostgreSQLInstance` - provision a PostgreSQL RDS instance that securely connects to a `Cluster`
  * [definition.yaml](package/database/postgres/definition.yaml)
  * [composition.yaml](package/database/postgres/composition.yaml) includes:
    * `Instance`
    * `SubnetGroup`

## Customize for your Organization

You can customize this platform reference as much as you like and use it as
a foundation for building your very own Configuration.

In addition to that, you can create a free repository for your Configuration and
publish it to [Universal Marketplace](https://marketplace.upbound.io/)

#### Create a free account in Upbound Cloud

1. Sign up for [Upbound Cloud](https://cloud.upbound.io/register).
1. When you first create an Upbound Account, you can create an Organization

### Create a Custom Repository

Create a `Repository` called `platform-ref-aws` in your Upbound Cloud `Organization`:

![Upbound Repository](docs/media/repository.png)

Set these to match your settings:

```console
UPBOUND_ORG=acme
UPBOUND_ACCOUNT_EMAIL=me@acme.io
REPO=platform-ref-aws
VERSION_TAG=v0.3.0
REGISTRY=xpkg.upbound.io
PLATFORM_CONFIG=${REGISTRY:+$REGISTRY/}${UPBOUND_ORG}/${REPO}:${VERSION_TAG}
```

Clone the GitHub repo.

```console
git clone https://github.com/upbound/platform-ref-aws.git
cd platform-ref-aws
```

Login to your container registry.

```console
docker login ${REGISTRY} -u ${UPBOUND_ACCOUNT_EMAIL}
```

Build package.

```console
up xpkg build --name package.xpkg --package-root=package --examples-root="examples"
```

Push package to registry.

```console
up xpkg push ${PLATFORM_CONFIG} -f package.xpkg
```

Install package into an Universal Crossplane(UXP) instance.

```console
cat <<EOF >> configuration.yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: platform-ref-aws
spec:
  package: ${PLATFORM_CONFIG}
EOF
```

```console
kubectl apply -f configuration.yaml
```

The AWS cloud service primitives that can be used in a `Composition` today are
listed in the [Upbound Official AWS Provider Docs](https://marketplace.upbound.io/providers/upbound/provider-aws).

To learn more see [Configuration Packages](https://crossplane.github.io/docs/v1.9/concepts/packages.html).

## What's Next

If you're interested in building your own reference platform for your company,
we'd love to hear from you and chat. You can setup some time with us at
https://www.upbound.io/contact

For Crossplane questions, drop by [slack.crossplane.io](https://slack.crossplane.io), and say hi!
