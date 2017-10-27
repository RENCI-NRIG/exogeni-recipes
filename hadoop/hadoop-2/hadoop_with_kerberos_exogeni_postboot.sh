#!/bin/bash

KDC_KEY=secret # Kerberos, Key Distribution Center

# CA_PASS must be exported in order for openssl command to access
export CA_PASS=secret # Certificate Authority
export KEYSTORE_PASS=secret
export TRUSTSTORE_PASS=secret

# testing:
exit

# using stable2 link for Hadoop Version
# HADOOP_VERSION=hadoop-2.7.4

# Velocity Hacks
#set( $bash_var = '${' )
#set( $bash_str_split = '#* ' )

############################################################
# setup /etc/hosts
# It's important to have lowercase hostnames for Kerberos support
############################################################
echo $namenode.IP("VLAN0") $namenode.Name() >> /etc/hosts
echo $resourcemanager.IP("VLAN0") $resourcemanager.Name() >> /etc/hosts
#set ( $sizeWorkerGroup = $workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
 echo $workers.get($j).IP("VLAN0") `echo $workers.get($j).Name() | sed 's/\//-/g'` >> /etc/hosts
#end
echo $kdc.IP("VLAN0") $kdc.Name() >> /etc/hosts

echo `echo $self.Name() | sed 's/\//-/g'` > /etc/hostname
/bin/hostname -F /etc/hostname


# Prepare Yum and Update
############################################################
yum makecache fast
#yum -y update

############################################################
# Kerberos
############################################################

# Need to ensure lots of entropy available on KDC
# http://giovannitorres.me/increasing-entropy-on-virtual-machines.html
# cat /proc/sys/kernel/random/entropy_avail 
############################################################
yum -y install rng-tools
sed -i 's/EXTRAOPTIONS=""/EXTRAOPTIONS="-r \/dev\/urandom"/' /etc/sysconfig/rngd
chkconfig rngd on
service rngd start

# Ensure NTP is setup and running
############################################################
yum -y install ntp
ntpdate clock1.unc.edu
service ntpd restart
chkconfig ntpd on

# Install Kerberos
############################################################

# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Managing_Smart_Cards/installing-kerberos.html
if [[ $self.Name() == kdc ]]
then
  yum -y install krb5-server krb5-libs krb5-auth-dialog
else
  yum -y install krb5-workstation krb5-libs krb5-auth-dialog
fi

# Configure Kerberos
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Managing_Smart_Cards/Configuring_a_Kerberos_5_Server.html

# configuration on both server and clients
#sed -i "s/EXAMPLE.COM/EXOGENI.NET/" /etc/krb5.conf
#sed -i "s/kerberos.example.com/kdc/" /etc/krb5.conf
#sed -i "s/example.com/exogeni.net/" /etc/krb5.conf

# Switch kerberos to use TCP rather than UDP
# https://stackoverflow.com/a/44228073/2955846
cat > /etc/krb5.conf << EOF
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = EXOGENI.NET
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 udp_preference_limit = 1

[realms]
 EXOGENI.NET = {
  kdc = kdc
  admin_server = kdc
 }

[domain_realm]
 .exogeni.net = EXOGENI.NET
 exogeni.net = EXOGENI.NET
EOF

# configuration only on the server
if [[ $self.Name() == kdc ]]
then
  sed -i "s/EXAMPLE.COM/EXOGENI.NET/" /var/kerberos/krb5kdc/kdc.conf
  sed -i "s/EXAMPLE.COM/EXOGENI.NET/" /var/kerberos/krb5kdc/kadm5.acl
fi

# setup krb5
# scriptable help from https://github.com/crazyadmins/useful-scripts/blob/master/ambari/setup_kerberos.sh
if [[ $self.Name() == kdc ]]
then
  # Create the database using the kdb5_util utility.
  # NOTE: password is provided by -P
  /usr/sbin/kdb5_util create -s -P ${KDC_KEY}

  # Create the first principal using kadmin.local at the KDC terminal
  # NOTE: password is provided by -pw
  /usr/sbin/kadmin.local -q "addprinc -pw ${KDC_KEY} exogeni/admin"

  service krb5kdc start
  service kadmin start
  chkconfig krb5kdc on
  chkconfig kadmin on


