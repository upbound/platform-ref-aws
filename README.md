# AWS Reference Platform for Crossplane

These are in progress development iteration steps to run the following:

* a local `kind` cluster
* Crossplane as a helm chart from source
* `provider-aws` in memory via `make run`
* directly apply XRDs and Composition manifests with `kubectl`

Note that no package for this reference platform is being built or used.

## Dev steps (outline)

### kind cluster and Crossplane

```console
cluster/local/kind.sh up
cluster/local/kind.sh helm-install
k apply -f crossplane-cluster-admin-rolebinding.yaml
```

### `provider-aws`

```console
cd ../provider-aws
k apply -f config/crd/
make run
```

### AWS reference platform

```console
cd ../../upbound/platform-ref-aws
for f in $(find . -name 'definition.yaml'); do kubectl apply -f $f; done
k apply -f network/composition.yaml
```

Now create an instance of the network claim:

```console
k apply -f examples/network.yaml
```

## Clean up

```console
k delete -f examples/network.yaml
k delete -f network/composition.yaml

for f in $(find . -name 'definition.yaml'); do k delete -f $f; done

cluster/local/kind.sh clean
```
