#!/bin/bash

LEASE_TYPE="server"
USER="mcevik"

NODE_TYPE_1="compute_skylake"
NODE_TYPE_2="compute_haswell"

TASK="cloudconnect"
LEASE_PREFIX="${USER}-${TASK}-${LEASE_TYPE}"

# Skylake Node Lease

NODE_TYPE=${NODE_TYPE_1}
LEASE_NAME_SKYLAKE="${LEASE_PREFIX}-${NODE_TYPE}-1"

# Haswell Node Lease

NODE_TYPE=${NODE_TYPE_2}
LEASE_NAME_HASWELL="${LEASE_PREFIX}-${NODE_TYPE}-1"

# Haswell - Get the reservation ID

LEASE_NAME=${LEASE_NAME_HASWELL}

RESERVATION_ID=$(blazar lease-show  -f json ${LEASE_NAME} | jq -r .reservations | jq -r .id)
LEASE_ID=$(blazar lease-show  -f json ${LEASE_NAME} | jq -r .id)

# Haswell - Get nodes from the reservation

hosts=$(blazar host-list -f json | jq 'map({"key": .id, "value": .hypervisor_hostname}) | from_entries')
NODES=$(blazar host-allocation-list -f json  \
        | jq -r --argjson hosts "$hosts" \
        "map(select(.reservations[]|select(.lease_id == \"$LEASE_ID\"))) | map(\$hosts[.resource_id])[] ")

HASWELL_NODES=( $NODES )
RESERVATION_ID_HASWELL=$RESERVATION_ID

HASWELL_1="${HASWELL_NODES[0]}"
HASWELL_2="${HASWELL_NODES[1]}"
HASWELL_3="${HASWELL_NODES[2]}"

# Get network UUIDs
VFC_NAME_1="cloudconnect1"
PROVIDER_1="exogeni"
NET_NAME_1="net-${PROVIDER_1}-${VFC_NAME_1}-1"
NET_UUID_1=$( openstack network show -f value -c id ${NET_NAME_1} )

VFC_NAME_2="cloudconnect2"
PROVIDER_2="physnet1"
NET_NAME_2="net-${PROVIDER_2}-${VFC_NAME_2}-1"
NET_UUID_2=$( openstack network show -f value -c id ${NET_NAME_2} )

INSTANCE_1="sw-bgp"
INSTANCE_2="sw-instance-1"

NET_1_IP_1="172.16.200.1"
NET_1_IP_2="172.16.200.2"
NET_1_IP_3="172.16.200.3"

NET_2_IP_1="192.168.200.61"
NET_2_IP_2="192.168.200.62"
NET_2_IP_3="192.168.200.63"



FLAVOR="baremetal"
IMAGE_CENTOS="CC-CentOS7"
KEY="key-chameleon"
SEC_GROUP="default"

IMAGE=${IMAGE_CENTOS}
USER_DATA_FILE="postbootscript.sh"

#
# Create instance BGP speaker on dual-nic Haswell node 
#
SERVER=${INSTANCE_1}
PHYSICAL=${HASWELL_1}
IP_ADDR_1=${NET_1_IP_1}
IP_ADDR_2=${NET_2_IP_1}
RESERVATION_ID=${RESERVATION_ID_HASWELL}

openstack server create \
  --image ${IMAGE} \
  --flavor ${FLAVOR} \
  --key-name ${KEY} \
  --nic net-id=${NET_UUID_2},v4-fixed-ip=${IP_ADDR_2} \
  --nic net-id=${NET_UUID_1},v4-fixed-ip=${IP_ADDR_1} \
  --security-group ${SEC_GROUP} \
  --hint reservation=${RESERVATION_ID} \
  --hint query='["=","$hypervisor_hostname","$PHYSICAL"]' \
  ${SERVER}

sleep 3;

#
# Create regular instance on Haswell node 
#
SERVER=${INSTANCE_2}
PHYSICAL=${HASWELL_3}
IP_ADDR_2=${NET_2_IP_2}
RESERVATION_ID=${RESERVATION_ID_HASWELL}

openstack server create \
  --image ${IMAGE} \
  --flavor ${FLAVOR} \
  --key-name ${KEY} \
  --nic net-id=${NET_UUID_2},v4-fixed-ip=${IP_ADDR_2} \
  --security-group ${SEC_GROUP} \
  --hint reservation=${RESERVATION_ID} \
  --hint query='["=","$hypervisor_hostname","$PHYSICAL"]' \
  ${SERVER}