fi

############################################################
# Can verify Kerberos setup on other servers (e.g. namenode) like this:
#
# [root@namenode ~]# kinit exogeni/admin
# Password for exogeni/admin@EXOGENI.NET: 
# [root@namenode ~]# klist
# Ticket cache: FILE:/tmp/krb5cc_0
# Default principal: exogeni/admin@EXOGENI.NET
# 
# Valid starting     Expires            Service principal
# 09/08/17 08:35:51  09/09/17 08:35:49  krbtgt/EXOGENI.NET@EXOGENI.NET
# 	renew until 09/08/17 08:35:51
#
############################################################

############################################################
# Configure iptables (Centos 6)
############################################################
# https://www.vultr.com/docs/setup-iptables-firewall-on-centos-6
iptables -F; iptables -X; iptables -Z
#Allow all loopback (lo) traffic and drop all traffic to 127.0.0.0/8 other than lo:
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -d 127.0.0.0/8 -j REJECT
#Block some common attacks:
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
#Accept all established inbound connections:
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#Allow SSH connections:
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow internal cluster connections
iptables -I INPUT -i eth1 -p tcp -j ACCEPT

#Node specific iptables config
if [[ $self.Name() == namenode ]]
then
  # connections to namenode allowed from outside the cluster
  iptables -A INPUT -p tcp --dport 50070 -j ACCEPT #HTTP
  iptables -A INPUT -p tcp --dport 50470 -j ACCEPT #HTTPS
elif [[ $self.Name() == resourcemanager ]]
then
  # connections to resource manager from outside the cluster
  iptables -A INPUT -p tcp --dport 8088 -j ACCEPT #HTTP
  iptables -A INPUT -p tcp --dport 8090 -j ACCEPT #HTTPS
elif [[ $self.Name() == workers* ]]
then
  # TODO ?
  : #no-op
fi

# complete the iptables config
#set the default policies:
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
#Save the iptables configuration with the following command:
service iptables save

if [[ $self.Name() == kdc ]]
then
  #that's the end of the postboot script for KDC
  exit
fi

############################################################
# Hadoop
############################################################

# Install Java
############################################################
yum install -y wget java-1.8.0-openjdk-devel
#apt install -y openjdk-9-jdk

export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")

cat > /etc/profile.d/java.sh << EOF
export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

# Install Hadoop
############################################################
stable2=$(curl --location --insecure --show-error https://dist.apache.org/repos/dist/release/hadoop/common/stable2)
# stable2 should look like: link hadoop-2.7.4
HADOOP_VERSION=${bash_var}stable2${bash_str_split}}
mkdir -p /opt/${HADOOP_VERSION}

# use the suggested mirror for the actual download
#curl --location --insecure --show-error https://dist.apache.org/repos/dist/release/hadoop/common/${HADOOP_VERSION}/${HADOOP_VERSION}.tar.gz > /opt/${HADOOP_VERSION}.tgz
curl --location --insecure --show-error "https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=hadoop/common/${HADOOP_VERSION}/${HADOOP_VERSION}.tar.gz" > /opt/${HADOOP_VERSION}.tgz

tar -C /opt/${HADOOP_VERSION} --extract --file /opt/${HADOOP_VERSION}.tgz --strip-components=1
rm -f /opt/${HADOOP_VERSION}.tgz*

export HADOOP_PREFIX=/opt/${HADOOP_VERSION}
export HADOOP_YARN_HOME=${HADOOP_PREFIX}
HADOOP_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop

cat > /etc/profile.d/hadoop.sh << EOF
export HADOOP_PREFIX=${HADOOP_PREFIX}
export HADOOP_YARN_HOME=${HADOOP_PREFIX}
export HADOOP_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop
export PATH=\$HADOOP_PREFIX/bin:\$PATH
EOF

