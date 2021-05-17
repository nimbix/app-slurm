#!/bin/bash
source /etc/JARVICE/jobenv.sh
queue=$(echo $1 | sed 's/jarvice-//g' | sed 's/[[]*[0-9].*//g')
queue_config=$(cat /etc/slurm-llnl/partitions.json)
slurm_config=$(cat /etc/slurm-llnl/slurm-configpath)
# Check if range of nodes is specified
for group in $(echo $1 | sed -r 's/(.*[a-zA-z]+)([0-9]+)$/[\2]/' \
    | awk -F'[][]' '{print $2}' | tr "," "\n"); do
    myRange=$group
    if [ -z "$myRange" ]; then
        myNumber=$(echo $group | grep -Eo '[0-9]+$')
        myRange="$myNumber-$myNumber"
    fi
    loopSeq=$(seq $(cut -d'-' -f1 <<<$myRange) $(cut -d'-' -f2 <<<$myRange))
    for index in $loopSeq; do
        nodeName="jarvice-$queue$index"
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
      "NODENAME": "$nodeName"
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
        rm $slurm_config/jxe-$nodeName
        resp=$(echo $jxe_job | curl -X POST \
            -H "Content-Type: application/json" \
            --data-binary @- "$APIURL"jarvice/submit)
        number=$(echo $resp | jq -r .number)
        echo $number | sudo tee /etc/slurm-llnl/jxe-$nodeName
        while true; do
            sleep 15
            job_status=$(curl --data-urlencode "username=$APIUSER" \
                --data-urlencode "apikey=$APIKEY" \
                --data-urlencode "number=$number" \
                "$APIURL""jarvice/status")
            index=$( printf '%d' $number )
            job_status=$(echo $job_status | jq -r .[\"$index\"].job_status)
            echo $job_status
            if [ "$job_status" = "PROCESSING STARTING" ]; then
                echo "worker $number online"
                break
            fi
        done
        touch $slurm_config/jxe-$nodeName
        slurm_worker_config=$(cat $slurm_config/$nodeName)
        worker_ip=$(echo $slurm_worker_config | awk '{print $1}')
        echo $slurm_worker_config | sudo tee --append /etc/hosts
        sudo scontrol update nodename=$nodeName nodeaddr=$worker_ip \
            nodehostname=$nodeName
    done
done
