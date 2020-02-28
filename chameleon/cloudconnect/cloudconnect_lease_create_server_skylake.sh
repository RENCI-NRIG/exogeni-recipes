#/bin/bash

# Create Lease for servers

LEASE_TYPE="server"
USER="mcevik"

NODE_TYPE_1="compute_skylake"
NODE_TYPE_2="compute_haswell"

TASK="cloudconnect"
LEASE_PREFIX="${USER}-${TASK}-${LEASE_TYPE}"

DAY="7"
MIN=2
MAX=3

#
# Skylake Nodes
#

NODE_TYPE=${NODE_TYPE_1}
LEASE_NAME="${LEASE_PREFIX}-${NODE_TYPE}-1"

SD=$(date -u "+%Y%m%d-%H%MUTC")
DATE=$(date -u "+%Y-%m-%d")
START_DATE=$(date -u -j -v +1M -f "%Y-%m-%d" "$DATE" "+%Y-%m-%d %H:%M")
END_DATE=$(date -u -j -v +${DAY}d -f "%Y-%m-%d" "$DATE" "+%Y-%m-%d %H:%M")

# Create server lease

blazar lease-create \
      --physical-reservation min=${MIN},max=${MAX},resource_properties="[\"==\", \"\$node_type\", \"$NODE_TYPE\"]" \
      --start-date "${START_DATE}" --end-date "${END_DATE}" \
      ${LEASE_NAME}

# Get the reservation ID

RESERVATION_ID=$(blazar lease-show  -f json ${LEASE_NAME} | jq -r .reservations | jq -r .id)
LEASE_ID=$(blazar lease-show  -f json ${LEASE_NAME} | jq -r .id)

# Get nodes from the reservation

lease=$LEASE_ID
hosts=$(blazar host-list -f json | jq 'map({"key": .id, "value": .hypervisor_hostname}) | from_entries')
NODES=$(blazar host-allocation-list -f json  \
        | jq -r --argjson hosts "$hosts" \
        "map(select(.reservations[]|select(.lease_id == \"$lease\"))) | map(\$hosts[.resource_id])[] ")

SKYLAKE_NODES=( $NODES )
RESERVATION_ID_SKYLAKE=$RESERVATION_ID


