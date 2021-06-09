#!/bin/bash
for group in $(squeue | grep CF | awk '{print $8}'); do
    /etc/slurm-llnl/resume-node.sh $group &
done
