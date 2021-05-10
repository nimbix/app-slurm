#!/bin/bash
source /etc/JARVICE/jobenv.sh
queue=$(echo $1 | sed 's/jarvice-//g' | sed 's/[0-9]//g')
queue_config=$(cat /etc/slurm-llnl/partitions.json)
slurm_config=$(cat /etc/slurm-llnl/slurm-configpath)
jxe_job=$(cat << EOF
{
  "app": "khill-slurm",
  "staging": false,
  "checkedout": false,
  "application": {
    "command": "Worker",
    "geometry": "1904x821",
    "parameters": {
      "CONFIG": "$slurm_config",
      "NODENAME": "$1"
    }
  },
  "machine": {
    "type": "$(echo $queue_config | jq -r .$queue.machine)",
    "nodes": 1
  },
  "vault": {
    "name": "$JARVICE_VAULT_NAME",
    "readonly": false,
    "force": false
  },
  "user": {
    "username": "$APIUSER",
    "apikey": "$APIKEY"
  }
}
EOF
)
resp=$(echo $jxe_job | curl -X POST -H "Content-Type: application/json" \
    --data-binary @- $APIURL/jarvice/submit)
number=$(echo $resp | jq -r .number)
echo $number | sudo tee /etc/slurm-llnl/jxe-$1
while true; do
        sleep 30
        job_status=$(curl --data-urlencode "username=$APIUSER" \
            --data-urlencode "apikey=$APIKEY" \
            --data-urlencode "number=$number" \
            "$APIURL/jarvice/status")
        index=$( printf '%d' $number )
        job_status=$(echo $job_status | jq -r .[\"$index\"].job_status)
        echo $job_status
        if [ "$job_status" = "PROCESSING STARTING" ]; then
                echo "worker $number online"
                break
        fi
done
sleep 5
cat $slurm_config/$1 | sudo tee --append /etc/hosts
