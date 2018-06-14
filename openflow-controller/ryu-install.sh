#!/bin/bash

{
CHAMELEON_RYU_URL="https://github.com/ChameleonCloud/ryu.git"
CHAMELEON_RYU_APP="simple_switch_13_custom_chameleon.py"

yum install -y epel-release
yum install -y python-pip git
pip install ryu
pip install --upgrade pip
# Remedy some version conflicts
# These packages are already installed, ryu installation requirements are satisfied, but running the 
# code generates errors with existing versions of six and netaddr. Needs to be updated.
pip install --upgrade six
pip install --upgrade --ignore-installed netaddr

useradd openflow
usermod -s /sbin/nologin openflow


RYU_DIR="/opt/ryu"

mkdir ${RYU_DIR} && mkdir ${RYU_DIR}/repo

# Ryu Application file that is customized for Chameleon use-case
git clone ${CHAMELEON_RYU_URL} ${RYU_DIR}/repo
ln -s ${RYU_DIR}/repo/ryu/app/${CHAMELEON_RYU_APP} ${RYU_DIR}/${CHAMELEON_RYU_APP}


chown -R openflow. ${RYU_DIR}
mkdir /var/run/ryu
chown openflow. /var/run/ryu
mkdir /var/log/ryu 
chown openflow. /var/log/ryu


# OFP_TCP_LISTEN_PORT line (below) is processed in Chameleon Heat Template for user input.
# This line should not be modified.
cat << EOF > /etc/sysconfig/ryu 
RYU_PID_FILE="/var/run/ryu/ryu-manager.pid"
RYU_LOG_FILE="/var/log/ryu/ryu-manager.log"
RYU_CONFIG_DIR="/opt/ryu/etc"
RYU_APP="${RYU_DIR}/${CHAMELEON_RYU_APP}"
OFP_TCP_LISTEN_PORT="6653"
EOF


cat << EOF > /etc/systemd/system/ryu.service 
[Unit]
Description=Ryu Openflow Controller Service
After=network.target

[Service]
EnvironmentFile=/etc/sysconfig/ryu
User=openflow
ExecStart=/usr/bin/ryu-manager --pid-file \${RYU_PID_FILE} --ofp-tcp-listen-port \${OFP_TCP_LISTEN_PORT} --log-file \${RYU_LOG_FILE} \${RYU_APP}
KillMode=process
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF


cat << EOF > /etc/logrotate.d/ryu
/var/log/ryu/*.log {
    rotate 2
    missingok
    nocreate
    sharedscripts
    size 100M
    compress
    postrotate
        /bin/systemctl restart ryu.service 2> /dev/null || true
    endscript
}
EOF


# https://www.freedesktop.org/software/systemd/man/systemd-tmpfiles.html
echo "d /var/run/ryu 0775 root openflow" > /usr/lib/tmpfiles.d/ryu.conf

echo "systemctl enable ryu"
systemctl enable ryu

echo "systemctl daemon-reload"
systemctl daemon-reload

echo "systemctl restart ryu"
systemctl start ryu

echo "systemctl status ryu"
systemctl status ryu

echo "--- Postboot script done"
} > /tmp/boot.log 2>&1
