#!/bin/bash

ELASTICSEARCH_CLUSTER_NAME=exogeni-elk
ELASTIC_PASSWORD=secret
KIBANA_PASSWORD=secret
LOGSTASH_PASSWORD=secret

KIBANA_XPACK_ENCRYPT_KEY="something_at_least_32_characters"

# CA_PASS must be exported in order for openssl command to access
export CA_PASS=secret # Certificate Authority

# Depending on the VM size, the memory available can be less than ElasticSearch is expecting
ELASTICSEARCH_JVM_HEAP=512m

# X-Pack plugin requires a license?
# > Your Trial license is active
# > Register for a Basic License. Monitoring is available for free with a Basic License. Simply register, check your inbox, and enjoy!
# > Unlock the Full Functionality. Get all X-Pack has to offer: security, monitoring, alerting, reporting, and Graph, plus support from the engineers behind the Elastic Stack.
# > Register below to receive a free 1 year Basic license, which enables many great features in X-Pack. See the subscription page for more details. And yes, when the 1 year is up, you can come back and register for another year. Happy searching!
# https://www.elastic.co/subscriptions
ENABLE_XPACK=true


# same location for X-Pack and/or Nginx ??
if [[ "${ENABLE_XPACK}" = true ]]; then
  #mkdir --parents /etc/elasticsearch/tls/private
  #mkdir --parents /etc/elasticsearch/tls/certs

  ELASTIC_SSL_KEY=/etc/elasticsearch/tls/private/elastic-server.key
  ELASTIC_SSL_CERT=/etc/elasticsearch/tls/private/elastic-server.crt
  ELASTIC_SSL_CA=/etc/elasticsearch/tls/certs/elastic-ca.crt
else
  ELASTIC_SSL_KEY=/etc/pki/tls/private/elastic-server.key
  ELASTIC_SSL_CERT=/etc/pki/tls/private/elastic-server.crt
  ELASTIC_SSL_CA=/etc/pki/tls/certs/elastic-ca.crt
fi

# Velocity Hacks
#set( $bash_var = '${' )
#set( $bash_str_split = '#* ' )
############################################################

# setup /etc/hosts
############################################################
echo $elk0.IP("VLAN0") $elk0.Name() >> /etc/hosts
echo $elk1.IP("VLAN0") $elk1.Name() >> /etc/hosts
echo $elk2.IP("VLAN0") $elk2.Name() >> /etc/hosts

echo `echo $self.Name() | sed 's/\//-/g'` > /etc/hostname
/bin/hostname -F /etc/hostname

# Install Java
############################################################
echo "elk_exogeni_postboot: yum install/updates"
yum makecache fast
#yum --assumeyes update # disabled only during testing. should be enabled in production
yum install --assumeyes wget java-1.8.0-openjdk-devel

export JAVA_HOME=$(readlink --canonicalize /usr/bin/java | sed "s:/bin/java::")

cat > /etc/profile.d/java.sh << EOF
export JAVA_HOME=$(readlink --canonicalize /usr/bin/java | sed "s:/bin/java::")
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

# Need to ensure lots of entropy available for generating SSL Keys
# http://giovannitorres.me/increasing-entropy-on-virtual-machines.html
# cat /proc/sys/kernel/random/entropy_avail 
############################################################
echo "elk_exogeni_postboot: enabling rng-tools"
yum -y install rng-tools
sed -i 's/EXTRAOPTIONS=""/EXTRAOPTIONS="-r \/dev\/urandom"/' /etc/sysconfig/rngd
chkconfig rngd on
service rngd start

# Configure firewalld for Centos 7
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7
############################################################
echo "elk_exogeni_postboot: configuring firewalld"
systemctl start firewalld.service
systemctl enable firewalld

# Internal cluster traffic should be treated as 'trusted'
firewall-cmd --zone=trusted --change-interface=eth1 --permanent # 'permanent' only changes saved config, not runtime

