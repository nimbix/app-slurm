#!/bin/bash

sudo dd if=/dev/urandom bs=1 count=1024 of=/etc/slurm-llnl/munge.key &> /dev/null
sudo mkdir -p /var/run/munge && sudo chown -R munge:munge /var/run/munge
sudo -u munge munged -f --key-file=/etc/slurm-llnl/munge.key

read -r CTRLR < /etc/JARVICE/nodes
sudo sed -i "s/ControlMachine=.*/ControlMachine=${CTRLR}/" /etc/slurm-llnl/slurm.conf
sudo slurmctld -D
