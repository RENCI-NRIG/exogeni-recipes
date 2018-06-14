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