# restart firewalld to activate saved ('permanent') config
# systemctl restart firewalld.service # do this once at the end

# verify: firewall-cmd --get-active-zones

# kibana access via port 5601
# to see details about a particular service: vi /usr/lib/firewalld/services/kibana.xml (e.g.)
firewall-cmd --permanent --zone=public --add-service=kibana

# restart firewalld to activate saved ('permanent') config
systemctl restart firewalld.service

# verify: firewall-cmd --zone public --list-all

# TODO: logstash will need open ports, in order to accept files

############################################################
# Elastic ELK
# https://www.elastic.co/start
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-production-elasticsearch-cluster-on-centos-7
# https://stackoverflow.com/questions/33675945/optimal-way-to-set-up-elk-stack-on-three-servers
############################################################

# Setup Elastic PGP key and Yum repo
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

############################################################
# ElasticSearch
# https://www.elastic.co/start
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-production-elasticsearch-cluster-on-centos-7
############################################################
echo "elk_exogeni_postboot: installing ElasticSearch"

cat > /etc/yum.repos.d/elasticsearch.repo << EOF
[elasticsearch-5.x]
name=Elasticsearch repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

# Install ElasticSearch
############################################################
yum --assumeyes install elasticsearch

# Configure ElasticSearch
############################################################
export ELASTICSEARCH_CONF=/etc/elasticsearch/elasticsearch.yml
export ELASTICSEARCH_JVM_CONF=/etc/elasticsearch/jvm.options

mv ${ELASTICSEARCH_CONF} ${ELASTICSEARCH_CONF}.orig

cat > ${ELASTICSEARCH_CONF} << EOF
# ======================== Elasticsearch Configuration =========================
#
# NOTE: Elasticsearch comes with reasonable defaults for most settings.
#       Before you set out to tweak and tune the configuration, make sure you
#       understand what are you trying to accomplish and the consequences.
#
# The primary way of configuring a node is via this file. This template lists
# the most important settings you may want to configure for a production cluster.
#
# Please consult the documentation for further information on configuration options:
# https://www.elastic.co/guide/en/elasticsearch/reference/index.html
#
# ---------------------------------- Cluster -----------------------------------
#
# Use a descriptive name for your cluster:
cluster.name: ${ELASTICSEARCH_CLUSTER_NAME}
#
# ------------------------------------ Node ------------------------------------
#
# Use a descriptive name for the node:
node.name: $self.Name()
#
# ---------------------------------- Network -----------------------------------
#
# Set the bind address to a specific IP (IPv4 or IPv6):
network.host: [_eth0_, _eth1_, _local_]
#
# The publish host is the single interface that the node advertises to other nodes in the cluster, so that those nodes can connect to it.
# Is this better as '_eth1_' or '$self.IP("VLAN0")' ? Can the interface change numbering on reboot?
network.publish_host: _eth1_
#
# Set a custom port for HTTP:
#
#http.port: 9200
#
# For more information, consult the network module documentation.
#
# --------------------------------- Discovery ----------------------------------
#
# Pass an initial list of hosts to perform discovery when new node is started:
# The default list of hosts is ["127.0.0.1", "[::1]"]
discovery.zen.ping.unicast.hosts: ["$elk0.Name()", "$elk1.Name()", "$elk2.Name()"]
#
# --------------------------------- X-Pack ----------------------------------
#Enable Auditing to keep track of attempted and successful interactions with your Elasticsearch cluster:
xpack.security.audit.enabled: ${ENABLE_XPACK}
# SSL -- only if X-Pack is enabled
xpack.ssl.key: ${ELASTIC_SSL_KEY}
xpack.ssl.certificate: ${ELASTIC_SSL_CERT}
xpack.ssl.certificate_authorities: [ "${ELASTIC_SSL_CA}" ]
#
# Enable SSL on the transport networking layer to ensure that communication between nodes is encrypted:
xpack.security.transport.ssl.enabled: ${ENABLE_XPACK}
# Enable SSL on the HTTP layer to ensure that communication between HTTP clients and the cluster is encrypted:
xpack.security.http.ssl.enabled: ${ENABLE_XPACK}
#
EOF

