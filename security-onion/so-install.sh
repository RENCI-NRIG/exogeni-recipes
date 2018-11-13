#!/bin/bash

{
echo "debconf debconf/frontend select noninteractive" | sudo debconf-set-selections
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get update
sudo apt-get -y install software-properties-common
sudo add-apt-repository -y ppa:securityonion/stable
sudo apt-get update
sudo apt-get -y install securityonion-all syslog-ng-core
sudo apt-get -y install securityonion-onionsalt

sudo apt install securityonion-elastic
sudo so-elastic-download

# FIXME: Self-signed cert is not created properly. 
# Use the workaround below until bug is fixed in Security Onion.
KEY_FILE="/etc/ssl/private/ssl-cert-snakeoil.key"
CERT_FILE="/etc/ssl/certs/ssl-cert-snakeoil.pem"
SUBJECT="/C=US/ST=NC/L=ChapelHill/O=RENCI/OU=NRIG/CN=security_onion"
mkdir /root/certs && cd /root/certs
openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes \
            -out ${CERT_FILE} -keyout ${KEY_FILE} -subj ${SUBJECT}
chmod 400 ${KEY_FILE}
systemctl restart apache2

sudo apt-get -y install mailutils

echo "Security Onion installation is completed ..." 

} > /tmp/boot.log 2>&1
