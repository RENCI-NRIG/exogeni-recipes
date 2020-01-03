## Install OpenFlow Controller

### Ryu on ExoGENI Slice

Add the script below to the "PostBoot Script" section of the request. 
This script installs RYU on CentOS 7.

```
#!/bin/bash
yum install -y git

RECIPE_REPO="https://github.com/RENCI-NRIG/exogeni-recipes.git"
RECIPE_DIR="/opt/exogeni-recipes"
RECIPE_APP="openflow-controller"
RECIPE_FILE="ryu-install.sh"

#ryu_port=$1
ryu_port=6653

git clone  --no-checkout ${RECIPE_REPO} ${RECIPE_DIR}
cd ${RECIPE_DIR} && git config core.sparsecheckout true
echo "${RECIPE_APP}/${RECIPE_FILE}" >> .git/info/sparse-checkout
git read-tree -m -u HEAD

sed -i -r  "s/(OFP_TCP_LISTEN_PORT=)\"6653\"/\1\"$ryu_port\"/g" ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
chmod +x ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
```


### Chameleon

Heat template : <PLACEHOLDER for URL>


### Docker

```
#!/bin/bash

yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2

yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

yum install -y docker-ce

systemctl enable docker
systemctl start docker
systemctl status docker

RECIPE_REPO="https://github.com/RENCI-NRIG/exogeni-recipes.git"
RECIPE_DIR="/opt/exogeni-recipes"
RECIPE_APP="openflow-controller/docker"
DOCKER_IMAGE="centos-ryu"
DOCKER_CONTAINER_NAME="ryu-controller"


git clone  --no-checkout ${RECIPE_REPO} ${RECIPE_DIR}
cd ${RECIPE_DIR} && git config core.sparsecheckout true
echo "${RECIPE_APP}/*" >> .git/info/sparse-checkout
git read-tree -m -u HEAD

cd ${RECIPE_DIR}/${RECIPE_APP}
docker volume create var_run_ryu
docker volume create var_log_ryu
docker build -t ${DOCKER_IMAGE} .
docker run --rm -dit -p 6653:6653 -p 8080:8080 -v var_log_ryu:/var/log/ryu -v var_run_ryu:/var/run/ryu --name=${DOCKER_CONTAINER_NAME} ${DOCKER_IMAGE}

```