# Depending on the VM size, the memory available can be less than ElasticSearch is expecting
sed --in-place "s/-Xms2g/-Xms${ELASTICSEARCH_JVM_HEAP}/" ${ELASTICSEARCH_JVM_CONF}
sed --in-place "s/-Xmx2g/-Xmx${ELASTICSEARCH_JVM_HEAP}/" ${ELASTICSEARCH_JVM_CONF}

# Install X-Pack plugin into ElasticSearch
############################################################
if [[ "${ENABLE_XPACK}" = true ]]; then
  echo "elk_exogeni_postboot: installing X-Pack plugin into ElasticSearch"
  /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch x-pack
fi


############################################################
# Kibana
# https://www.elastic.co/guide/en/kibana/current/rpm.html
# https://www.elastic.co/guide/en/kibana/5.6/settings.html
# https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-elk-stack-on-centos-7
# https://www.elastic.co/guide/en/x-pack/current/kibana.html
############################################################
echo "elk_exogeni_postboot: installing Kibana"

cat > /etc/yum.repos.d/elasticsearch.repo << EOF
[kibana-5.x]
name=Kibana repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

# Install Kibana
############################################################
yum --assumeyes install kibana

# Configure Kibana
############################################################
export KIBANA_CONF=/etc/kibana/kibana.yml

mv ${KIBANA_CONF} ${KIBANA_CONF}.orig

cat > ${KIBANA_CONF} << EOF
# Kibana is served by a back end server. This setting specifies the port to use.
#server.port: 5601

# Specifies the address to which the Kibana server will bind. IP addresses and host names are both valid values.
# The default is 'localhost', which usually means remote machines will not be able to connect.
# To allow connections from remote users, set this parameter to a non-loopback address.
server.host: "0.0.0.0"

# The URL of the Elasticsearch instance to use for all your queries.
#elasticsearch.url: "http://localhost:9200"

# If your Elasticsearch is protected with basic authentication, these settings provide
# the username and password that the Kibana server uses to perform maintenance on the Kibana
# index at startup. Your Kibana users still need to authenticate with Elasticsearch, which
# is proxied through the Kibana server.
#elasticsearch.username: "user"
elasticsearch.password: "${KIBANA_PASSWORD}"

# Enables SSL and paths to the PEM-format SSL certificate and SSL key files, respectively.
# These settings enable SSL for outgoing requests from the Kibana server to the browser.
server.ssl.enabled: ${ENABLE_XPACK}
server.ssl.certificate: ${ELASTIC_SSL_CERT}
server.ssl.key: ${ELASTIC_SSL_KEY}

# Optional settings that provide the paths to the PEM-format SSL certificate and key files.
# These files validate that your Elasticsearch backend uses the same key files.
#elasticsearch.ssl.certificate: ${ELASTIC_SSL_CERT}
#elasticsearch.ssl.key: ${ELASTIC_SSL_KEY}

# Optional setting that enables you to specify a path to the PEM file for the certificate
# authority for your Elasticsearch instance.
elasticsearch.ssl.certificateAuthorities: [ "${ELASTIC_SSL_CA}" ]

# To disregard the validity of SSL certificates, change this setting's value to 'none'.
#elasticsearch.ssl.verificationMode: full

# Set the xpack.security.encryptionKey property in the kibana.yml configuration file. 
# You can use any text string that is 32 characters or longer as the encryption key.
xpack.security.encryptionKey: "${KIBANA_XPACK_ENCRYPT_KEY}"

EOF

