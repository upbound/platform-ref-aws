#!/usr/bin/env bash
set -aeuo pipefail

# Delete the release before deleting the cluster not to orphan the release object
# Note(turkenh): This is a workaround for the infamous dependency problem during deletion.
${KUBECTL} delete release --all
