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
# Haswell Nodes with dual-NICs enabled
#

NODE_TYPE=${NODE_TYPE_2}
LEASE_NAME="${LEASE_PREFIX}-${NODE_TYPE}-1"

SD=$(date -u "+%Y%m%d-%H%MUTC")
DATE=$(date -u "+%Y-%m-%d")
START_DATE=$(date -u -j -v +1M -f "%Y-%m-%d" "$DATE" "+%Y-%m-%d %H:%M")
END_DATE=$(date -u -j -v +${DAY}d -f "%Y-%m-%d" "$DATE" "+%Y-%m-%d %H:%M")


# Create server lease with dual-nic nodes

blazar lease-create \
      --physical-reservation min=${MIN},max=${MAX},resource_properties="[\"and\",[\"==\",\"\$network_adapters.1.enabled\",\"True\"],[\"==\",\"\$node_type\",\"compute_haswell\"]]" \
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

HASWELL_NODES=( $NODES )
RESERVATION_ID_HASWELL=$RESERVATION_ID


