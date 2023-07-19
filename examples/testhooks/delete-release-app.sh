#!/usr/bin/env bash
set -aeuo pipefail

# Delete the release before deleting the cluster not to orphan the release object
# Note(turkenh): This is a workaround for the infamous dependency problem during deletion.
# Note(ytsarev): In addition to helm Release deletion we also need to pause
# XService reconciler to prevent it from recreating the Release.
${KUBECTL} annotate xapps.aws.platformref.upbound.io --all crossplane.io/paused="true"
app=$(${KUBECTL} get releases --no-headers -o custom-columns="NAME:metadata.name" | grep "platform-ref-aws-ghost")
${KUBECTL} patch release $app -p '{"metadata":{"finalizers":null}}' --type=merge
${KUBECTL} delete release -l crossplane.io/claim-name=platform-ref-aws-ghost
