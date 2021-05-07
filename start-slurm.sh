#!/bin/bash
set -e

source /etc/JARVICE/jobenv.sh
curl "$APIURL/jarvice/queues?username=$APIUSER&apikey=$APIKEY&info=true" | \
        jq . | sudo tee /etc/slurm-llnl/partitions.json

sudo mkdir -p /etc/slurm-llnl/slurm.conf.d

config=$(cat /etc/slurm-llnl/partitions.json)

for q in $(echo $config | jq -r keys[]); do
        name=$(echo $config | jq -r .$q.name)
        size=$(echo $config | jq -r .$q.size)
        echo "NodeName=jarvice-${name}[1-${size}]" | \
                sudo tee --append /etc/slurm-llnl/slurm.conf.d/nodes.conf
        echo "PartitionName=${name} Default=no Nodes=jarvice-${name}[1-${size}] DefaultTime=INFINITE State=UP" | \
                sudo tee --append /etc/slurm-llnl/slurm.conf.d/partitions.conf
done

sudo dd if=/dev/urandom bs=1 count=1024 of=/etc/slurm-llnl/munge.key &> /dev/null
sudo mkdir -p /var/run/munge && sudo chown -R munge:munge /var/run/munge
sudo -u munge munged -f --key-file=/etc/slurm-llnl/munge.key

read -r CTRLR < /etc/JARVICE/nodes
sudo sed -i "s/ControlMachine=.*/ControlMachine=${CTRLR}/" /etc/slurm-llnl/slurm.conf

dir=$(mktemp -d --tmpdir=/data)
echo "slurm dir: $dir"
cp -r /etc/slurm-llnl/* ${dir}
cat /etc/hosts | grep $(hostname) > ${dir}/slurm-headnode

sudo slurmctld -D

