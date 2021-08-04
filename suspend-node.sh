#!/bin/bash
source /etc/JARVICE/jobenv.sh
OS_ID=$((cat /etc/os-release | grep ^ID_LIKE= || cat /etc/os-release | grep ^ID=) | cut -d = -f2 | tr -d '"')
OS_ID=$(echo $OS_ID | grep -o debian || echo $OS_ID | grep -o fedora)
if [ "$OS_ID" = "debian" ]; then
    SLURM_INSTALL="/etc/slurm-llnl"
else
    SLURM_INSTALL="/etc/slurm"
fi
queue=$(echo $1 | sed 's/jarvice-//g' | sed 's/[[]*[0-9].*//g')
queue_config=$(cat $SLURM_INSTALL/partitions.json)
slurm_config=$(cat $SLURM_INSTALL/slurm-configpath)
#while IFS= read -r job; do
#    sed -i "/$job/d" /tmp/jobs.list
#done < $slurm_config/job_complete
# Check if range of nodes is specified
for group in $(echo $1 | sed -r 's/(.*[a-zA-Z]+)([0-9]+)$/[\2]/' \
    | awk -F'[][]' '{print $2}' | tr "," "\n"); do
    myRange=$group
    loopSeq=$(seq $(cut -d'-' -f1 <<<$myRange) $(cut -d'-' -f2 <<<$myRange))
    for index in $loopSeq; do
        nodeName="jarvice-$queue$index"
        if [ ! -f "$SLURM_INSTALL/jxe-$nodeName" ]; then
            continue
        fi
        number=$(cat $SLURM_INSTALL/jxe-$nodeName)
        groupNames=$(cat $SLURM_INSTALL/$number)
        curl --data-urlencode "username=$APIUSER" \
            --data-urlencode "apikey=$APIKEY" \
            --data-urlencode "number=$number" \
            "$APIURL""jarvice/shutdown"
        for node in $groupNames; do
            sudo rm -f $SLURM_INSTALL/jxe-$node
            cat /etc/hosts | sed "/.*$node/d" | sudo tee /etc/hosts
            sudo sed -i "/.*$node.*/d" /root/slurm.db
            sudo scontrol update nodename="$node" state="resume"
        done
        rm $SLURM_INSTALL/$number
    done
done
