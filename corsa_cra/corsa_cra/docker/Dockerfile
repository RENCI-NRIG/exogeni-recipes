FROM ubuntu:14.04

# https://github.com/phusion/baseimage-docker/issues/58
ENV DEBIAN_FRONTEND noninteractive

# COPY corsa_cra/ubuntu/sources.list /etc/apt/sources.list

RUN apt-get update && apt-get -y upgrade 

# https://forums.docker.com/t/error-in-docker-image-creation-invoke-rc-d-policy-rc-d-denied-execution-of-restart-start/880
RUN echo exit 0 > /usr/sbin/policy-rc.d

RUN apt-get install -y telnet \
 && apt-get install -y vim \
 && apt-get install -y libzmq1 \
 && apt-get install -y libevent-2.0-5 \
 && apt-get install -y libevent-openssl-2.0-5 \
 && apt-get install -y libevent-core-2.0-5 \
 && apt-get install -y libevent-pthreads-2.0-5 \
 && apt-get install -y libyaml-0-2 \
 && apt-get install -y libjsoncpp0 \
 && apt-get install -y libprotobuf8 \
 && apt-get install -y arping \
 && apt-get install -y ndisc6 \
 && apt-get install -y libboost-filesystem1.54.0 \
 && apt-get install -y libboost-iostreams1.54.0 \
 && apt-get install -y libboost-log1.54.0 \
 && apt-get install -y libboost-system1.54.0 \
 && apt-get install -y libboost-thread1.54.0

# Build quagga
RUN apt-get install -y \
 git wget gawk \
 texinfo libreadline-dev \
 build-essential

RUN useradd -m dev
RUN useradd -d /var/run/quagga/ -s /bin/false -c 'Quagga routing suite' \
    -m quagga \
 && groupadd quaggavty

RUN su - dev -c 'wget http://download.savannah.gnu.org/releases/quagga/quagga-1.0.20160315.tar' \
 && su - dev -c 'tar xf quagga-1.0.20160315.tar'


RUN su - dev -c 'cd quagga-1.0.20160315 &&  \
./configure -build=x86_64-linux-gnu --prefix=/usr \
  --includedir=${prefix}/include --mandir=${prefix}/share/man \
  --infodir=${prefix}/share/info --sysconfdir=/etc --localstatedir=/var \
  --libexecdir=${prefix}/lib/quagga-test --disable-maintainer-mode \
  --disable-dependency-tracking \
  --enable-exampledir=/usr/share/doc/quagga/examples/ \
  --localstatedir=/var/run/quagga --sbindir=/usr/lib/quagga \
  --sysconfdir=/etc/quagga --enable-vtyshb --enable-isisd --enable-pimd \
  --enable-watchquagga --enable-ospf-te --enable-opaque-lsa --enable-ipv6 \
  --enable-ospfclient=yes --enable-ospfapi=yes --enable-multipath=64 \
  --enable-user=quagga --enable-group=quagga --enable-vty-group=quaggavty \
  --enable-configfile-mask=0640 --enable-logfile-mask=0640 --enable-rtadv \
  --enable-gcc-rdynamic --enable-tcp-zebra --enable-fpm --enable-isis-topology \
  --with-libpam --with-pkg-extra-version=-ci.NetDEF.org-20160610.130007-git.5f6788i \
&& make'
RUN cd ~dev/quagga-1.0.20160315 && make install

COPY corsa_cra/quagga/bgpd.conf /etc/quagga/bgpd.conf 
COPY corsa_cra/quagga/zebra.conf /etc/quagga/zebra.conf 
COPY corsa_cra/quagga/vtysh.conf /etc/quagga/vtysh.conf 
COPY corsa_cra/quagga/debian.conf /etc/quagga/debian.conf 
COPY corsa_cra/quagga/etc_initd_quagga /etc/init.d/quagga 
COPY corsa_cra/quagga/daemons /etc/quagga/daemons 
COPY corsa_cra/cra/etc_corsa-app-cra.conf /etc/corsa-app-cra.conf 
COPY corsa_cra/cra/etc_initd_corsa-cra-app /etc/init.d/corsa-cra-app 
COPY corsa_cra/cra/etc_logrotated_corsa-cra-app /etc/logrotate.d/corsa-cra-app 
COPY corsa_cra/cra/K10corsa-cra-app /etc/rc0.d/K10corsa-cra-app 
COPY corsa_cra/cra/K10corsa-cra-app /etc/rc1.d/K10corsa-cra-app 
COPY corsa_cra/cra/K10corsa-cra-app /etc/rc6.d/K10corsa-cra-app 
COPY corsa_cra/cra/S90corsa-cra-app /etc/rc2.d/S90corsa-cra-app 
COPY corsa_cra/cra/S90corsa-cra-app /etc/rc3.d/S90corsa-cra-app 
COPY corsa_cra/cra/S90corsa-cra-app /etc/rc4.d/S90corsa-cra-app 
COPY corsa_cra/cra/S90corsa-cra-app /etc/rc5.d/S90corsa-cra-app 
COPY corsa_cra/cra/usr_bin_corsa-cra-app /usr/bin/corsa-cra-app 
COPY corsa_cra/cra/libcorsa_app.so.0.0.0 /usr/lib/x86_64-linux-gnu/libcorsa_app.so.0.0.0 
COPY corsa_cra/cra/libfluid_base.so.0.0.0 /usr/lib/x86_64-linux-gnu/libfluid_base.so.0.0.0 
COPY corsa_cra/cra/libfluid_msg.so.0.0.0 /usr/lib/x86_64-linux-gnu/libfluid_msg.so.0.0.0 
COPY corsa_cra/cra/start_cra.sh start_cra.sh

RUN chown quagga:quaggavty /etc/quagga/vtysh.conf
RUN mkdir /var/log/quagga && chown quagga: /var/log/quagga
RUN cd /usr/lib/x86_64-linux-gnu \
 && ln -s libcorsa_app.so.0.0.0 libcorsa_app.so.0 \
 && ln -s libfluid_base.so.0.0.0 libfluid_base.so.0 \
 && ln -s libfluid_msg.so.0.0.0 libfluid_msg.so.0 \
 && chown -R quagga.quagga /etc/quagga \
 && chmod +x /start_cra.sh

CMD echo "net.ipv4.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf \
 && echo "net.ipv4.conf.default.forwarding=1" | sudo tee -a /etc/sysctl.conf \
 && sed 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf | sudo tee /etc/sysctl.conf \
 && echo "net.ipv6.conf.default.forwarding=1" | sudo tee -a /etc/sysctl.conf \
 && sudo sysctl -p  \
 && echo "net.ipv4.conf.all.mc_forwarding=1" | sudo tee -a /etc/sysctl.conf \
 && echo "net.ipv4.conf.default.mc_forwarding=1" | sudo tee -a /etc/sysctl.conf \
 && sudo sysctl -p

#CMD  /bin/bash 
CMD /start_cra.sh ; /bin/bash