# Configure Hadoop
############################################################
CORE_SITE_FILE=${HADOOP_CONF_DIR}/core-site.xml
HDFS_SITE_FILE=${HADOOP_CONF_DIR}/hdfs-site.xml
MAPRED_SITE_FILE=${HADOOP_CONF_DIR}/mapred-site.xml
YARN_SITE_FILE=${HADOOP_CONF_DIR}/yarn-site.xml
SLAVES_FILE=${HADOOP_CONF_DIR}/slaves
SSL_CLIENT_FILE=${HADOOP_CONF_DIR}/ssl-client.xml
SSL_SERVER_FILE=${HADOOP_CONF_DIR}/ssl-server.xml
HADOOP_TRUSTSTORE=${HADOOP_CONF_DIR}/truststore.jks
HADOOP_KEYSTORE=${HADOOP_CONF_DIR}/keystore.jks

echo "hadoop_exogeni_postboot: configuring Hadoop"

cat > $CORE_SITE_FILE << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
   <name>fs.default.name</name>
   <value>hdfs://$namenode.Name():9000</value>
  </property>
  <property>
    <name>hadoop.security.authentication</name>
    <value>kerberos</value> <!-- A value of "simple" would disable security. -->
  </property>
  <property>
    <name>hadoop.security.authorization</name>
    <value>true</value>
  </property>
<!--
  <property>
    <name>hadoop.ssl.server.conf</name>
    <value>ssl-server.xml</value>
  </property>
  <property>
    <name>hadoop.ssl.client.conf</name>
    <value>ssl-client.xml</value>
  </property>
-->
</configuration>
EOF

cat > $HDFS_SITE_FILE << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
   <name>dfs.replication</name>
   <value>2</value>
  </property>

<!-- General HDFS security config -->
<property>
  <name>dfs.block.access.token.enable</name>
  <value>true</value>
</property>

<!-- NameNode security config -->
<property>
  <name>dfs.namenode.keytab.file</name>
  <value>${HADOOP_CONF_DIR}/hdfs.keytab</value> <!-- path to the HDFS keytab -->
</property>
<property>
  <name>dfs.namenode.kerberos.principal</name>
  <value>hdfs/_HOST@EXOGENI.NET</value>
</property>
<property>
  <name>dfs.namenode.kerberos.internal.spnego.principal</name>
  <value>HTTP/_HOST@EXOGENI.NET</value>
</property>

<!-- Secondary NameNode security config -->
<property>
  <name>dfs.secondary.namenode.keytab.file</name>
  <value>${HADOOP_CONF_DIR}/hdfs.keytab</value> <!-- path to the HDFS keytab -->
</property>
<property>
  <name>dfs.secondary.namenode.kerberos.principal</name>
  <value>hdfs/_HOST@EXOGENI.NET</value>
</property>
<property>
  <name>dfs.secondary.namenode.kerberos.internal.spnego.principal</name>
  <value>HTTP/_HOST@EXOGENI.NET</value>
</property>

<!-- DataNode security config -->
<property>
  <name>dfs.datanode.data.dir.perm</name>
  <value>700</value> 
</property>
<!--
<property>
  <name>dfs.datanode.address</name>
  <value>0.0.0.0:1004</value>
</property>
<property>
  <name>dfs.datanode.http.address</name>
  <value>0.0.0.0:1006</value>
</property>
-->
<property>
  <name>dfs.datanode.keytab.file</name>
  <value>${HADOOP_CONF_DIR}/hdfs.keytab</value> <!-- path to the HDFS keytab -->
</property>
<property>
  <name>dfs.datanode.kerberos.principal</name>
  <value>hdfs/_HOST@EXOGENI.NET</value>
</property>
<property>
  <name>dfs.data.transfer.protection</name>
  <value>authentication</value>
  <description>authentication : authentication only  integrity : integrity check in addition to authentication  privacy : data encryption in addition to integrity This property is unspecified by default. Setting this property enables SASL for authentication of data transfer protocol. If this is enabled, then dfs.datanode.address must use a non-privileged port, dfs.http.policy must be set to HTTPS_ONLY and the HADOOP_SECURE_DN_USER environment variable must be undefined when starting the DataNode process.
  </description>
</property>

