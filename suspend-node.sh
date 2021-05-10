#!/bin/bash
source /etc/JARVICE/jobenv.sh
number=$(cat /etc/slurm-llnl/jxe-$1)
sudo rm /etc/slurm-llnl/jxe-$1
cat /etc/hosts | sed 's/.*$1//g' | sudo tee /etc/hosts
curl --data-urlencode "username=$APIUSER" \
    --data-urlencode "apikey=$APIKEY" \
    --data-urlencode "number=$number" \
    "$APIURL/jarvice/shutdown"
