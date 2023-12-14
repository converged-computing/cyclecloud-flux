#!/bin/bash

# This was developed on the template included here.
# Note that this assumes running as root (not azureuser)
# chmod 600 ~/.ssh/key.pem 
# ssh -i ~/.ssh/key.pem -o 'IdentitiesOnly=yes' azureuser@<address>

export DEBIAN_FRONTEND=noninteractive

apt-get update && \
   apt-get -y install \
    apt-utils \
    autotools-dev \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    dnsutils \
    libfftw3-dev \
    libfftw3-3 \
    gfortran \
    git \
    flex \
    libtool \
    libyaml-cpp-dev \
    libedit-dev \
    libnuma-dev \
    libgomp1 \
    libboost-graph-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-regex-dev \
    munge \
    openssh-server \
    openssh-client \
    pkg-config \
    python3-yaml \
    python3-jsonschema \
    python3-pip \
    python3-cffi \
    python3 \
    pdsh \
    sudo \
    unzip \
    wget 

# Python - instead of a system python we install mamba
curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh > mambaforge.sh
bash mambaforge.sh -b -p /opt/conda
rm mambaforge.sh
export PATH=/opt/conda/bin:$PATH
export LD_LIBRARY_PATH=/opt/conda/lib:$LD_LIBRARY_PATH
pip install --upgrade --ignore-installed \
    "markupsafe==2.0.0" \
    coverage cffi ply six pyyaml "jsonschema>=2.6,<4.0" \
    sphinx sphinx-rtd-theme sphinxcontrib-spelling

# Other deps
apt-get update && \
    apt-get -qq install -y --no-install-recommends \
        libsodium-dev \
        libzmq3-dev \
        libczmq-dev \
        libjansson-dev \
        libmunge-dev \
        libncursesw5-dev \
        lua5.2 \
        liblua5.2-dev \
        liblz4-dev \
        libsqlite3-dev \
        uuid-dev \
        libhwloc-dev \
        libmpich-dev \
        libs3-dev \
        libevent-dev \
        libarchive-dev \
        libpam-dev && \
    rm -rf /var/lib/apt/lists/*

# Testing utils and libs
apt-get update && \
    apt-get -qq install -y --no-install-recommends \
        faketime \
        libfaketime \
        luarocks \
        pylint \
        cppcheck \
        enchant-2 \
        aspell \
        aspell-en && \
    rm -rf /var/lib/apt/lists/*

locale-gen en_US.UTF-8

# Install openpmix, prrte
git clone https://github.com/openpmix/openpmix.git && \
    git clone https://github.com/openpmix/prrte.git && \
    ls -l && \
    set -x && \
    cd openpmix && \
    git checkout fefaed568f33bf86f28afb6e45237f1ec5e4de93 && \
    ./autogen.pl && \
    PYTHON=/opt/conda/bin/python ./configure --prefix=/usr --disable-static && make -j 4 install && \
    ldconfig && \
    cd .. && \
    cd prrte && \
    git checkout 477894f4720d822b15cab56eee7665107832921c && \
    ./autogen.pl && \
    PYTHON=/opt/conda/bin/python ./configure --prefix=/usr && make -j 4 install && \
    cd ../.. && \
    rm -rf prrte

export LANG=C.UTF-8

# Install flux-security
export FLUX_SECURITY_VERSION=0.8.0
git clone --depth 1 https://github.com/flux-framework/flux-security /opt/flux-security
cd /opt/flux-security && \
    ./autogen.sh && \
    PYTHON=/opt/conda/bin/python ./configure --prefix=/usr --sysconfdir=/etc && \
    make && \
    make install && \
    cd .. && \
    rm -rf flux-security

# TODO: if azureuser needs sudo access (these are already defined)
# set -x && groupadd -g $UID $USER
# useradd -g $USER -u $UID -d /home/$USER -m $USER
# printf "$USER ALL= NOPASSWD: ALL\\n" >> /etc/sudoers

# Setup MUNGE directories & key
mkdir -p /var/run/munge && \
    dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key && \
    chown -R munge /etc/munge/munge.key /var/run/munge && \
    chmod 600 /etc/munge/munge.key

# Build flux core
git clone https://github.com/flux-framework/flux-core /opt/flux-core
cd /opt/flux-core
./autogen.sh && \
    PYTHON=/opt/conda/bin/python PYTHON_PREFIX=PYTHON_EXEC_PREFIX=/opt/conda/lib/python3.10/site-packages ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --with-systemdsystemunitdir=/etc/systemd/system \
        --localstatedir=/var \
        --with-flux-security && \
    make clean && \
    make && \
    make install

# This is from the same src/test/docker/bionic/Dockerfile but in flux-sched
# Flux-sched deps
apt-get update
apt-get -qq install -y --no-install-recommends \
    libboost-graph-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-regex-dev \
    libyaml-cpp-dev \
    libedit-dev

# Build Flux Sched	
# https://github.com/flux-framework/flux-sched/blob/master/src/test/docker/docker-run-checks.sh#L152-L158
git clone https://github.com/flux-framework/flux-sched /opt/flux-sched 
cd /opt/flux-sched
git fetch && git checkout v0.31.0
./autogen.sh && \
    PYTHON=/opt/conda/bin/python ./configure --prefix=/usr --sysconfdir=/etc \
       --localstatedir=/var
    make && \
    make install && \
    ldconfig

# A quick test! Single test instance
# flux start --test-size=4
# flux resource list
# flux run hostname
# flux run -N 4 hostname

# Clean up a bit
apt-get clean
apt-get autoremove
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
