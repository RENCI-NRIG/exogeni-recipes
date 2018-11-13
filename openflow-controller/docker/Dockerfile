FROM centos

MAINTAINER mcevik mcevik@renci.org

RUN yum update -y &&  yum install -y wget vim lsof git

ENV RECIPE_REPO="https://github.com/RENCI-NRIG/exogeni-recipes.git" \
    RECIPE_DIR="/opt/exogeni-recipes" \
    RECIPE_APP="openflow-controller"  \
    RECIPE_FILE="ryu-install.sh"

ENV ryu_port 6653

RUN git clone  --no-checkout ${RECIPE_REPO} ${RECIPE_DIR} ; \
    cd ${RECIPE_DIR} && git config core.sparsecheckout true ; \
    echo "${RECIPE_APP}/${RECIPE_FILE}" >> .git/info/sparse-checkout ; \
    git read-tree -m -u HEAD

RUN sed -i -r  "s/(OFP_TCP_LISTEN_PORT=)\"6653\"/\1\"$ryu_port\"/g" ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
RUN chmod +x ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
RUN ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
COPY ryu_start.sh .
CMD /bin/bash ryu_start.sh; /bin/bash