<!-- Web Authentication config -->
<!-- WebHDFS is disabled by default -->
<property>
  <name>dfs.web.authentication.kerberos.principal</name>
  <value>HTTP/_HOST@EXOGENI.NET</value>
</property>
<property>
  <name>dfs.web.authentication.kerberos.keytab</name>
  <value>${HADOOP_CONF_DIR}/hdfs.keytab</value>
</property>

<!-- to enable TLS/SSL for HDFS -->
<property>
  <name>dfs.http.policy</name>
  <value>HTTPS_ONLY</value>
</property>

  <property>
    <name>dfs.https.server.keystore.resource</name>
    <value>ssl-server.xml</value>
  </property>
  <property>
    <name>dfs.client.https.keystore.resource</name>
    <value>ssl-client.xml</value>
  </property>

</configuration>
EOF

cat > $MAPRED_SITE_FILE << EOF
<configuration>
 <property>
   <name>mapreduce.framework.name</name>
   <value>yarn</value>
 </property>

<!-- MapReduce Job History Server security configs -->
<!-- Host and port of the MapReduce Job History Server; default port is 10020  -->
<!--
<property>
  <name>mapreduce.jobhistory.address</name>
  <value>host:port</value> 
</property>
-->
<property>
  <name>mapreduce.jobhistory.keytab</name>
  <value>${HADOOP_CONF_DIR}/mapred.keytab</value>
<!-- path to the MAPRED keytab for the Job History Server -->
</property>

<property>
  <name>mapreduce.jobhistory.principal</name>
  <value>mapred/_HOST@EXOGENI.NET</value>
</property>

<!-- To enable TLS/SSL -->
<property>
  <name>mapreduce.jobhistory.http.policy</name>
  <value>HTTPS_ONLY</value>
</property>

</configuration>
EOF

# https://www.cloudera.com/documentation/enterprise/5-6-x/topics/cdh_sg_yarn_security.html#topic_3_17
cat > $YARN_SITE_FILE << EOF
<?xml version="1.0"?>
<configuration>
<!-- Site specific YARN configuration properties -->
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>$resourcemanager.Name()</value>
  </property>
  <property>
    <name>yarn.resourcemanager.bind-host</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce_shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>

<!-- ResourceManager security configs -->
<property>
  <name>yarn.resourcemanager.keytab</name>
  <value>${HADOOP_CONF_DIR}/yarn.keytab</value>
<!-- path to the YARN keytab -->
</property>
<property>
  <name>yarn.resourcemanager.principal</name>

  <value>yarn/_HOST@EXOGENI.NET</value>
</property>

<!-- NodeManager security configs -->
<property>
  <name>yarn.nodemanager.keytab</name>
  <value>${HADOOP_CONF_DIR}/yarn.keytab</value>
<!-- path to the YARN keytab -->
</property>
<property>
  <name>yarn.nodemanager.principal</name>

  <value>yarn/_HOST@EXOGENI.NET</value>
</property>

<property>
  <name>yarn.nodemanager.container-executor.class</name>
  <value>org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor</value>
</property>

<property>
  <name>yarn.nodemanager.linux-container-executor.group</name>
  <value>yarn</value>
</property>

<!-- To enable TLS/SSL -->
<property>
  <name>yarn.http.policy</name>
  <value>HTTPS_ONLY</value>
</property>

</configuration>
EOF

cat > $SSL_CLIENT_FILE << EOF
<configuration>

<property>
  <name>ssl.client.truststore.location</name>
  <value>${HADOOP_TRUSTSTORE}</value>
  <description>Truststore to be used by clients like distcp. Must be
  specified.
  </description>
</property>

<property>
  <name>ssl.client.truststore.password</name>
  <value>${TRUSTSTORE_PASS}</value>
  <description>Optional. Default value is "".
  </description>
</property>

<property>
  <name>ssl.client.keystore.location</name>
  <value>${HADOOP_KEYSTORE}</value>
  <description>Keystore to be used by clients like distcp. Must be
  specified.
  </description>
</property>

<property>
  <name>ssl.client.keystore.password</name>
  <value>${KEYSTORE_PASS}</value>
  <description>Optional. Default value is "".
  </description>
</property>

</configuration>