if [[ "${ENABLE_XPACK}" = true ]]; then
  sed --in-place 's|#elasticsearch.url: "http://localhost:9200"|elasticsearch.url: "https://localhost:9200"|' ${KIBANA_CONF}
fi

# Specifies the address to which the Kibana server will bind. IP addresses and host names are both valid values.
# The default is 'localhost', which usually means remote machines will not be able to connect.
#sed --in-place 's/#server.host: "localhost"/server.host: "0.0.0.0"/' ${KIBANA_CONF}

# X-Pack plugin sets up password authentication
#sed --in-place "s/#elasticsearch.password: \"pass\"/elasticsearch.password: \"${KIBANA_PASSWORD}\"/" ${KIBANA_CONF}

#if [[ "${ENABLE_XPACK}" = true ]]; then
#  # X-Pack plugin SSL/TLS
#  sed --in-place "s/#server.ssl.enabled: false/server.ssl.enabled: true/" ${KIBANA_CONF}
#  sed --in-place "s|#server.ssl.certificate: /path/to/your/server.crt|server.ssl.certificate: ${ELASTIC_SSL_CERT}|" ${KIBANA_CONF}
#  sed --in-place "s|#server.ssl.key: /path/to/your/server.key|server.ssl.key: ${ELASTIC_SSL_KEY}|" ${KIBANA_CONF}
#  sed --in-place "s|#elasticsearch.ssl.certificateAuthorities: \[ \"/path/to/your/CA.pem\" \]|elasticsearch.ssl.certificateAuthorities: [ \"${ELASTIC_SSL_CA}\" ]|" ${KIBANA_CONF}
#fi

# Install X-Pack plugin into Kibana
############################################################
if [[ "${ENABLE_XPACK}" = true ]]; then
  echo "elk_exogeni_postboot: installing X-Pack plugin into Kibana (can be slow)"
  /usr/share/kibana/bin/kibana-plugin install x-pack
fi

############################################################
# Logstash
# https://www.elastic.co/guide/en/kibana/current/rpm.html
# https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-elk-stack-on-centos-7
############################################################
echo "elk_exogeni_postboot: installing Logstash"

# Logstash is installed via the Kibana yum repo

# Install Logstash
############################################################
yum --assumeyes install logstash

# TODO: not sure what / if any default configuration is useful to do.
# See the linked Digital Ocean tutorial for examples, or elastic docs:
# https://www.elastic.co/guide/en/logstash/current/config-examples.html


# Install X-Pack plugin into Logstash
############################################################
if [[ "${ENABLE_XPACK}" = true ]]; then
  echo "elk_exogeni_postboot: installing X-Pack plugin into Logstash"
  /usr/share/logstash/bin/logstash-plugin install x-pack
fi

############################################################
# Setup SSH to be able to transfer SSL CA/cert files
############################################################

# Namenode will generate private SSH key
if [[ $self.Name() == elk0 ]]
then
  echo "elk_exogeni_postboot: generating SSH key"
  ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
  cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
  # allow cluster to download SSH public key
  # port is only accessible to internal cluster
  mkdir /public_html
  cp -u /root/.ssh/id_rsa.pub /public_html/
  (cd /public_html; python -c 'import SimpleHTTPServer,BaseHTTPServer; BaseHTTPServer.HTTPServer(("", 8080), SimpleHTTPServer.SimpleHTTPRequestHandler).serve_forever()') &
else
  echo "elk_exogeni_postboot: waiting to download SSH public key"
  # Need to download SSH public key from master
  until wget -O /root/.ssh/id_rsa.pub "http://elk0:8080/id_rsa.pub"
  do
    sleep 2
  done
  cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
fi

# Add host RSA keys to SSH known hosts files
# Need to wait until these succeed
until ssh-keyscan elk0 >> /root/.ssh/known_hosts; do sleep 2; done
until ssh-keyscan elk1 >> /root/.ssh/known_hosts; do sleep 2; done
until ssh-keyscan elk2 >> /root/.ssh/known_hosts; do sleep 2; done

