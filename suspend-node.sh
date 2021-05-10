#!/bin/bash
source /etc/JARVICE/jobenv.sh
number=$(cat /etc/slurm-llnl/jxe-$1)
curl --data-urlencode "username=$APIUSER" \
    --data-urlencode "apikey=$APIKEY" \
    --data-urlencode "number=$number" \
    "$APIURL/jarvice/shutdown"
