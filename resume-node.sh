#!/bin/bash
source /etc/JARVICE/jobenv.sh
SLURM_YUMDIR="/data/slurm-rpms/slurm-19.05.5/x86_64"
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
jobscript=$(cat << EOF
if [ \$(which apt) ]; then
    SLURMDIR=/etc/slurm-llnl
    DEBIAN_FRONTEND=noninteractive sudo apt update && \
    DEBIAN_FRONTEND=noninteractive sudo apt install -yq slurmd
elif [ \$(which yum) ]; then
    SLURMDIR=/etc/slurm
    cd $SLURM_YUMDIR
    sudo yum install -y *
else
    echo \$(cat /etc/issue) not supported
fi
sudo mkdir -p \$SLURMDIR
worker_name=$nodeName
sudo cp -r ${slurm_config}/* \$SLURMDIR
cat \$SLURMDIR/slurm-headnode | sudo tee --append /etc/hosts
node=\$(hostname)
cat /etc/hosts | sed "/.*\${node}/s/$/ \${worker_name}/" | sudo tee /etc/hosts
cat /etc/hosts | grep \${worker_name} > ${slurm_config}/\${worker_name}
cat /etc/resolv.conf | sed 's/^search/& jarvice.slurm/' | sed "s/^nameserver.*/nameserver $(cat /etc/hosts | grep $(hostname) | awk '{print $1}')/" | sudo tee /etc/resolv.conf
while true; do
    if [ -f "$slurm_config/jxe-\$worker_name" ]; then
        echo "headnode ready"
        break
    fi
done
sudo mkdir -p /var/run/munge && sudo chown munge:munge /var/run/munge
sudo -u munge munged -f --key-file=\$SLURMDIR/munge.key
sudo mkdir -p /var/spool/slurmd
sudo mkdir -p /var/run/slurmd
sudo slurmd -b -D
EOF
)
jxe_job=$(cat << EOF
{
  "app": "$(echo $queue_config | jq -r .$queue.app)",
  "staging": false,
  "checkedout": false,
  "application": {
    "command": "HpcJob",
    "geometry": "1904x821"
  },
  "machine": {
    "type": "$(echo $queue_config | jq -r .$queue.machine)",
    "nodes": 1
  },
  "hpc": {
    "hpc_job_env_config": "",
    "hpc_job_script": "$(base64 -w 0 <<<$jobscript)",
    "hpc_job_shell": "/bin/bash",
    "hpc_queue": "$queue",
    "hpc_umask": 0,
    "hpc_resources": {
      "mc_name": "$(echo $queue_config | jq -r .$queue.machine)"
    }
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
        rm $slurm_config/jxe-$nodeName $slurm_config/$nodeName
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
        while true; do
            if [ -f "$slurm_config/$nodeName" ]; then
                echo "worker ready"
                break
            fi
            sleep 5
        done
        slurm_worker_config=$(cat $slurm_config/$nodeName)
        worker_ip=$(echo $slurm_worker_config | awk '{print $1}')
        echo "$nodeName.jarvice.slurm.  IN   A   $worker_ip" | sudo tee --append /root/slurm.db
        soa_update=$(sudo awk 'NR==1{$6='"$(date +\"%Y%m%M%S\")"'; print}' /root/slurm.db)
        # arecords=$(sudo cat /root/slurm.db | sed '/.*SOA.*/d')
        sudo cat /root/slurm.db | sed "1s/.*/$soa_update/" | sudo tee /root/slurm.db
        # echo $arecords | sudo tee --append /root/slurm.db
        sleep 15
        echo $slurm_worker_config | sudo tee --append /etc/hosts
        sudo scontrol update nodename=$nodeName nodeaddr=$worker_ip \
            nodehostname=$nodeName
    done
done
