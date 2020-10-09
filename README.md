# AWS Reference Platform for Crossplane

## Basic steps to build, push, and install as a Crossplane package

1. Build package.

```
kubectl crossplane build configuration --ignore "examples/*"
```

2. Push package to registry.

```
kubectl crossplane push configuration upbound/platform-ref-aws:latest
```

3. Install package in Kubernetes cluster with Crossplane installed.

```
kubectl crossplane install configuration upbound/platform-ref-aws:latest
```

Note that no official package for this reference platform is being built or
published.

For now you should build from source and push to your repo of choice.

## Quick Start
With [Crossplane installed](https://crossplane.github.io/docs/master/getting-started/install-configure.html):

### Pick the repo and tag for push/install
Note: If unspecified, Dockerhub is the default registry.
```
# PACKAGE=registry.fav.io/myrepo/platform-ref-aws:latest
PACKAGE=upbound/platform-ref-aws:latest
```

### Install the `kubectl crossplane` CLI

```
rm /usr/local/bin/kubectl-crossplane*

# from lastest official release
curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh

# from master
curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | CHANNEL=master VERSION=v0.13.0-rc.338.gea5b4f7 sh

cp kubectl-crossplane /usr/local/bin
chmod +x /usr/local/bin/kubectl-crossplane
```

### Install `provider-aws`
```
kubectl crossplane install provider crossplane/provider-aws:master
kubectl get providers.pkg.crossplane.io
```

### Configure `ProviderConfig` and `Secret`
```
AWS_PROFILE=default && echo -e "[default]\naws_access_key_id = $(aws configure get aws_access_key_id --profile $AWS_PROFILE)\naws_secret_access_key = $(aws configure get aws_secret_access_key --profile $AWS_PROFILE)" > creds.conf

kubectl create secret generic aws-creds -n crossplane-system --from-file=key=./creds.conf
kubectl apply -f examples/aws-default-provider.yaml
```

### Build and push `platform-ref-aws`
```
docker login
kubectl crossplane build configuration --name package.xpkg --ignore "examples/*"
kubectl crossplane push configuration ${PACKAGE} -f package.xpkg
```

### Install `platform-ref-aws`
```
kubectl crossplane install configuration ${PACKAGE}
kubectl get configuration.pkg.crossplane.io
```

### Create `Network` claim
```
kubectl apply -f examples/network.yaml
```

### Create `PostgreSQLInstance` claim
```
kubectl apply -f examples/postgres-claim.yaml
```

### Verify everything is created
```
kubectl get claim
kubectl get composite
kubectl get managed
```

### Connect to the `PostgreSQLInstance` using the supplied db-conn `Secret`
```
endpoint=$(kubectl get secret -n default db-conn -o jsonpath='{.data.endpoint}' | base64 --decode)
port=$(kubectl get secret -n default db-conn -o jsonpath='{.data.port}' | base64 --decode)
username=$(kubectl get secret -n default db-conn -o jsonpath='{.data.username}' | base64 --decode)
echo -n "${endpoint}:${port}:postgres:${username}:" > .pgpass
echo $(kubectl get secret -n default db-conn -o jsonpath='{.data.password}' | base64 --decode) >> .pgpass
export PGPASSFILE="$(pwd)/.pgpass"

sudo chmod 600 .pgpass

psql -h $endpoint -U $username postgres
```

### Cleanup
```
kubectl delete -f examples/postgres-claim.yaml
kubectl delete -f examples/network.yaml
kubectl get managed
```

### Uninstall
```
kubectl delete configurations.pkg.crossplane.io platform-ref-aws
kubectl delete providers.pkg.crossplane.io provider-aws
```

## Dev steps (outline)

These are in progress development iteration steps to run the following:

* a local `kind` cluster
* Crossplane as a helm chart from source
* `provider-aws` in memory via `make run`
* directly apply XRDs and Composition manifests with `kubectl`

### kind cluster and Crossplane

```console
cluster/local/kind.sh up
cluster/local/kind.sh helm-install
k apply -f crossplane-cluster-admin-rolebinding.yaml
```

### `provider-aws`

```console
k apply -f package/crds/
make run
```

### AWS reference platform

Set up the AWS credentials and default AWS `ProviderConfig`:

```console
AWS_PROFILE=default && echo -e "[default]\naws_access_key_id = $(aws configure get aws_access_key_id --profile $AWS_PROFILE)\naws_secret_access_key = $(aws configure get aws_secret_access_key --profile $AWS_PROFILE)" > creds.conf
```

```console
kubectl create secret generic aws-creds -n crossplane-system --from-file=key=./creds.conf
kubectl apply -f examples/aws-default-provider.yaml
```

Now create all the XRDs and Compositions:

```console
for f in $(find . -name 'definition.yaml'); do kubectl apply -f $f; done
for f in $(find . -name 'composition.yaml'); do kubectl apply -f $f; done
```

Now create an instance of the network claim:

```console
k apply -f examples/network.yaml
```

## Clean up

```console
k delete -f examples/network.yaml

for f in $(find . -name 'composition.yaml'); do k delete -f $f; done
for f in $(find . -name 'definition.yaml'); do k delete -f $f; done

kubectl delete -f examples/aws-default-provider.yaml
kubectl -n crossplane-system delete secret aws-creds
rm -fr creds.conf

cluster/local/kind.sh clean
```
