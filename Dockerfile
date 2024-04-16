# syntax=docker/dockerfile:1
FROM ubuntu:22.04
LABEL maintainer "Daniel R. Kerr <daniel.r.kerr@gmail.com>"
LABEL Description="CORE Docker Ubuntu Image"

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

ARG PREFIX=/usr/local
ARG BRANCH=master
ARG PROTOC_VERSION=3.19.6
ARG ARCH=aarch_64
#ARG ARCH=x86_64
ARG VENV_PATH=/opt/core/venv
ENV PATH="$PATH:${VENV_PATH}/bin"
WORKDIR /opt

# install system dependencies
#---------------------------------------
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    sudo \
    wget \
    tzdata \
    libpcap-dev \
    libpcre3-dev \
    libprotobuf-dev \
    libxml2-dev \
    protobuf-compiler \
    unzip \
    uuid-dev \
    software-properties-common && \
    apt-get autoremove -y

# install core dependencies
#---------------------------------------
RUN apt-get update -y \
 && apt-get install -qq -y libev-dev libpcap-dev libreadline-dev libxml2-dev libxslt-dev libtk-img libtool \
 && apt-get install -qq -y python3 python3-dev python3-pip python3-setuptools python3-full python3-tk pipx \
 && apt-get install -qq -y autoconf automake gawk g++ gcc git pkg-config tk sudo \
 && apt-get install -qq -y bridge-utils ebtables ethtool iproute2 nftables radvd docker.io \
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
RUN git clone https://github.com/coreemu/core && \
    cd core && \
    git checkout ${BRANCH} && \
    ./setup.sh && \
    PATH=/root/.local/bin:$PATH inv install -v -p ${PREFIX} && \
    cd /opt && \
    rm -rf ospf-mdr

# install emane
#---------------------------------------
RUN wget https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${ARCH}.zip && \
    mkdir protoc && \
    unzip protoc-${PROTOC_VERSION}-linux-${ARCH}.zip -d protoc && \
    git clone https://github.com/adjacentlink/emane.git && \
    cd emane && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make -j$(nproc)  && \
    make install && \
    cd src/python && \
    make clean && \
    PATH=/opt/protoc/bin:$PATH make && \
    ${VENV_PATH}/bin/python -m pip install . && \
    cd /opt && \
    rm -rf protoc && \
    rm -rf emane && \
    rm -f protoc-${PROTOC_VERSION}-linux-${ARCH}.zip

# configure core
#---------------------------------------
COPY icons /usr/share/core/icons/cisco

RUN apt-get update -y \
 && apt-get install -qq -y bash curl psmisc screen wget xvfb \
 && apt-get install -qq -y apache2 iptables isc-dhcp-client isc-dhcp-server mgen vsftpd \
 && apt-get install -qq -y iputils-ping moreutils net-tools scamper tcpdump traceroute tshark \
 && apt-get clean \
 && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

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
