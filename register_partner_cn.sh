#!/usr/bin/env bash
set -euo pipefail

export CLIENT_ID="3a036053-105d-4f0b-b315-15e7b38e2df8"
export CLIENT_SECRET="ta-secret.+rCpCXAHo1VSAT+b"
export AUDIENCE="https://fleet-api.prd.cn.vn.cloud.tesla.com"
export FLEET_AUTH="https://fleet-auth.prd.vn.cloud.tesla.com/oauth2/v3/token"
export PARTNER_DOMAIN="tesla-map-cn-github-io.vercel.app"

echo "Requesting partner access token..."
RESPONSE=$(
  curl --request POST \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
  --data-urlencode 'scope=openid vehicle_device_data vehicle_cmds vehicle_charging_cmds' \
  --data-urlencode "audience=$AUDIENCE" \
  $FLEET_AUTH
)

PARTNER_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

if [[ -z "$PARTNER_TOKEN" || "$PARTNER_TOKEN" == "null" ]]; then
  echo "Failed to obtain partner token" >&2
  exit 1
fi
echo "Partner token acquired. $PARTNER_TOKEN"
echo "Registering partner domain $PARTNER_DOMAIN"

curl -H "Authorization: Bearer $PARTNER_TOKEN" \
     -H 'Content-Type: application/json' \
     --data '{
			    "domain": "'$PARTNER_DOMAIN'"
			}' \
      -X POST \
      -i $AUDIENCE/api/1/partner_accounts