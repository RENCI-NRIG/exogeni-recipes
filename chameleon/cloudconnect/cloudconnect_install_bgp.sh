#!/bin/bash

#
# Create Quagga and CorsaCRA instance
# ./cloudconnect_install_bgp.sh <BGP_AUTH_KEY>

yum update -y
yum install -y yum-utils device-mapper-persistent-data lvm2

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce

systemctl enable docker
systemctl start docker
systemctl status docker

mkdir ~/corsa_cra
cd ~/corsa_cra/ 
git init 
git config core.sparsecheckout true 
echo corsa_cra/corsa_cra/* >> .git/info/sparse-checkout 
git remote add -f origin https://mcevik0@github.com/RENCI-NRIG/exogeni-recipes.git 
git pull origin master 


cd ~/corsa_cra/corsa_cra/corsa_cra/docker/

# Modify corsa_cra/quagga/bgpd.conf

export LOCAL_ASN="65015"
export LOCAL_ROUTER_IP="172.16.100.1"
export LOCAL_SUBNET="192.168.200.0\/24"
export REMOTE_ROUTER_IP="172.16.100.2"
export REMOTE_ASN="55038"
export REMOTE_DESC="AWS"
#export BGP_PASSWORD="xxxxxxxxxxxxxxxxxxxxxxxx"
export BGP_PASSWORD=$1


sed -r -i "s/<LOCAL_ASN>/${LOCAL_ASN}/g" corsa_cra/quagga/bgpd.conf
sed -r -i "s/<LOCAL_ROUTER_IP>/${LOCAL_ROUTER_IP}/g" corsa_cra/quagga/bgpd.conf
sed -r -i "s/<LOCAL_SUBNET>/${LOCAL_SUBNET}/g" corsa_cra/quagga/bgpd.conf
sed -r -i "s/<REMOTE_ROUTER_IP>/${REMOTE_ROUTER_IP}/g" corsa_cra/quagga/bgpd.conf
sed -r -i "s/<REMOTE_ASN>/${REMOTE_ASN}/g" corsa_cra/quagga/bgpd.conf
sed -r -i "s/<REMOTE_DESC>/${REMOTE_DESC}/g" corsa_cra/quagga/bgpd.conf
sed -r -i "s/<BGP_PASSWORD>/${BGP_PASSWORD}/g" corsa_cra/quagga/bgpd.conf


# Modify  corsa_cra/quagga/zebra.conf

export INTERFACE_FACING_AWS="eno1"
export INTERFACE_FACING_LOCAL="eno2"
export IP_ADDRESS_FACING_AWS="172.16.100.1\/24"
export IP_ADDRESS_FACING_LOCAL="192.168.200.61\/24"


sed -r -i "s/<INTERFACE_FACING_AWS>/${INTERFACE_FACING_AWS}/g" corsa_cra/quagga/zebra.conf
sed -r -i "s/<INTERFACE_FACING_LOCAL>/${INTERFACE_FACING_LOCAL}/g" corsa_cra/quagga/zebra.conf
sed -r -i "s/<IP_ADDRESS_FACING_AWS>/${IP_ADDRESS_FACING_AWS}/g" corsa_cra/quagga/zebra.conf
sed -r -i "s/<IP_ADDRESS_FACING_LOCAL>/${IP_ADDRESS_FACING_LOCAL}/g" corsa_cra/quagga/zebra.conf


cd ~/corsa_cra/software/corsa/corsa_cra/docker/ 
docker build -t cra_2 . 
docker run --rm -dit --privileged --network host -p 6653:6653 --name=cra_2 cra_2 
docker image ls