EOF

cat > $SSL_SERVER_FILE << EOF
<configuration>

<property>
  <name>ssl.server.truststore.location</name>
  <value>${HADOOP_TRUSTSTORE}</value>
  <description>Truststore to be used by clients like distcp. Must be
  specified.
  </description>
</property>

<property>
  <name>ssl.server.truststore.password</name>
  <value>${TRUSTSTORE_PASS}</value>
  <description>Optional. Default value is "".
  </description>
</property>

<property>
  <name>ssl.server.keystore.location</name>
  <value>${HADOOP_KEYSTORE}</value>
  <description>Keystore to be used by clients like distcp. Must be
  specified.
  </description>
</property>

<property>
  <name>ssl.server.keystore.password</name>
  <value>${KEYSTORE_PASS}</value>
  <description>Optional. Default value is "".
  </description>
</property>

<property>
  <name>ssl.server.exclude.cipher.list</name>
  <value>TLS_ECDHE_RSA_WITH_RC4_128_SHA,SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA,
  SSL_RSA_WITH_DES_CBC_SHA,SSL_DHE_RSA_WITH_DES_CBC_SHA,
  SSL_RSA_EXPORT_WITH_RC4_40_MD5,SSL_RSA_EXPORT_WITH_DES40_CBC_SHA,
  SSL_RSA_WITH_RC4_128_MD5</value>
  <description>Optional. The weak security cipher suites that you want excluded
  from SSL communication.</description>
</property>

</configuration>
EOF

cat > $SLAVES_FILE << EOF
#set ( $sizeWorkerGroup = $workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
 `echo $workers.get($j).Name() | sed 's/\//-/g'`
#end
EOF

# Create hadoop users and setup Kerberos
# https://hadoop.apache.org/docs/r2.7.3/hadoop-project-dist/hadoop-common/SecureMode.html
############################################################
groupadd hadoop

# Ensure that HDFS and YARN daemons run as different Unix users, e.g. hdfs and yarn. Also, ensure that the MapReduce JobHistory server runs as different user such as mapred.
for user in hdfs yarn mapred
do
  useradd -U $user -G hadoop
  mkdir -p /home/$user/.ssh
done

# make the hadoop logs directory, so that it gets the correct permissions
# on datanodes, it is shared by hdfs and yarn users.
mkdir ${HADOOP_PREFIX}/logs

# make sure the hadoop user owns /opt/hadoop
chown -R hdfs:hadoop ${HADOOP_PREFIX} # yarn ?
chmod -R g+w ${HADOOP_PREFIX}

# Create the Kerberos principals for Hadoop
# https://www.cloudera.com/documentation/enterprise/5-6-x/topics/cdh_sg_kerberos_prin_keytab_deploy.html#topic_3_4

# Need to wait for KDC, and kinit
until echo "${KDC_KEY}" | kinit exogeni/admin; do sleep 2; done

for user in hdfs yarn mapred HTTP
do
  kadmin -w ${KDC_KEY} -q "addprinc -randkey ${user}/`echo $self.Name() | sed 's/\//-/g'`"
done
#kadmin -w ${KDC_KEY} -q "xst -norandkey -k hdfs.keytab hdfs/$self.Name() HTTP/$self.Name()"
#kadmin -w ${KDC_KEY} -q "xst -norandkey -k yarn.keytab yarn/$self.Name() HTTP/$self.Name()"
#kadmin -w ${KDC_KEY} -q "xst -norandkey -k mapred.keytab mapred/$self.Name() HTTP/$self.Name()"
kadmin -w ${KDC_KEY} -q "xst -k hdfs-unmerged.keytab hdfs/`echo $self.Name() | sed 's/\//-/g'`"
kadmin -w ${KDC_KEY} -q "xst -k yarn-unmerged.keytab yarn/`echo $self.Name() | sed 's/\//-/g'`"
kadmin -w ${KDC_KEY} -q "xst -k mapred-unmerged.keytab mapred/`echo $self.Name() | sed 's/\//-/g'`"
kadmin -w ${KDC_KEY} -q "xst -k http.keytab HTTP/`echo $self.Name() | sed 's/\//-/g'`"

