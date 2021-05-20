#!/bin/bash
source /etc/JARVICE/jobenv.sh
queue=$(echo $1 | sed 's/jarvice-//g' | sed 's/[[]*[0-9].*//g')
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

        number=$(cat /etc/slurm-llnl/jxe-$nodeName)
        sudo rm /etc/slurm-llnl/jxe-$nodeName
        cat /etc/hosts | sed "/.*$nodeName/d" | sudo tee /etc/hosts
        cat /root/slurm.db | sed "/.*$nodeName.*/d" | sudo tee /root/slurm.db
        curl --data-urlencode "username=$APIUSER" \
            --data-urlencode "apikey=$APIKEY" \
            --data-urlencode "number=$number" \
            "$APIURL""jarvice/shutdown"
    done
done
