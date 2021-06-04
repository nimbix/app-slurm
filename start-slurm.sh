#!/bin/bash
set -e

dir=$(mktemp -d --tmpdir=/data)

function cleanup()
{
    rm -rf $dir
}

trap cleanup EXIT

source /etc/JARVICE/jobenv.sh
curl "$APIURL""jarvice/queues?username=$APIUSER&apikey=$APIKEY&info=true" | \
        jq . | sudo tee /etc/slurm-llnl/partitions.json

sudo mkdir -p /etc/slurm-llnl/slurm.conf.d

config=$(cat /etc/slurm-llnl/partitions.json)

for q in $(echo $config | jq -r keys[]); do
        name=$(echo $config | jq -r .$q.name)
        size=$(echo $config | jq -r .$q.size)
        echo "NodeName=jarvice-${name}[1-${size}] State=CLOUD" | \
                sudo tee --append /etc/slurm-llnl/slurm.conf.d/nodes.conf
        echo "PartitionName=${name} Default=no Nodes=jarvice-${name}[1-${size}] DefaultTime=INFINITE State=UP" | \
                sudo tee --append /etc/slurm-llnl/slurm.conf.d/partitions.conf
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

wget https://github.com/coredns/coredns/releases/download/v1.8.3/coredns_1.8.3_linux_amd64.tgz.sha256
wget https://github.com/coredns/coredns/releases/download/v1.8.3/coredns_1.8.3_linux_amd64.tgz
sha256sum coredns_1.8.3_linux_amd64.tgz.sha256
tar -xf coredns_1.8.3_linux_amd64.tgz
sudo mv coredns /usr/local/bin/coredns
rm coredns_1.8.3_linux_amd64.tgz*

sudo coredns -conf /root/Corefile &

sudo dd if=/dev/urandom bs=1 count=1024 of=/etc/slurm-llnl/munge.key &> /dev/null
sudo mkdir -p /var/run/munge && sudo chown -R munge:munge /var/run/munge
sudo -u munge munged -f --key-file=/etc/slurm-llnl/munge.key

read -r CTRLR < /etc/JARVICE/nodes
sudo sed -i "s/ControlMachine=.*/ControlMachine=${CTRLR}/" /etc/slurm-llnl/slurm.conf

echo $dir | sudo tee /etc/slurm-llnl/slurm-configpath
echo "slurm dir: $dir"
cp -r /etc/slurm-llnl/* ${dir}
cat /etc/hosts | grep $(hostname) > ${dir}/slurm-headnode

sudo mkdir -p /var/run/slurmd
sudo mkdir -p /var/lib/slurmd

sudo slurmctld -D

