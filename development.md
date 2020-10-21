# Local Dev Guide

These are in progress development iteration steps to run the following:

* a local `kind` cluster
* Crossplane as a helm chart from source
* `provider-aws` and `provider-helm` from published packages
* directly apply XRDs and Composition manifests with `kubectl`

## kind cluster and Crossplane

```console
cluster/local/kind.sh up
cluster/local/kind.sh helm-install
k apply -f crossplane-cluster-admin-rolebinding.yaml
```

## `provider-aws` and `provider-helm`

```console
PROVIDER_AWS=crossplane/provider-aws:v0.12.0
PROVIDER_HELM=crossplane/provider-helm:v0.3.5

kubectl crossplane install provider ${PROVIDER_AWS}
kubectl crossplane install provider ${PROVIDER_HELM}
kubectl get pkg
```

## AWS reference platform

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
