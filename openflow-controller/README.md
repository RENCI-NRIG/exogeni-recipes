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

Build container and start ryu-controller with simple_switch_13 application
```
#!/bin/bash
yum install -y yum-utils device-mapper-persistent-data lvm2 vim
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce
systemctl start docker


RECIPE_REPO="https://github.com/RENCI-NRIG/exogeni-recipes.git"
RECIPE_DIR="/opt/exogeni-recipes"
RECIPE_APP="openflow-controller/docker"
DOCKER_IMAGE="centos-ryu"
DOCKER_CONTAINER_NAME="ryu-controller"
OFP_TCP_LISTEN_PORT="6653"
RYU_APP_SIMPLE="/opt/ryu_app/simple_switch_13_custom_chameleon.py"
RYU_APP_MIRROR="/opt/ryu_app/mirror_switch_13_chameleon.py"

git clone  --no-checkout ${RECIPE_REPO} ${RECIPE_DIR}
cd ${RECIPE_DIR} && git config core.sparsecheckout true
echo "${RECIPE_APP}/*" >> .git/info/sparse-checkout
git read-tree -m -u HEAD

cd ${RECIPE_DIR}/${RECIPE_APP}
docker volume create var_run_ryu
docker volume create var_log_ryu
docker volume create opt_ryu
docker volume create opt_ryu_chameleon
sed -r -i 's/^(RYU_APP=.*)/#\1/g' ryu_start.sh
sed -r -i 's/^(OFP_TCP_LISTEN_PORT=.*)/#\1/g' ryu_start.sh
sed -r -i 's/^(RYU_REST=.*)/#\1/g' ryu_start.sh

docker build -t ${DOCKER_IMAGE} .

RYU_APP=${RYU_APP_SIMPLE}
docker run --rm -dit -p ${OFP_TCP_LISTEN_PORT}:${OFP_TCP_LISTEN_PORT} -p 8080:8080 -v opt_ryu_chameleon:/opt/ryu_chameleon -v opt_ryu:/opt/ryu -v var_log_ryu:/var/log/ryu -v var_run_ryu:/var/run/ryu -e RYU_APP=${RYU_APP} -e OFP_TCP_LISTEN_PORT=${OFP_TCP_LISTEN_PORT}  --name=${DOCKER_CONTAINER_NAME} ${DOCKER_IMAGE}

```

Rebuild container and start ryu-controller with mirror-switch application

```
DOCKER_CONTAINER_NAME="ryu-controller"
DOCKER_IMAGE="centos-ryu"
docker stop $DOCKER_CONTAINER_NAME

RECIPE_DIR="/opt/exogeni-recipes"
RECIPE_APP="openflow-controller/docker"
RYU_APP_MIRROR="/opt/ryu_app/mirror_switch_13_chameleon.py"
OFP_TCP_LISTEN_PORT="6653"

cd ${RECIPE_DIR}/${RECIPE_APP}
RYU_APP=${RYU_APP_MIRROR}
docker run --rm -dit -p ${OFP_TCP_LISTEN_PORT}:${OFP_TCP_LISTEN_PORT} -p 8080:8080 -v opt_ryu_chameleon:/opt/ryu_chameleon -v opt_ryu:/opt/ryu -v var_log_ryu:/var/log/ryu -v var_run_ryu:/var/run/ryu -e RYU_APP=${RYU_APP} -e OFP_TCP_LISTEN_PORT=${OFP_TCP_LISTEN_PORT}  --name=${DOCKER_CONTAINER_NAME} ${DOCKER_IMAGE}
```
Physical directories that are mapped to volumes are located at `/var/lib/docker/volumes/<VOLUME_NAME>/_data`
Ryu log file can be accessed from the base OS at `/var/lib/docker/volumes/var_log_ryu/_data/ryu-manager.log`
