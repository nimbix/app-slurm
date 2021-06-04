#!/bin/bash
source /etc/JARVICE/jobenv.sh
queue=$(echo $1 | sed 's/jarvice-//g' | sed 's/[[]*[0-9].*//g')
# Check if range of nodes is specified
for group in $(echo $1 | sed -r 's/(.*[a-zA-z]+)([0-9]+)$/[\2]/' \
    | awk -F'[][]' '{print $2}' | tr "," "\n"); do
    myRange=$group
    loopSeq=$(seq $(cut -d'-' -f1 <<<$myRange) $(cut -d'-' -f2 <<<$myRange))
    for index in $loopSeq; do
        nodeName="jarvice-$queue$index"
        if [ ! -f "/etc/slurm-llnl/jxe-$nodeName" ]; then
            continue
        fi
        number=$(cat /etc/slurm-llnl/jxe-$nodeName)
        groupNames=$(cat /etc/slurm-llnl/$number)
        for node in $groupNames; do
            sudo scontrol update nodename="$node" state="down" reason="evict"
        done
        curl --data-urlencode "username=$APIUSER" \
            --data-urlencode "apikey=$APIKEY" \
            --data-urlencode "number=$number" \
            "$APIURL""jarvice/shutdown"
        for node in $groupNames; do
            sudo rm -f /etc/slurm-llnl/jxe-$node
            cat /etc/hosts | sed "/.*$node/d" | sudo tee /etc/hosts
            cat /root/slurm.db | sed "/.*$node.*/d" | sudo tee /root/slurm.db
            sudo scontrol update nodename="$node" state="resume"
        done
        rm /etc/slurm-llnl/$number
    done
done
