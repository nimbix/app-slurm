#!/bin/bash
# start slurmctld
/etc/slurm/start-slurm.sh &
# replace process with app (this example runs xclock)
exec /usr/bin/xclock
