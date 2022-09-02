FROM rockylinux:8

MAINTAINER mcevik mcevik@renci.org

RUN dnf update -y \
 && dnf install -y epel-release \
 && dnf install -y wget vim lsof git \
 && dnf install -y python3-pip \
 && mkdir /opt/ryu /opt/ryu_chameleon

RUN git clone https://github.com/faucetsdn/ryu.git /opt/ryu \
 && cd /opt/ryu ; pip3 install .

RUN git clone https://github.com/ChameleonCloud/ryu.git /opt/ryu_chameleon \
 && ln -s /opt/ryu_chameleon/ryu/app /opt/ryu_app

COPY ryu.conf /opt/ryu_app/ryu.conf
COPY ryu_start.sh .
RUN chmod +x /ryu_start.sh
CMD /ryu_start.sh; /bin/bash

