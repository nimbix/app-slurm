#!/bin/bash
OS_ID=$((cat /etc/os-release | grep ^ID_LIKE= || cat /etc/os-release | grep ^ID=) | cut -d = -f2 | tr -d '"')
OS_ID=$(echo $OS_ID | grep -o debian || echo $OS_ID | grep -o fedora)
if [ "$OS_ID" = "debian" ]; then
    SLURM_INSTALL="/etc/slurm-llnl"
else
    SLURM_INSTALL="/etc/slurm"
fi
JOBFILE="$SLURM_INSTALL/jobs.list"
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
    $SLURM_INSTALL/resume-node.sh $req &
done
