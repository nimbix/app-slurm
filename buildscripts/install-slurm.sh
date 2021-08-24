#!/bin/bash
set -e
set -x
SLURM_PLUGIN_INSTALL="/usr/lib/jarvice.slurm"
OS_ID=$((cat /etc/os-release | grep ^ID_LIKE= || cat /etc/os-release | grep ^ID=) | cut -d = -f2 | tr -d '"')
OS_ID=$(echo $OS_ID | grep -o debian || echo $OS_ID | grep -o fedora)
if [ "$OS_ID" = "debian" ]; then
    SLURMDIR="/etc/slurm-llnl"
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get -yq install slurmctld slurmd jq sudo
else
    SLURM_VERSION=${SLURM_VERSION:-19.05.5}
    SLURMDIR="/etc/slurm"
    cd /usr/lib/slurm/slurm-${SLURM_VERSION}
    yum install -y epel-release
    yum -y install jq sudo *.rpm
    sed -i 's/slurm-llnl/slurm/' /tmp/slurm.conf
fi
mkdir -p "${SLURM_PLUGIN_INSTALL}/scripts"
# move scripts to slurm installation
mv /tmp/start-slurm.sh \
    /tmp/suspend-node.sh \
    /tmp/resume-node.sh \
    /tmp/resume-group.sh \
    "${SLURM_PLUGIN_INSTALL}/scripts/"
mv /tmp/slurm.conf ${SLURMDIR}
exit 0
