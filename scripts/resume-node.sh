#!/bin/bash
#
# Copyright (c) 2021, Nimbix, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are 
# those of the authors and should not be interpreted as representing official 
# policies, either expressed or implied, of Nimbix, Inc.
#
source /etc/JARVICE/jobenv.sh
OS_ID=$((cat /etc/os-release | grep ^ID_LIKE= || cat /etc/os-release | grep ^ID=) | cut -d = -f2 | tr -d '"')
OS_ID=$(echo $OS_ID | grep -o debian || echo $OS_ID | grep -o fedora)
if [ "$OS_ID" = "debian" ]; then
    SLURM_INSTALL="/etc/slurm-llnl"
else
    SLURM_INSTALL="/etc/slurm"
fi
SLURM_YUMDIR="/usr/lib/slurm/slurm-${SLURM_VERSION}/x86_64"
queue=$(echo $1 | sed 's/jarvice-//g' | sed 's/[[]*[0-9].*//g')
queue_config=$(cat $SLURM_INSTALL/partitions.json)
slurm_config="/tmp/slurmconf"

# Check if range of nodes is specified
for group in $(echo $1 | sed -r 's/(.*[a-zA-Z]+)([0-9]+)$/[\2]/' \
    | awk -F'[][]' '{print $2}' | tr "," "\n"); do
    myRange=$group
    loopSeq=$(seq $(cut -d'-' -f1 <<<$myRange) $(cut -d'-' -f2 <<<$myRange))
    nodeCount=$(echo $loopSeq | wc -w)

    indexStart=$(echo $loopSeq | awk '{print $1}')
