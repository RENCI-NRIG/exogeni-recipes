#!/bin/bash

#
# Create subnet 
#


VFC_NAME_1="cloudconnect2"
PROVIDER_1="physnet1"
NET_NAME_1="net-${PROVIDER_1}-${VFC_NAME_1}-1"

                
# Create subnet on network-2 

VFC_NAME="${VFC_NAME_1}"
PROVIDER="${PROVIDER_1}"
NET_NAME="${NET_NAME_1}"

#VLAN_TAG=$(openstack network show ${NET_NAME} | grep segmentation_id | awk '{print $4}')
 
SUBNET_NAME="subnet-${NET_NAME}"
DNS_NAMESERVER1="130.202.101.6"
DNS_NAMESERVER2="130.202.101.37"
 

CIDR="192.168.200.0/24"
GATEWAY_IP="192.168.200.254"
DHCP_ALLOCATION_START="192.168.200.51"
DHCP_ALLOCATION_END="192.168.200.90"

openstack subnet create --subnet-range ${CIDR} \
                   --dhcp \
                   --allocation-pool start=${DHCP_ALLOCATION_START},end=${DHCP_ALLOCATION_END} \
                   --dns-nameserver ${DNS_NAMESERVER1} \
                   --dns-nameserver ${DNS_NAMESERVER2} \
                   --gateway ${GATEWAY_IP} \
                   --network ${NET_NAME} ${SUBNET_NAME}

# Create router for the subnet

ROUTER_NAME="router-${NET_NAME}"
EXTERNAL_NET="public"

openstack router create ${ROUTER_NAME}
openstack router add subnet ${ROUTER_NAME} ${SUBNET_NAME} 
openstack router set --external-gateway ${EXTERNAL_NET} ${ROUTER_NAME}



