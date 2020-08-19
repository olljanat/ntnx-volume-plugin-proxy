#!/bin/bash
set -euo pipefail

printf "Content-Type: application/json\n\n"

curl --silent --header "Authorization: Basic $AuthorizationBase64" \
--tlsv1.2 --insecure "https://$UPSTREAM/api/nutanix/v0.8/volume_groups?includeDiskSize=True" \
| jq "[.[] | select(.diskList[0].containerId | contains($REMOTE_USER))]" | cat
