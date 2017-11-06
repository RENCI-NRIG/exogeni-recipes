#!/bin/bash

ELASTICSEARCH_CLUSTER_NAME=exogeni-elk
KIBANA_ADMIN_USER=${ELASTICSEARCH_CLUSTER_NAME} # for nginx
KIBANA_ADMIN_PASS=secret # for nginx
ELASTIC_PASSWORD=secret
KIBANA_PASSWORD=secret
LOGSTASH_PASSWORD=secret

# Depending on the VM size, the memory available can be less than ElasticSearch is expecting
ELASTICSEARCH_JVM_HEAP=512m

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

# Configure firewalld for Centos 7
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7
############################################################
echo "elk_exogeni_postboot: configuring firewalld"
systemctl start firewalld.service
systemctl enable firewalld

# Internal cluster traffic should be treated as 'trusted'
# not sure why this command needs to be done twice.  running only once with --permanent option doesn't change the setting.
#firewall-cmd --zone=trusted --change-interface=eth1 # only changes runtime
firewall-cmd --zone=trusted --change-interface=eth1 --permanent # only changes saved config, not runtime

# Save firewalld configuration (probably unnecessary: the '--permanent' seems like enough)
# https://serverfault.com/questions/674874/is-there-a-way-to-run-just-save-with-firewalld-in-rhel7/674887#674887
# firewall-cmd --runtime-to-permanent # only supported in Centos >= 7.1 # don't use if commands have been run with --permanent
systemctl restart firewalld.service # might be necessary after the '--runtime-to-permanent' command

# verify: firewall-cmd --get-active-zones

# kibana will be accessed (via nginx) via port 80
# to see details about a particular service: vi /usr/lib/firewalld/services/kibana.xml (e.g.)
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=kibana

# ensure configuration is saved
#firewall-cmd --runtime-to-permanent # only supported in Centos >= 7.1
systemctl restart firewalld.service # might be necessary after the '--runtime-to-permanent' command

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
xpack.security.audit.enabled: true
#
EOF

# Use a descriptive name for the node:
#sed --in-place 's/#cluster.name: my-application/cluster.name: exogeni-elk/' ${ELASTICSEARCH_CONF}

# Use a descriptive name for the node:
#sed --in-place 's/#node.name: node-1/node.name: $self.Name()/' ${ELASTICSEARCH_CONF}

# Set the bind address to a specific IP (IPv4 or IPv6):
# https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-network.html
#sed --in-place 's/#network.host: 192.168.0.1/network.host: [_eth0_, _eth1_, _local_]/' ${ELASTICSEARCH_CONF}

# Pass an initial list of hosts to perform discovery when new node is started:
#sed --in-place 's/#discovery.zen.ping.unicast.hosts: \["host1", "host2"\]/discovery.zen.ping.unicast.hosts: ["$elk0.Name()", "$elk1.Name()", "$elk2.Name()"]/' ${ELASTICSEARCH_CONF}

# Depending on the VM size, the memory available can be less than ElasticSearch is expecting
sed --in-place "s/-Xms2g/-Xms${ELASTICSEARCH_JVM_HEAP}/" ${ELASTICSEARCH_JVM_CONF}
sed --in-place "s/-Xmx2g/-Xmx${ELASTICSEARCH_JVM_HEAP}/" ${ELASTICSEARCH_JVM_CONF}

# Install X-Pack plugin into ElasticSearch
############################################################
echo "elk_exogeni_postboot: installing X-Pack plugin into ElasticSearch"
/usr/share/elasticsearch/bin/elasticsearch-plugin install --batch x-pack

# Start ElasticSearch
############################################################
systemctl start elasticsearch
systemctl enable elasticsearch

# Verify: curl -XGET 'http://localhost:9200/_cluster/state?pretty'

############################################################
# Kibana
# https://www.elastic.co/guide/en/kibana/current/rpm.html
# https://www.elastic.co/guide/en/kibana/5.6/settings.html
# https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-elk-stack-on-centos-7
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

# Specifies the address to which the Kibana server will bind. IP addresses and host names are both valid values.
# The default is 'localhost', which usually means remote machines will not be able to connect.
#sed --in-place 's/#server.host: "localhost"/server.host: "localhost"/' ${KIBANA_CONF}
sed --in-place 's/#server.host: "localhost"/server.host: "0.0.0.0"/' ${KIBANA_CONF}

# X-Pack plugin sets up password authentication
sed --in-place "s/#elasticsearch.password: \"pass\"/elasticsearch.password: \"${ELASTIC_PASSWORD}\"/" ${KIBANA_CONF}

# Install X-Pack plugin into Kibana
############################################################
echo "elk_exogeni_postboot: installing X-Pack plugin into Kibana (can be slow)"
/usr/share/kibana/bin/kibana-plugin install x-pack

# Start Kibana
############################################################
systemctl start kibana
systemctl enable kibana

############################################################
# nginx
# Use nginx to control access to the Kibana web gui
# https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-elk-stack-on-centos-7
#
# TODO: Probably not necessary if X-Pack plugin is used?
############################################################
echo "elk_exogeni_postboot: installing nginx"

yum --assumeyes install nginx httpd-tools

# setup kibana user and password
htpasswd -bc /etc/nginx/htpasswd.users ${KIBANA_ADMIN_USER} ${KIBANA_ADMIN_PASS}

# Need to remove any existing 'server' sections
cat > /etc/nginx/nginx.conf << EOF
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html\#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

}
EOF

# create a server block for Kibana
cat > /etc/nginx/conf.d/kibana.conf << EOF
server {
    listen 80;

    server_name $(neuca-get-public-ip);

    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/htpasswd.users;

    location / {
        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;        
    }
}
EOF

# start and enable nginx
systemctl start nginx
systemctl enable nginx

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
echo "elk_exogeni_postboot: installing X-Pack plugin into Logstash"
/usr/share/logstash/bin/logstash-plugin install x-pack

# start and enable logstash
systemctl start logstash
systemctl enable logstash

############################################################
# X-Pack Security
# https://www.elastic.co/guide/en/x-pack/current/security-getting-started.html
############################################################
echo "elk_exogeni_postboot: configuring X-Pack Security modules"

# The default password for the elastic user is changeme.
curl -XPUT -u elastic:changeme 'localhost:9200/_xpack/security/user/elastic/_password' -H "Content-Type: application/json" -d "{
  \"password\" : \"${ELASTIC_PASSWORD}\"
}"

curl -XPUT -u elastic:${ELASTIC_PASSWORD} 'localhost:9200/_xpack/security/user/kibana/_password' -H "Content-Type: application/json" -d "{
  \"password\" : \"${KIBANA_PASSWORD}\"
}"

curl -XPUT -u elastic:${ELASTIC_PASSWORD} 'localhost:9200/_xpack/security/user/logstash_system/_password' -H "Content-Type: application/json" -d "{
  \"password\" : \"${LOGSTASH_PASSWORD}\"
}"


