#!/bin/bash

# This was developed on the template included here.
# Note that this assumes running as root (not azureuser)
# Also note this takes hours - we likely will not be using this script!
# I will update it to use system libraries soon.

# chmod 600 ~/.ssh/key.pem 
# ssh -i ~/.ssh/key.pem -o 'IdentitiesOnly=yes' azureuser@<address>

export DEBIAN_FRONTEND=noninteractive
export SPACK_ROOT=/opt/spack-environment/spack
export spack_cpu_arch=x86_64

# These mostly aren't needed for spack, added anticipating vanilla build
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
    python3-yaml \
    python3-jsonschema \
    python3-pip \
    python3-cffi \
    python3 \
    pdsh \
    rdma-core \
    sudo \
    unzip \
    wget && \
    apt-get clean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# What we want to install and how we want to install it is specified in a spack.yaml
# TODO: 1. add flux security
# TODO: 2. decide on optimized build for azure (mpi, libfabric, etc)
mkdir -p /opt/spack-environment \
    &&  (echo "spack:" \
    &&   echo "  specs:" \
    &&   echo "  - openmpi@4.1.2 fabrics=ofi +legacylaunchers target=${spack_cpu_arch}" \
    &&   echo "  - flux-sched target=${spack_cpu_arch}" \
    &&   echo "  - flux-core target=${spack_cpu_arch}" \
    &&   echo "  - flux-pmix target=${spack_cpu_arch}" \
    &&   echo "  concretizer:" \
    &&   echo "    unify: true" \
    &&   echo "  config:" \
    &&   echo "    install_tree: /opt/software" \
    &&   echo "  view: /opt/view") > /opt/spack-environment/spack.yaml

# Build caches see https://cache.spack.io/tag/v0.21.0/
# NOTE: this only has flux for ubuntu 20.04

# This is a bug with py-docutils.
# spack shouldn't be trying to manage python packages, but we don't have a choice
# It's trying to copy a file from a directory that doesn't exist.
# So we just return early in the function (this is yuck)
git clone --single-branch --branch v0.21.0 https://github.com/spack/spack.git /opt/spack-environment/spack
cp /opt/spack-environment/spack/var/spack/repos/builtin/packages/py-docutils/package.py ./package.py
sed -i 's/        bin_path = self.prefix.bin/        return/g' package.py
mv ./package.py /opt/spack-environment/spack/var/spack/repos/builtin/packages/py-docutils/package.py

# This is how to get a spack prefix
# docutils_prefix=$(spack spec --format="{prefix}" py-docutils)
# mkdir -p ${docutils_prefix}/bin

cd /opt/spack-environment && \
    . spack/share/spack/setup-env.sh && \
    spack env activate . && \
    spack external find openssh && \
    spack external find cmake && \
    spack external find python && \
    spack mirror add v0.21.0 https://binaries.spack.io/v0.21.0 && \
    spack buildcache keys --install --trust && \
    python3 -m pip install docutils && \
    spack install --reuse --fail-fast --use-buildcache auto

# Strip all the binaries
find -L /opt/view/* -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip -s

# Modifications to the environment that are necessary to run
cd /opt/spack-environment && \
    . spack/share/spack/setup-env.sh && \
    spack env activate --sh -d . >> /etc/profile.d/z10_spack_environment.sh

# TODO if there is a specific user for cyclecloud, we would want it to be
# added here as such (this will be the user to run flux)
# sudo adduser --disabled-password --uid 1000 --gecos "" flux && \
#    chown -R flux /opt && \
#    sudo chmod -R +r /opt && \
#    sudo apt-get install python3-distutils && \
#    wget https://bootstrap.pypa.io/get-pip.py && \
#    sudo python3 -m pip install pyyaml jsonschema cffi
