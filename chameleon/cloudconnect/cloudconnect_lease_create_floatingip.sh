#/bin/bash

# 
# Create lease for floating ips
#

LEASE_TYPE="floatingip"
USER="mcevik"

TASK="cloudconnect"
LEASE_PREFIX="${USER}-${TASK}-${LEASE_TYPE}"

LEASE_NAME="${LEASE_PREFIX}"

DAY="7"
AMOUNT="3"

PUBLIC_NETWORK_ID=$(openstack network show public -f value -c id)

SD=$(date -u "+%Y%m%d-%H%MUTC")
DATE=$(date -u "+%Y-%m-%d")
START_DATE=$(date -u -j -v +1M -f "%Y-%m-%d" "$DATE" "+%Y-%m-%d %H:%M")
END_DATE=$(date -u -j -v +${DAY}d -f "%Y-%m-%d" "$DATE" "+%Y-%m-%d %H:%M")

blazar lease-create \
  --reservation "resource_type=virtual:floatingip,network_id=${PUBLIC_NETWORK_ID},amount=${AMOUNT}" \
  --start-date "${START_DATE}" --end-date "${END_DATE}" \
  "$LEASE_NAME"