# see if the script can copy private key to other nodes
if [[ $self.Name() == elk0 ]]
then
  echo "elk_exogeni_postboot: securely transferring SSH private key"
  until scp -o BatchMode=yes /root/.ssh/id_rsa elk1:/root/.ssh/id_rsa; do sleep 2; done
  until scp -o BatchMode=yes /root/.ssh/id_rsa elk2:/root/.ssh/id_rsa; do sleep 2; done
fi

############################################################
# Use 'certgen' to generate SSL CA and certs
# https://www.elastic.co/guide/en/elasticsearch/reference/5.6/certgen.html
# Except that's it's only included if you install X-Pack, which we probably won't want to do in the end.
############################################################

# Generate CA and SSL certs on a single node
############################################################
TEMP_CA_DIR=/root/ca
TEMP_CA_CONF=${TEMP_CA_DIR}/ca.conf
TEMP_CA_KEY=${TEMP_CA_DIR}/ca.key
TEMP_CA_CSR=${TEMP_CA_DIR}/ca.csr
TEMP_CA_CERT=${TEMP_CA_DIR}/ca.crt
TEMP_CA_CRL=${TEMP_CA_DIR}/ca.crl

CA_DOMAIN=recipes.exogeni.net
CA_NAME=exogeni-recipes
CA_CERT_C="US"
CA_CERT_ST="North Carolina"
CA_CERT_L="Chapel Hill"
CA_CERT_O="EXOGENI.net"
CA_CERT_OU="Recipes"
CA_CERT_CN="exogeni-recipes Certificate Authority"

if [[ $self.Name() == elk0 ]]
then
  echo "elk_exogeni_postboot: generating SSL CA"
  mkdir ${TEMP_CA_DIR}
  mkdir ${TEMP_CA_DIR}/db
  mkdir ${TEMP_CA_DIR}/archive

  # Create empty databases
  touch ${TEMP_CA_DIR}/db/certificate.db
  #touch ${TEMP_CA_DIR}/db/certificate.db.attr
  echo 01 > ${TEMP_CA_DIR}/db/crt.srl
  echo 01 > ${TEMP_CA_DIR}/db/crl.srl

  # https://github.com/redredgroovy/easy-ca/blob/master/templates/root.tpl
cat > ${TEMP_CA_CONF} << EOF
[ default ]
ca                      = ${CA_NAME}
domain                  = ${CA_DOMAIN}
base_url                = http://\$domain/ca         # CA base URL
aia_url                 = \$base_url/\$ca.crt        # CA certificate URL
crl_url                 = \$base_url/\$ca.crl        # CRL distribution point
name_opt                = multiline,-esc_msb,utf8    # Display UTF-8 characters

[ req ]
default_bits            = 4096                  # RSA key size
default_days            = 3652                  # How long to certify for
encrypt_key             = yes                   # Protect private key
default_md              = sha256                # MD to use
utf8                    = yes                   # Input is UTF-8
string_mask             = utf8only              # Emit UTF-8 strings
prompt                  = no                    # Don't prompt for DN
distinguished_name      = ca_dn                 # DN section
req_extensions          = ca_reqext             # Desired extensions

[ ca_dn ]
countryName             = "${CA_CERT_C}"
stateOrProvinceName     = "${CA_CERT_ST}"
localityName            = "${CA_CERT_L}"
organizationName        = "${CA_CERT_O}"
organizationalUnitName  = "${CA_CERT_OU}"
commonName              = "${CA_CERT_CN}"

[ ca_reqext ]
keyUsage                = critical,keyCertSign,cRLSign
basicConstraints        = critical,CA:true
subjectKeyIdentifier    = hash

[ ca ]
default_ca              = root_ca               # The default CA section

