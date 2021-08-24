#!/bin/bash
SLURM_PLUGIN_INSTALL="/usr/lib/jarvice.slurm"
JOBFILE="/tmp/jobs.list"
touch "$JOBFILE"
IFS=
exec 100>/var/tmp/jxe.lock
flock -w 120 100
trap 'rm -f /var/tmp/jxe.lock' EXIT
squeue | grep CF | while read -r line; do
    req=$(echo $line | awk '{print $8}')
    job=$(echo $line | awk '{print $1}')
    if grep -Fxq "$job" $JOBFILE; then
        continue
    fi
    echo $job >> $JOBFILE
    $SLURM_PLUGIN_INSTALL/scripts/resume-node.sh $req &
done
