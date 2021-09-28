#!/bin/bash
# start slurmctld
/usr/lib/jarvice.slurm/scripts/start-slurm.sh &
# start sshd
/usr/lib/JARVICE/tools/bin/sshd_start &
# replace process with app (this example runs xclock)
exec /usr/bin/xclock
