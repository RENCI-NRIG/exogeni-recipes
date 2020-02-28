#!/bin/bash

#
# Create subnet 
#


VFC_NAME_1="cloudconnect1"
PROVIDER_1="exogeni"
NET_NAME_1="net-${PROVIDER_1}-${VFC_NAME_1}-1"

# Create subnet on network-1 

VFC_NAME="${VFC_NAME_1}"
PROVIDER="${PROVIDER_1}"
NET_NAME="${NET_NAME_1}"

SUBNET_NAME="subnet-${NET_NAME}"
DNS_NAMESERVER1="130.202.101.6"
DNS_NAMESERVER2="130.202.101.37"
 
CIDR="172.16.200.0/24"
GATEWAY_IP="172.16.200.127"
DHCP_ALLOCATION_START="172.16.200.11"
DHCP_ALLOCATION_END="172.16.200.99"


openstack subnet create --subnet-range ${CIDR} \
                   --no-dhcp \
                   --gateway ${GATEWAY_IP} \
                   --network ${NET_NAME} ${SUBNET_NAME}

