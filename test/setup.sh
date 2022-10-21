#!/usr/bin/env bash
set -aeuo pipefail

echo "Running setup.sh"
echo "Waiting until configuration package is healthy/installed..."
${KUBECTL} wait configuration.pkg platform-ref-aws --for=condition=Healthy --timeout 5m
${KUBECTL} wait configuration.pkg platform-ref-aws --for=condition=Installed --timeout 5m

echo "Creating cloud credential secret..."
${KUBECTL} -n upbound-system create secret generic aws-creds --from-literal=credentials="${UPTEST_AWS_CREDS}" \
    --dry-run=client -o yaml | ${KUBECTL} apply -f -

echo "Waiting until provider-aws is healthy..."
${KUBECTL} wait provider.pkg upbound-provider-aws --for condition=Healthy --timeout 5m

echo "Waiting for all pods to come online..."
"${KUBECTL}" -n upbound-system wait --for=condition=Available deployment --all --timeout=5m

echo "Waiting for all XRDs to be established..."
kubectl wait xrd --all --for condition=Established

echo "Creating a default provider config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    secretRef:
      key: credentials
      name: aws-creds
      namespace: upbound-system
    source: Secret
EOF
