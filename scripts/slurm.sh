#!/bin/bash
# start slurmctld
/etc/slurm/start-slurm.sh &
# replace process with init
exec /usr/bin/xclock