[ root_ca ]
certificate             = ${TEMP_CA_CERT}       # The CA cert
private_key             = ${TEMP_CA_KEY}        # CA private key
serial                  = ${TEMP_CA_DIR}/db/crt.srl         # Serial number file
crlnumber               = ${TEMP_CA_DIR}/db/crl.srl         # CRL number file
database                = ${TEMP_CA_DIR}/db/certificate.db  # Index file
new_certs_dir           = ${TEMP_CA_DIR}/archive                # Certificate archive
unique_subject          = no                    # Require unique subject
default_md              = sha256                # MD to use
policy                  = match_pol             # Default naming policy
email_in_dn             = no                    # Add email to cert DN
preserve                = no                    # Keep passed DN ordering
name_opt                = \$name_opt            # Subject DN display options
cert_opt                = ca_default            # Certificate display options
copy_extensions         = copy                  # Copy extensions from CSR
x509_extensions         = signing_ca_ext        # Default cert extensions
default_crl_days        = 1                     # How long before next CRL
crl_extensions          = crl_ext               # CRL extensions

[ match_pol ]
countryName             = match                 # Must match
stateOrProvinceName     = optional              # Included if present
localityName            = optional              # Included if present
organizationName        = match                 # Must match
organizationalUnitName  = optional              # Included if present
commonName              = supplied              # Must be present

# Extensions for this root CA
[ root_ca_ext ]
keyUsage                = critical,keyCertSign,cRLSign
basicConstraints        = critical,CA:true
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always

# Extensions for signing CAs issued by this root CA
[ signing_ca_ext ]
keyUsage                = critical,keyCertSign,cRLSign
basicConstraints        = critical,CA:true,pathlen:0
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always
authorityInfoAccess     = @issuer_info
crlDistributionPoints   = @crl_info

# Extensions for signing certs issued by this signing CA
[ server_ext ]
keyUsage                = critical,digitalSignature,keyEncipherment
basicConstraints        = CA:false
extendedKeyUsage        = serverAuth,clientAuth
subjectKeyIdentifier    = hash
#subjectAltName          = \$ENV::SAN
authorityKeyIdentifier  = keyid:always
authorityInfoAccess     = @issuer_info
crlDistributionPoints   = @crl_info

[ client_ext ]
keyUsage                = critical,digitalSignature
basicConstraints        = CA:false
extendedKeyUsage        = clientAuth
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always
authorityInfoAccess     = @issuer_info
crlDistributionPoints   = @crl_info

[ crl_ext ]
authorityKeyIdentifier  = keyid:always
authorityInfoAccess     = @issuer_info

[ issuer_info ]
caIssuers;URI.0         = \$aia_url

[ crl_info ]
URI.0                   = \$crl_url
EOF

  # https://github.com/redredgroovy/easy-ca/blob/master/create-root-ca

  # Create the root CA key
  openssl genrsa -out ${TEMP_CA_KEY} -passout env:CA_PASS 2048
  chmod 0400 ${TEMP_CA_KEY}

  # Create the root CA certificate
  openssl req -new -batch \
              -config ${TEMP_CA_CONF} \
              -key ${TEMP_CA_KEY} \
              -out ${TEMP_CA_CSR} \
              -passin env:CA_PASS

  # Create the signing CA certificate
  openssl ca -selfsign -batch -notext \
             -config ${TEMP_CA_CONF} \
             -in ${TEMP_CA_CSR} \
             -out ${TEMP_CA_CERT} \
             -days 3652 \
             -extensions root_ca_ext \
             -passin env:CA_PASS

  # Create the root CRL
  openssl ca -gencrl -batch \
             -config ${TEMP_CA_CONF} \
             -out ${TEMP_CA_CRL}

  # trust our new CA (might not be necessary)
  # https://www.happyassassin.net/2015/01/14/trusting-additional-cas-in-fedora-rhel-centos-dont-append-to-etcpkitlscertsca-bundle-crt-or-etcpkitlscert-pem/
  cp ${TEMP_CA_CERT} /etc/pki/ca-trust/source/anchors/
  update-ca-trust
