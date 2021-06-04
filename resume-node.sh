#!/bin/bash
source /etc/JARVICE/jobenv.sh
SLURM_YUMDIR="/data/slurm-rpms/slurm-19.05.5/x86_64"
queue=$(echo $1 | sed 's/jarvice-//g' | sed 's/[[]*[0-9].*//g')
queue_config=$(cat /etc/slurm-llnl/partitions.json)
slurm_config=$(cat /etc/slurm-llnl/slurm-configpath)
# Check if range of nodes is specified
for group in $(echo $1 | sed -r 's/(.*[a-zA-Z]+)([0-9]+)$/[\2]/' \
    | awk -F'[][]' '{print $2}' | tr "," "\n"); do
    myRange=$group
    loopSeq=$(seq $(cut -d'-' -f1 <<<$myRange) $(cut -d'-' -f2 <<<$myRange))
    nodeCount=$(echo $loopSeq | wc -w)

    indexStart=$(echo $loopSeq | awk '{print $1}')
jobscript=$(cat << EOF
if [ "\$1" != "worker" ]; then
    myHost=\$(hostname)
    while IFS= read -r node; do
        if [ "\$node" != "\$myHost" ]; then
            echo "Setting up node: \$node"
            while ! 2> /dev/null > /dev/tcp/\$node/22; do
                sleep 1
            done
            scp /opt/JARVICE/jobscript \$node:/tmp
            (ssh -n \$node "nohup bash /tmp/jobscript worker &> /dev/null") &
        fi
    done < /etc/JARVICE/nodes
fi
if [ \$(which apt) ]; then
    SLURMDIR=/etc/slurm-llnl
    DEBIAN_FRONTEND=noninteractive sudo apt update && \
    DEBIAN_FRONTEND=noninteractive sudo apt install -yq slurmd
elif [ \$(which yum) ]; then
    SLURMDIR=/etc/slurm
    cd $SLURM_YUMDIR
    sudo yum install -y slurm-19.05.5-1.el7.x86_64.rpm \
        slurm-perlapi-19.05.5-1.el7.x86_64.rpm \
        slurm-slurmd-19.05.5-1.el7.x86_64.rpm \
        mariadb-libs-5.5.68-1.el7.x86_64.rpm \
        munge-0.5.11-3.el7.x86_64.rpm \
        munge-libs-0.5.11-3.el7.x86_64.rpm rrdtool-1.4.8-9.el7.x86_64.rpm
else
    echo \$(cat /etc/issue) not supported
    exit 1
fi
sudo mkdir -p \$SLURMDIR
node_rank=\$(cat /etc/JARVICE/nodes | grep -n \$(hostname) | \
    sed -r 's/([0-9]+):.*$/\1/')
node_rank=\$(( \$node_rank + $indexStart - 1 ))
worker_name="jarvice-$queue\$node_rank"
sudo cp -r ${slurm_config}/* \$SLURMDIR
cat \$SLURMDIR/slurm-headnode | sudo tee --append /etc/hosts
node=\$(hostname)
cat /etc/hosts | sed "/.*\${node}/s/$/ \${worker_name}/" | sudo tee /etc/hosts
cat /etc/hosts | grep \${worker_name} > ${slurm_config}/\${worker_name}
cat /etc/resolv.conf | sed 's/^search/& jarvice.slurm/' | \
    sed "s/^nameserver.*/nameserver $(cat /etc/hosts | grep $(hostname) | \
    awk '{print $1}')/" | sudo tee /etc/resolv.conf
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
sudo mkdir -p /var/log/slurm
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
    "nodes": $nodeCount
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
    for nodeIndex in $loopSeq; do
        myNodeName="jarvice-$queue$nodeIndex"
        rm -f $slurm_config/jxe-$myNodeName $slurm_config/$myNodeName
    done
    resp=$(echo $jxe_job | curl --fail -X POST \
        -H "Content-Type: application/json" \
        --data-binary @- "$APIURL"jarvice/submit || exit 1)
    number=$(echo $resp | jq -r .number)
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
    for nodeIndex in $loopSeq; do
        myNodeName="jarvice-$queue$nodeIndex"
        touch $slurm_config/jxe-$myNodeName
        while true; do
            if [ -f "$slurm_config/$myNodeName" ]; then
                echo "worker ready"
                break
            fi
            sleep 5
        done
        echo $number | sudo tee /etc/slurm-llnl/jxe-$myNodeName
        echo $myNodeName | sudo tee --append /etc/slurm-llnl/$number
        slurm_worker_config=$(cat $slurm_config/$myNodeName)
        echo $slurm_worker_config | sudo tee --append /etc/hosts
        worker_ip=$(echo $slurm_worker_config | awk '{print $1}')
        echo "$myNodeName.jarvice.slurm.  IN   A   $worker_ip" | \
            sudo tee --append /root/slurm.db
        soa_update=$(sudo awk 'NR==1{$6='"$(date +\"%Y%m%M%S\")"'; print}' /root/slurm.db)
        sudo cat /root/slurm.db | sed "1s/.*/$soa_update/" | \
            sudo tee /root/slurm.db
        sudo scontrol update nodename=$myNodeName nodeaddr=$worker_ip \
            nodehostname=$myNodeName
    done
done
