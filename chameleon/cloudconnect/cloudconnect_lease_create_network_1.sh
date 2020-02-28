#!/bin/bash

#
# Create leases for networks on Chameleon Cloud
#


LEASE_TYPE="network"
USER="mcevik"

TASK="cloudconnect"
LEASE_PREFIX="${USER}-${TASK}-${LEASE_TYPE}"

OF_CONTROLLER_IP="147.72.248.27"
OF_CONTROLLER_PORT="6653"

VFC_NAME_1="cloudconnect1"
PROVIDER_1="exogeni"
NET_NAME_1="net-${PROVIDER_1}-${VFC_NAME_1}-1"

DAY="7"
                
# Create Lease for network-1 on exogeni provider

SD=$(date -u "+%Y%m%d-%H%MUTC")
DATE=$(date -u "+%Y-%m-%d")
START_DATE=$(date -u -j -v +1M -f "%Y-%m-%d" "$DATE" "+%Y-%m-%d %H:%M")
END_DATE=$(date -u -j -v +${DAY}d -f "%Y-%m-%d" "$DATE" "+%Y-%m-%d %H:%M")

VFC_NAME="${VFC_NAME_1}"
PROVIDER="${PROVIDER_1}"
NET_NAME="${NET_NAME_1}"

LEASE_NAME="${LEASE_PREFIX}-${PROVIDER}-1"


# Possible options for network creation on Chameleon Cloud
# 1 - custom openflow controller on named vfc
# 2 - stock openflow controller on named vfc
# 3 - stock openflow controller without named vfc

# Option 1
#blazar lease-create \
#   --reservation resource_type=network,network_name=${NET_NAME},network_description="OFController=${OF_CONTROLLER_IP}:${OF_CONTROLLER_PORT},VSwitchName=${VFC_NAME}",resource_properties="[\"==\",\"\$physical_network\",\"$PROVIDER\"]" \
#   --start-date "${START_DATE}" --end-date "${END_DATE}" \
#   ${LEASE_NAME}

# Option 2
blazar lease-create \
   --reservation resource_type=network,network_name=${NET_NAME},network_description="VSwitchName=${VFC_NAME}",resource_properties="[\"==\",\"\$physical_network\",\"$PROVIDER\"]" \
   --start-date "${START_DATE}" --end-date "${END_DATE}" \
   ${LEASE_NAME}

# Option 3
#blazar lease-create \
#   --reservation resource_type=network,network_name=${NET_NAME},resource_properties="[\"==\",\"\$physical_network\",\"$PROVIDER\"]" \
#   --start-date "${START_DATE}" --end-date "${END_DATE}" \
#   ${LEASE_NAME}