fi

# Create (signed) server certs
############################################################
TEMP_SERVER_CONF=${TEMP_CA_DIR}/server.conf

if [[ $self.Name() == elk0 ]]
then
  echo "elk_exogeni_postboot: generating SSL server certs"

  # https://github.com/redredgroovy/easy-ca/blob/master/templates/server.tpl
cat > ${TEMP_SERVER_CONF} << EOF
[ default ]

[ req ]
default_bits            = 2048                  # RSA key size
default_days            = 730                   # How long to certify for
encrypt_key             = no                    # Protect private key
default_md              = sha256                # MD to use
utf8                    = yes                   # Input is UTF-8
string_mask             = utf8only              # Emit UTF-8 strings
prompt                  = yes                   # Prompt for DN
distinguished_name      = server_dn             # DN template
req_extensions          = server_reqext         # Desired extensions

[ server_dn ]
countryName			= "1. Country Name (2 letters) "
countryName_max			= 2
countryName_default		= ${CA_CERT_C}
stateOrProvinceName		= "2. State or Province Name   "
stateOrProvinceName_default	= ${CA_CERT_ST}
localityName			= "3. Locality Name            "
localityName_default		= ${CA_CERT_L}
organizationName		= "4. Organization Name        "
organizationName_default	= ${CA_CERT_O}
organizationalUnitName		= "5. Organizational Unit Name "
organizationalUnitName_default	= ${CA_CERT_OU}
commonName			= "6. Common Name              "
commonName_max			= 64
commonName_default		= \$ENV::CN_HOSTNAME

[ server_reqext ]
keyUsage                = critical,digitalSignature,keyEncipherment
extendedKeyUsage        = serverAuth,clientAuth
subjectKeyIdentifier    = hash
subjectAltName          = \$ENV::HOST_SAN

EOF

  # create server cert for namenode
  for server in $elk0.Name() $elk1.Name() $elk2.Name()
  do
    export CN_HOSTNAME=${server}

    # there must be a better way to do this part ?
    if [[ $elk0.Name() == ${server} ]]; then
      export HOST_SAN="IP:$elk0.IP("VLAN0")"
    elif [[ $elk1.Name() == ${server} ]]; then
      export HOST_SAN="IP:$elk1.IP("VLAN0")"
    elif [[ $elk2.Name() == ${server} ]]; then
      export HOST_SAN="IP:$elk2.IP("VLAN0")"
    fi

    TEMP_SERVER_KEY=${TEMP_CA_DIR}/${server}.server.key
    TEMP_SERVER_CSR=${TEMP_CA_DIR}/${server}.server.csr
    TEMP_SERVER_CERT=${TEMP_CA_DIR}/${server}.server.crt
    TEMP_SERVER_CRL=${TEMP_CA_DIR}/${server}.server.crl
    #TEMP_SERVER_P12=${TEMP_CA_DIR}/${server}.server.p12
    #TEMP_SERVER_JKS=${TEMP_CA_DIR}/${server}.server.jks

    # no password on the server keys
    openssl req -new -batch -nodes \
                -config ${TEMP_SERVER_CONF} \
                -keyout ${TEMP_SERVER_KEY} \
                -out ${TEMP_SERVER_CSR}
    chmod 0400 ${TEMP_SERVER_KEY}

    openssl ca -batch -notext \
               -config ${TEMP_CA_CONF} \
               -in ${TEMP_SERVER_CSR} \
               -out ${TEMP_SERVER_CERT} \
               -days 730 \
               -extensions server_ext \
               -passin env:CA_PASS

  done

fi

# transfer SSL files to other nodes
############################################################
if [[ "${ENABLE_XPACK}" = true ]]; then
  mkdir --parents /etc/elasticsearch/tls/private
  mkdir --parents /etc/elasticsearch/tls/certs

  # kibana user needs access to elasticsearch keys
  usermod -a -G elasticsearch kibana