# https://groups.google.com/forum/#!topic/comp.protocols.kerberos/k1CVskrMrMU
ktutil << EOF
rkt hdfs-unmerged.keytab
rkt http.keytab
wkt hdfs.keytab
clear
rkt mapred-unmerged.keytab
rkt http.keytab
wkt mapred.keytab
clear
rkt yarn-unmerged.keytab
rkt http.keytab
wkt yarn.keytab
exit
EOF

# deploy keytab files
mv hdfs.keytab mapred.keytab yarn.keytab ${HADOOP_CONF_DIR}
chown hdfs:hadoop ${HADOOP_CONF_DIR}/hdfs.keytab
chown yarn:hadoop ${HADOOP_CONF_DIR}/yarn.keytab
chown mapred:hadoop ${HADOOP_CONF_DIR}/mapred.keytab
chmod 400 ${HADOOP_CONF_DIR}/*.keytab

# Example of accessing HDFS from command line, with kerberos (after starting Hadoop):
# [hdfs@namenode ~]$ kinit -kt /opt/hadoop-2.7.4/etc/hadoop/hdfs.keytab -V hdfs/namenode
# [hdfs@namenode ~]$ hdfs dfs -ls /

# Generate CA and SSL certs for Hadoop on NameNode
############################################################
TEMP_CA_DIR=/root/ca
TEMP_CA_CONF=${TEMP_CA_DIR}/ca.conf
TEMP_CA_KEY=${TEMP_CA_DIR}/ca.key
TEMP_CA_CSR=${TEMP_CA_DIR}/ca.csr
TEMP_CA_CERT=${TEMP_CA_DIR}/ca.crt
TEMP_CA_CRL=${TEMP_CA_DIR}/ca.crl
TEMP_TRUSTSTORE=${TEMP_CA_DIR}/truststore.jks

CA_DOMAIN=recipes.exogeni.net
CA_NAME=exogeni-recipes
CA_CERT_C="US"
CA_CERT_ST="North Carolina"
CA_CERT_L="Chapel Hill"
CA_CERT_O="EXOGENI.net"
CA_CERT_OU="Recipes"
CA_CERT_CN="exogeni-recipes Certificate Authority"

if [[ $self.Name() == namenode ]]
then
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

  # copy the root CA cert into truststore
  keytool -importcert -noprompt -trustcacerts -alias ${CA_NAME} -file ${TEMP_CA_CERT} -keystore ${TEMP_TRUSTSTORE} -storepass ${TRUSTSTORE_PASS}
fi

# Create (signed) server certs
############################################################
TEMP_SERVER_CONF=${TEMP_CA_DIR}/server.conf
if [[ $self.Name() == namenode ]]
then

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
commonName_default		= \$ENV::CA_HOSTNAME

[ server_reqext ]
keyUsage                = critical,digitalSignature,keyEncipherment
extendedKeyUsage        = serverAuth,clientAuth
subjectKeyIdentifier    = hash
#subjectAltName          = \$ENV::SAN
EOF

  # create server cert for namenode

  for server in $namenode.Name() $resourcemanager.Name()
  do
    export CA_HOSTNAME=${server}
    TEMP_SERVER_KEY=${TEMP_CA_DIR}/${server}.server.key
    TEMP_SERVER_CSR=${TEMP_CA_DIR}/${server}.server.csr
    TEMP_SERVER_CERT=${TEMP_CA_DIR}/${server}.server.crt
    TEMP_SERVER_CRL=${TEMP_CA_DIR}/${server}.server.crl
    TEMP_SERVER_P12=${TEMP_CA_DIR}/${server}.server.p12
    TEMP_SERVER_JKS=${TEMP_CA_DIR}/${server}.server.jks

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

    openssl pkcs12 -export \
                   -in ${TEMP_SERVER_CERT} \
                   -inkey ${TEMP_SERVER_KEY} \
                   -out ${TEMP_SERVER_P12} \
                   -passin env:CA_PASS \
                   -passout env:KEYSTORE_PASS

    # import server cert and key
    keytool -importkeystore -noprompt -trustcacerts \
            -srckeystore ${TEMP_SERVER_P12} \
            -srcstoretype PKCS12 \
            -srcstorepass ${KEYSTORE_PASS} \
            -destkeystore ${TEMP_SERVER_JKS} \
            -deststoretype PKCS12 \
            -deststorepass ${KEYSTORE_PASS}
            #-destalias ${CA_HOSTNAME} 
            #-deststoretype JKS \

    # import CA cert
    keytool -importcert -noprompt -trustcacerts -alias ${CA_NAME} -file ${TEMP_CA_CERT} -keystore ${TEMP_SERVER_JKS} -storepass ${KEYSTORE_PASS}
    
  done

#set ( $sizeWorkerGroup = $workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
  server=`echo $workers.get($j).Name() | sed 's/\//-/g'`

    export CA_HOSTNAME=${server}
    TEMP_SERVER_KEY=${TEMP_CA_DIR}/${server}.server.key
    TEMP_SERVER_CSR=${TEMP_CA_DIR}/${server}.server.csr
    TEMP_SERVER_CERT=${TEMP_CA_DIR}/${server}.server.crt
    TEMP_SERVER_CRL=${TEMP_CA_DIR}/${server}.server.crl
    TEMP_SERVER_P12=${TEMP_CA_DIR}/${server}.server.p12
    TEMP_SERVER_JKS=${TEMP_CA_DIR}/${server}.server.jks

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

    openssl pkcs12 -export \
                   -in ${TEMP_SERVER_CERT} \
                   -inkey ${TEMP_SERVER_KEY} \
                   -out ${TEMP_SERVER_P12} \
                   -passin env:CA_PASS \
                   -passout env:KEYSTORE_PASS

    # import server cert and key
    keytool -importkeystore -noprompt -trustcacerts \
            -srckeystore ${TEMP_SERVER_P12} \
            -srcstoretype PKCS12 \
            -srcstorepass ${KEYSTORE_PASS} \
            -destkeystore ${TEMP_SERVER_JKS} \
            -deststoretype PKCS12 \
            -deststorepass ${KEYSTORE_PASS}
            #-destalias ${CA_HOSTNAME} 
            #-deststoretype JKS \

    # import CA cert
    keytool -importcert -noprompt -trustcacerts -alias ${CA_NAME} -file ${TEMP_CA_CERT} -keystore ${TEMP_SERVER_JKS} -storepass ${KEYSTORE_PASS}

#end

fi


# setup SSH -- needed to be able to transfer JKS files to other nodes
############################################################

# Namenode will generate private SSH key
if [[ $self.Name() == namenode ]]
then

  # files served from:
  mkdir /public_html

  for user in hdfs yarn mapred
  do
    ssh-keygen -t rsa -N "" -f /home/${user}/.ssh/id_rsa
    cat /home/${user}/.ssh/id_rsa.pub >> /home/${user}/.ssh/authorized_keys
    cp -u /home/${user}/.ssh/id_rsa.pub /public_html/${user}_id_rsa.pub
  
  done

  # allow cluster to download SSH public key
  # port is only accessible to internal cluster

  (cd /public_html; python -c 'import SimpleHTTPServer,BaseHTTPServer; BaseHTTPServer.HTTPServer(("", 8080), SimpleHTTPServer.SimpleHTTPRequestHandler).serve_forever()') &

else
  for user in hdfs yarn mapred
  do
    # Need to download SSH public key from master
    until wget -O /home/${user}/.ssh/id_rsa.pub "http://namenode:8080/${user}_id_rsa.pub"
    do
      sleep 2
    done
    cat /home/${user}/.ssh/id_rsa.pub >> /home/${user}/.ssh/authorized_keys
  done
fi

# Add host RSA keys to SSH known hosts files
# Need to wait until these succeed
for user in hdfs yarn mapred
do
    until ssh-keyscan namenode >> /home/${user}/.ssh/known_hosts; do sleep 2; done
    until ssh-keyscan resourcemanager >> /home/${user}/.ssh/known_hosts; do sleep 2; done
#set ( $sizeWorkerGroup = $workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
    until ssh-keyscan $(echo $workers.get($j).Name() | sed 's/\//-/g') >> /home/${user}/.ssh/known_hosts
    do
      sleep 2
    done
#end

  # Fix permissions in .ssh
  chown -R ${user}:${user} /home/${user}/.ssh
  chmod -R g-w /home/${user}/.ssh
  chmod -R o-w /home/${user}/.ssh

done



# see if the NameNode can copy private key to other nodes
if [[ $self.Name() == namenode ]]
then
  for user in hdfs yarn mapred
  do
    until sudo -u ${user} scp -o BatchMode=yes /home/${user}/.ssh/id_rsa resourcemanager:/home/${user}/.ssh/id_rsa; do sleep 2; done
    #set ( $sizeWorkerGroup = $workers.size() - 1 )
    #foreach ( $j in [0..$sizeWorkerGroup] )
      until sudo -u ${user} scp -o BatchMode=yes /home/${user}/.ssh/id_rsa $(echo $workers.get($j).Name() | sed 's/\//-/g'):/home/${user}/.ssh/id_rsa
      do
        sleep 2
      done
    #end
  done
fi

# transfer JKS files to other nodes
############################################################
#for user in hdfs yarn mapred
#do
user=hdfs

#  HADOOP_TRUSTSTORE=/home/${user}/.truststore
#  HADOOP_KEYSTORE=/home/${user}/.keystore

  if [[ $self.Name() == namenode ]]
  then
  
    # copy files on namenode, fix ownership and permissions. then transfer to other servers
    server=namenode
    TEMP_SERVER_JKS=${TEMP_CA_DIR}/${server}.server.jks

    cp --update ${TEMP_TRUSTSTORE} ${HADOOP_TRUSTSTORE}
    cp --update ${TEMP_SERVER_JKS} ${HADOOP_KEYSTORE}

    # make sure the hadoop user owns /opt/hadoop
    chown ${user}:hadoop ${HADOOP_TRUSTSTORE}
    chown ${user}:hadoop ${HADOOP_KEYSTORE}
    #chmod -R g+w ${HADOOP_PREFIX}

    for server in $resourcemanager.Name()
    do
      TEMP_SERVER_JKS=${TEMP_CA_DIR}/${server}.server.jks

      until sudo -u ${user} scp -o BatchMode=yes ${HADOOP_TRUSTSTORE} ${server}:${HADOOP_TRUSTSTORE}; do sleep 2; done
      until sudo -u ${user} scp -o BatchMode=yes ${HADOOP_KEYSTORE} ${server}:${HADOOP_KEYSTORE}; do sleep 2; done
    done

    #set ( $sizeWorkerGroup = $workers.size() - 1 )
    #foreach ( $j in [0..$sizeWorkerGroup] )
      server=`echo $workers.get($j).Name() | sed 's/\//-/g'`
      TEMP_SERVER_JKS=${TEMP_CA_DIR}/${server}.server.jks

      until sudo -u ${user} scp -o BatchMode=yes ${HADOOP_TRUSTSTORE} ${server}:${HADOOP_TRUSTSTORE}; do sleep 2; done
      until sudo -u ${user} scp -o BatchMode=yes ${HADOOP_KEYSTORE} ${server}:${HADOOP_KEYSTORE}; do sleep 2; done
    #end

  else
    echo "waiting for hadoop keystores"
    # other servers need to wait for files to exist
    until [[ -f ${HADOOP_TRUSTSTORE} ]] ; do sleep 2; done
    until [[ -f ${HADOOP_KEYSTORE} ]] ; do sleep 2; done

  fi

#done


# Start Hadoop
############################################################
echo "hadoop_exogeni_postboot: starting Hadoop"

if [[ $self.Name() == namenode ]]
then
  sudo -E -u hdfs $HADOOP_PREFIX/bin/hdfs namenode -format
  sudo -E -u hdfs $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start namenode
elif [[ $self.Name() == resourcemanager ]]
then
  sudo -E -u yarn $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
elif [[ $self.Name() == workers* ]]
then
  sudo -E -u hdfs $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start datanode
  sudo -E -u yarn $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager
fi
