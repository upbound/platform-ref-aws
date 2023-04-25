#!/usr/bin/env bash
set -aeuo pipefail

# Delete the release before deleting the cluster not to orphan the release object
# Note(turkenh): This is a workaround for the infamous dependency problem during deletion.
# Note(ytsarev): In addition to helm Release deletion we also need to pause
# XService reconciler to prevent it from recreating the Release.
${KUBECTL} annotate xservices.aws.platformref.upbound.io --all crossplane.io/paused="true"
${KUBECTL} delete release --all