fi

if [[ $self.Name() == elk0 ]]
then
  echo "elk_exogeni_postboot: securely transferring CA signed SSL certs to all nodes"

  for server in $elk0.Name() $elk1.Name() $elk2.Name()
  do

    TEMP_SERVER_KEY=${TEMP_CA_DIR}/${server}.server.key
    TEMP_SERVER_CERT=${TEMP_CA_DIR}/${server}.server.crt


    # Transfer SSL files to server
    until scp -o BatchMode=yes ${TEMP_CA_CERT}     ${server}:${ELASTIC_SSL_CA};  do sleep 2; done
    until scp -o BatchMode=yes ${TEMP_SERVER_KEY}  ${server}:${ELASTIC_SSL_KEY}; do sleep 2; done
    until scp -o BatchMode=yes ${TEMP_SERVER_CERT} ${server}:${ELASTIC_SSL_CERT};   do sleep 2; done

  done

fi

# wait for SSL certs to be available before continuing
echo "elk_exogeni_postboot: waiting for SSL certs"
until [[ -f ${ELASTIC_SSL_KEY} ]] ; do sleep 2; done
until [[ -f ${ELASTIC_SSL_CERT} ]] ; do sleep 2; done
until [[ -f ${ELASTIC_SSL_CA} ]] ; do sleep 2; done

for file in ${ELASTIC_SSL_KEY} ${ELASTIC_SSL_CERT} ${ELASTIC_SSL_CA}
do
  chown root:elasticsearch ${file}
done
chmod 640 ${ELASTIC_SSL_KEY}
chmod 644 ${ELASTIC_SSL_CERT}
chmod 644 ${ELASTIC_SSL_CA}



############################################################
# Start all of the services at the end, after full-configuration
############################################################

# Start ElasticSearch
systemctl start elasticsearch
systemctl enable elasticsearch

# Verify: curl -XGET -u elastic:${ELASTIC_PASSWORD} 'http://localhost:9200/_cluster/state?pretty' | less
# Verify: curl -k -XGET -u elastic:${ELASTIC_PASSWORD} 'https://localhost:9200/_cluster/state?pretty' | less

# Start Kibana
systemctl start kibana
systemctl enable kibana

# start and enable logstash
systemctl start logstash
systemctl enable logstash

############################################################
# X-Pack Security
# https://www.elastic.co/guide/en/x-pack/current/security-getting-started.html
############################################################

if [[ "${ENABLE_XPACK}" = true ]]; then
  echo "elk_exogeni_postboot: waiting for ElasticSearch to be responsive..."
  until curl -k -XGET -u elastic:changeme 'https://localhost:9200/'; do sleep 2; done

  echo "elk_exogeni_postboot: configuring passwords for X-Pack"

  # The default password for the elastic user is changeme.
  curl \
    --insecure \
    -XPUT \
    --user elastic:changeme \
    'https://localhost:9200/_xpack/security/user/elastic/_password' \
    --header "Content-Type: application/json" \
    --data "{
        \"password\" : \"${ELASTIC_PASSWORD}\"
      }"

  curl \
    --insecure \
    -XPUT \
    --user elastic:${ELASTIC_PASSWORD} \
    'https://localhost:9200/_xpack/security/user/kibana/_password' \
    --header "Content-Type: application/json" \
    --data "{
        \"password\" : \"${KIBANA_PASSWORD}\"
      }"

  curl \
    --insecure \
    -XPUT \
    --user elastic:${ELASTIC_PASSWORD} \
    'https://localhost:9200/_xpack/security/user/logstash_system/_password' \
    --header "Content-Type: application/json" \
    --data "{
        \"password\" : \"${LOGSTASH_PASSWORD}\"
      }"

fi

echo "elk_exogeni_postboot: DONE!"

