FROM ubuntu:22.04
LABEL maintainer "Daniel R. Kerr <daniel.r.kerr@gmail.com>"

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

# install core dependencies
#---------------------------------------
RUN apt-get update -y \
 && apt-get install -qq -y libev-dev libpcap-dev libreadline-dev libxml2-dev libxslt-dev libtk-img libtool \
 && apt-get install -qq -y python3 python3-dev python3-pip python3-setuptools python3-full python3-tk pipx \
 && apt-get install -qq -y autoconf automake gawk g++ gcc git pkg-config tk sudo \
 && apt-get install -qq -y bridge-utils ebtables ethtool iproute2 radvd \
 && apt-get clean \
 && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# install ospf mdf
#---------------------------------------
RUN git clone https://github.com/USNavalResearchLaboratory/ospf-mdr.git /opt/ospf-mdr \
 && cd /opt/ospf-mdr \
 && ./bootstrap.sh \
 && ./configure \
    --disable-doc \
    --enable-group=root \
    --enable-user=root \
    --enable-vtysh \
    --localstatedir=/var/run/quagga \
    --sysconfdir=/usr/local/etc/quagga \
    --with-cflags=-ggdb \
 && make -j$(nproc) \
 && make install \
 && cd \
 && rm -rf /opt/ospf-mdr

# install core
#---------------------------------------
RUN pip3 install --upgrade pip \
 && pip3 install cython \
 && pip3 install dataclasses fabric grpcio==1.54.2 grpcio-tools==1.54.2 lxml mako netaddr netifaces Pillow poetry psutil pyyaml \
 && pip3 install pyproj

RUN git clone -b release-9.0.3 https://github.com/coreemu/core.git /opt/core \
 && cd /opt/core \
 && ./setup.sh \
# && source /root/.bashrc \
 && apt update \
 && inv install \
 && mkdir -p /etc/core \
 && cp -n /opt/core/package/etc/core.conf /etc/core \
 && cp -n /opt/core/package/etc/logging.conf /etc/core \
 && cp /opt/core/venv/bin/core-cleanup /usr/local/bin/core-cleanup \
 && cp /opt/core/venv/bin/core-cli /usr/local/bin/core-cli \
 && cp /opt/core/venv/bin/core-daemon /usr/local/bin/core-daemon \
 && cp /opt/core/venv/bin/core-gui /usr/local/bin/core-gui \
 && cp /opt/core/venv/bin/core-player /usr/local/bin/core-player \
 && cp /opt/core/venv/bin/core-route-monitor /usr/local/bin/core-route-monitor \
 && cp /opt/core/venv/bin/core-service-update /usr/local/bin/core-service-update \
 && cd /opt/core/daemon \
 && poetry build -f wheel \
 && pip3 install /opt/core/daemon/dist/* \
 && cd
# && rm -rf /opt/core

ENV PYTHONPATH "${PYTHONPATH}:/usr/local/lib/python3.10/site-packages"

# configure core
#---------------------------------------
COPY icons /usr/share/core/icons/cisco

RUN apt-get update -y \
 && apt-get install -qq -y bash curl psmisc screen wget xvfb \
 && apt-get install -qq -y apache2 iptables isc-dhcp-client isc-dhcp-server mgen vsftpd \
 && apt-get install -qq -y iputils-ping moreutils net-tools scamper tcpdump traceroute tshark \
 && apt-get clean \
 && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# install emanes
#---------------------------------------
#RUN wget -O /opt/emane.tgz https://adjacentlink.com/downloads/emane/emane-1.2.5-release-1.ubuntu-18_04.amd64.tar.gz \
# && cd /opt \
# && tar xzf /opt/emane.tgz \
# && cd /opt/emane-1.2.5-release-1/debs/ubuntu-18_04/amd64 \
# && dpkg -i *.deb \
# && apt-get install -f \
# && cd /root \
# && rm -rf /opt/emane.tgz /opt/emane-1.2.5-release-1

# install and configure ssh
#---------------------------------------
RUN apt-get update -y \
 && apt-get install -qq -y openssh-server \
 && apt-get clean \
 && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

RUN mkdir /var/run/sshd \
 && mkdir /root/.ssh \
 && chmod 700 /root/.ssh \
 && chown root:root /root/.ssh \
 && touch /root/.ssh/authorized_keys \
 && chmod 600 /root/.ssh/authorized_keys \
 && chown root:root /root/.ssh/authorized_keys \
 && echo "\nX11UseLocalhost no\n" >> /etc/ssh/sshd_config

# install and configure supervisord
#---------------------------------------
RUN apt-get update -y \
 && apt-get install -qq -y supervisor \
 && apt-get clean \
 && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

COPY supervisord.conf /etc/supervisor/conf.d/core.conf

# startup configuration
#---------------------------------------
EXPOSE 22
EXPOSE 50051

WORKDIR /root
CMD ["/usr/bin/supervisord", "--nodaemon"]