jobscript=$(cat << EOF
OS_ID=\$((cat /etc/os-release | grep ^ID_LIKE= || cat /etc/os-release | grep ^ID=) | cut -d = -f2 | tr -d '"')
OS_ID=\$(echo \$OS_ID | grep -o debian || echo \$OS_ID | grep -o fedora)
if [ "\$OS_ID" = "debian" ]; then
    SLURMDIR=/etc/slurm-llnl
    if command -v slurmd &> /dev/null; then
        echo "skipping slurm installation"
    else
        DEBIAN_FRONTEND=noninteractive sudo apt update
        DEBIAN_FRONTEND=noninteractive sudo apt install -yq slurmd dnsutils
    fi
elif [ "\$OS_ID" = "fedora" ]; then
    SLURMDIR=/etc/slurm
    if command -v slurmd &> /dev/null; then
        echo "skipping slurm installation"
    else
    cd $SLURM_YUMDIR
        sudo yum install -y *.rpm bind-utils
    fi
else
    echo \$(cat /etc/issue) not supported
    exit 1
fi
SKIP=\$(awk '/^__TARFILE_FOLLOWS__/ { print NR + 1; exit 0; }' "\$0")
tail -n +\${SKIP} "\$0" | tar -pvx -C /tmp
sudo cp -r /tmp/\$(basename \${SLURMDIR})/* \$SLURMDIR
cat \$SLURMDIR/slurm-headnode | sudo tee --append /etc/hosts

myHost=\$(hostname)
if [ "\$1" != "worker" ]; then
    node_rank=$indexStart
    while IFS= read -r node; do
        worker_name="jarvice-$queue\$node_rank"
        cat /etc/hosts | sed "/.*\${node}/s/$/ \${worker_name}/" | sudo tee /etc/hosts &> /dev/null
        node_rank=\$(( \$node_rank + 1 ))
    done < /etc/JARVICE/nodes
    cat /etc/hosts
    echo "worker ready"
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
SLURM_JOBID='\$SLURM_JOBID'
SLURMD_NODENAME='\$SLURMD_NODENAME'
epilogscript=\$(cat << EPI
#!/bin/bash
sudo scontrol update nodename=\$SLURMD_NODENAME state="down" reason="JXE_Eviction"
EPI
)
IFS=
echo \$epilogscript | sudo tee /usr/bin/epilog.sh
sudo chmod 755 /usr/bin/epilog.sh
cat /etc/resolv.conf | sed 's/^search/& jarvice.slurm/' | \
    sed "s/^nameserver.*/nameserver $(cat /etc/hosts | grep $(hostname) | \
    awk '{print $1}')/" | sudo tee /etc/resolv.conf
node_rank=\$(cat /etc/JARVICE/nodes | grep -n \$(hostname) | \
    sed -r 's/([0-9]+):.*$/\1/')
node_rank=\$(( \$node_rank + $indexStart - 1 ))
worker_name="jarvice-$queue\$node_rank"
cat /etc/hosts | sed "/.*\$(hostname)/s/$/ \${worker_name}/" | sudo tee /etc/hosts &> /dev/null
while true; do
    dig \${worker_name}.jarvice.slurm | grep "ANSWER SECTION"
    if [ "$?" -eq "0" ]; then
        echo "headnode ready"
        break
    fi
    sleep 1
done
sudo mkdir -p /var/run/munge && sudo chown munge:munge /var/run/munge
sudo -u munge munged -f --key-file=\$SLURMDIR/munge.key
sudo mkdir -p /var/spool/slurmd
sudo mkdir -p /var/run/slurmd
sudo mkdir -p /var/log/slurm
sudo slurmd -b -D
exit 0
__TARFILE_FOLLOWS__
EOF
)
IFS=
tmpfile=$(mktemp)
echo $jobscript > $tmpfile
cat /tmp/slurm.tar >> $tmpfile
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
    "hpc_job_script": "$(cat $tmpfile | base64 -w 0)",
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
  "job_label": "jarvice-$queue[$group]",
  "user": {
    "username": "$APIUSER",
    "apikey": "$APIKEY"
  }
}
EOF
)
rm $tmpfile
    resp=$(echo $jxe_job | curl --fail -X POST \
        -H "Content-Type: application/json" \
        --data-binary @- "$APIURL"jarvice/submit 2> /dev/null || exit 1)
    number=$(echo $resp | jq -r .number)
    while true; do
        sleep 1
        job_status=$(curl --data-urlencode "username=$APIUSER" \
            --data-urlencode "apikey=$APIKEY" \
            --data-urlencode "number=$number" \
            "$APIURL""jarvice/status" 2> /dev/null)
        index=$( printf '%d' $number )
        job_status=$(echo $job_status | jq -r .[\"$index\"].job_status)
        echo $job_status
        if [ "$job_status" = "PROCESSING STARTING" ]; then
            echo "worker $number online"
            break
        fi
    done
    while true; do
        hosts_entry=$(curl --data-urlencode "username=$APIUSER" \
            --data-urlencode "apikey=$APIKEY" \
            --data-urlencode "number=$number" \
            --data-urlencode "lines=1000" \
            "$APIURL""jarvice/tail" 2>/dev/null)
        if [ "$(echo $hosts_entry | grep "worker ready")" = "worker ready" ]; then
            echo "worker ready"
            break
        fi
        sleep 1
    done
    while IFS= read -r nodeIndex; do
        myNodeName="jarvice-$queue$nodeIndex"
        echo $number | sudo tee $SLURM_INSTALL/jxe-$myNodeName
        echo $myNodeName | sudo tee --append $SLURM_INSTALL/$number
        slurm_worker_config=$(echo $hosts_entry | grep $myNodeName)
        echo $slurm_worker_config | sudo tee --append /etc/hosts
        worker_ip=$(echo $slurm_worker_config | awk '{print $1}')
        sudo scontrol update nodename=$myNodeName nodeaddr=$worker_ip \
            nodehostname=$myNodeName
        echo "$myNodeName.jarvice.slurm.  IN   A   $worker_ip" | \
            sudo tee --append /root/slurm.db
        soa_update=$(sudo awk 'NR==1{$6='"$(date +\"%Y%m%M%S\")"'; print}' /root/slurm.db)
        sudo sed -i "1s/.*/$soa_update/" /root/slurm.db
    done <<< "$loopSeq"
done
