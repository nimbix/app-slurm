#!/bin/bash
#
# Copyright (c) 2021, Nimbix, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are 
# those of the authors and should not be interpreted as representing official 
# policies, either expressed or implied, of Nimbix, Inc.
#
JARVICE_ID_USER=$USER
if [ -f /var/run/jxe-slurm.pid ]; then
    exit 0
else
    echo $$ > /var/run/jxe-slurm.pid
fi
set -e
OS_ID=$((cat /etc/os-release | grep ^ID_LIKE= || cat /etc/os-release | grep ^ID=) | cut -d = -f2 | tr -d '"')
OS_ID=$(echo $OS_ID | grep -o debian || echo $OS_ID | grep -o fedora)
if [ "$OS_ID" = "debian" ]; then
    SLURM_INSTALL="/etc/slurm-llnl"
else
    SLURM_INSTALL="/etc/slurm"
fi

function cleanup()
{
    sudo rm /var/run/jxe-slurm.pid
}

trap cleanup SIGINT SIGTERM ERR EXIT

source /etc/JARVICE/jobenv.sh
curl "$APIURL""jarvice/queues?username=$APIUSER&apikey=$APIKEY&info=true" | \
        jq . | sudo tee $SLURM_INSTALL/partitions.json

sudo mkdir -p $SLURM_INSTALL/slurm.conf.d

config=$(cat $SLURM_INSTALL/partitions.json)

for q in $(echo $config | jq -r keys[]); do
        name=$(echo $config | jq -r .$q.name)
        size=$(echo $config | jq -r .$q.size)
        machine=$(echo $config | jq -r .$q.machine)
        resp=$(curl "$APIURL""jarvice/machines?username=$APIUSER&apikey=$APIKEY&name=$machine" | \
            jq .$machine)
        cpu=$(echo $resp | jq -r .mc_cores)
        ram=$(( $(echo $resp | jq -r .mc_ram) * 1024 ))
        echo "NodeName=jarvice-${name}[1-${size}] CPUs=${cpu} RealMemory=${ram} State=CLOUD" | \
                sudo tee --append $SLURM_INSTALL/slurm.conf.d/nodes.conf
        echo "PartitionName=${name} Default=no Nodes=jarvice-${name}[1-${size}] DefaultTime=INFINITE State=UP" | \
                sudo tee --append $SLURM_INSTALL/slurm.conf.d/partitions.conf
done

dns_corefile=$(cat <<EOF
. {
    forward . /etc/resolv.conf
    log
    errors
}
auto jarvice.slurm {
    file /root/slurm.db
    log
    errors
    reload 15s
}
EOF
)

dns_slurm=$(cat <<EOF
jarvice.slurm.      IN  SOA dns.jarvice.slurm. admin.jarvice.slurm. $(date +"%Y%m%M%S") 7200 3600 1209600 3600
dns.jarvice.slurm.  IN  A  $(cat /etc/hosts | grep $(hostname) | awk '{print $1}')
EOF
)

printf "$dns_corefile\n" | sudo tee /root/Corefile
printf "$dns_slurm\n" | sudo tee /root/slurm.db

sudo /usr/local/bin/coredns -conf /root/Corefile &

sudo mkdir -p /var/run/munge && sudo chown -R munge:munge /var/run/munge
if [ -f "/etc/JARVICE/munge.key" ]; then
    MUNGE_SRC=/opt/JARVICE/munge.key
else
    MUNGE_SRC=/dev/urandom
fi
sudo dd if=$MUNGE_SRC bs=1 count=1024 of=$SLURM_INSTALL/munge.key &> /dev/null
sudo -u munge munged -f --key-file=$SLURM_INSTALL/munge.key

read -r CTRLR < /etc/JARVICE/nodes
sudo sed -i "s/ControlMachine=.*/ControlMachine=${CTRLR}/" $SLURM_INSTALL/slurm.conf
sudo sed -i "s/JARVICE_USER/${JARVICE_ID_USER}/" $SLURM_INSTALL/slurm.conf

sudo chmod -R 755 ${SLURM_INSTALL}

cat /etc/hosts | grep $(hostname) | sudo tee ${SLURM_INSTALL}/slurm-headnode
tar -C $SLURM_INSTALL/.. -cvf /tmp/slurm.tar $(basename $SLURM_INSTALL)

sudo mkdir -p /var/run/slurmd
sudo mkdir -p /var/lib/slurmd
sudo mkdir -p /var/log/slurm
sudo chown -R $JARVICE_ID_USER:$JARVICE_ID_USER /var/run/slurmd
sudo chown -R $JARVICE_ID_USER:$JARVICE_ID_USER /var/lib/slurmd
sudo chown -R $JARVICE_ID_USER:$JARVICE_ID_USER /var/log/slurm

slurmctld -D

