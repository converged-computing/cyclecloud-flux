#!/bin/bash

# This was developed on the template included here.
# Note that this assumes running as root (not azureuser)
# chmod 600 ~/.ssh/key.pem 
# ssh -i ~/.ssh/key.pem -o 'IdentitiesOnly=yes' azureuser@<address>

export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get -y install -y curl

# Python - install mamba to get access to conda-forge
curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh > mambaforge.sh
bash mambaforge.sh -b -p /opt/conda
rm mambaforge.sh
export PATH=/opt/conda/bin:$PATH
export LD_LIBRARY_PATH=/opt/conda/lib:$LD_LIBRARY_PATH

# Install flux core and flux sched
mamba install -c conda-forge flux-core flux-sched

# A quick test! Single test instance
# flux start --test-size=4
# flux resource list
# flux run hostname
# flux run -N 4 hostname
