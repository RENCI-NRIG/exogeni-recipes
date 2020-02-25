FROM centos:7

MAINTAINER mcevik mcevik@renci.org

RUN yum update -y \
 && yum install -y epel-release \
 && yum install -y wget vim lsof git \
 && yum install -y python2-pip \
 && pip install --upgrade pip \
 && mkdir /opt/custom /opt/ryu

RUN git clone git://github.com/osrg/ryu.git /opt/ryu \
 && cd /opt/ryu ; pip install .

RUN git clone https://github.com/ChameleonCloud/ryu.git /opt/custom \
 && ln -s /opt/custom/ryu/app/simple_switch_13_custom_chameleon.py /opt/simple_switch_13_custom_chameleon.py \
 && ln -s /opt/custom/ryu/app/ofctl_rest.py /opt/ofctl_rest.py \
 && ln -s /opt/custom/ryu/app/mirror_switch_13_chameleon.py /opt/mirror_switch_13_chameleon.py


COPY ryu_start.sh .
RUN chmod +x /ryu_start.sh
CMD /ryu_start.sh; /bin/bash
