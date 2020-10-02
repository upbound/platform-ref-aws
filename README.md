# AWS Reference Platform for Crossplane

cluster/local/kind.sh up
cluster/local/kind.sh helm-install
k apply -f crossplane-cluster-admin-rolebinding.yaml

cd ../provider-aws
k apply -f config/crd/
make run

cd ../../upbound/platform-ref-aws
for f in $(find . -name 'definition.yaml'); do kubectl apply -f $f; done

k apply -f network/composition.yaml
k apply -f examples/network.yaml


## Clean up
k delete -f examples/network.yaml
k delete -f network/composition.yaml

for f in $(find . -name 'definition.yaml'); do k delete -f $f; done

cluster/local/kind.sh clean
