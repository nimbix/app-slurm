#!/bin/bash
set -e
slurm_config=${1}
worker_name=${2}
sudo cp -r ${slurm_config}/* /etc/slurm-llnl/
cat /etc/slurm-llnl/slurm-headnode | sudo tee --append /etc/hosts
node=$(hostname)
cat /etc/hosts | sed "/.*${node}/s/$/ ${worker_name}/" | sudo tee /etc/hosts
cat /etc/hosts | grep ${worker_name} > ${slurm_config}/${worker_name}
sudo mkdir -p /var/run/munge && sudo chown munge:munge /var/run/munge
sudo -u munge munged -f --key-file=/etc/slurm-llnl/munge.key
sudo slurmd -D
