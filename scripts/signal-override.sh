#!/bin/sh
set -e

trap 'echo {"error": "signal not supported"}' ERR
# get slurm info for job
job=$(scontrol listpids | awk 'NR>1{print $2}')
pid=$(scontrol listpids | awk 'NR>1{print $1}')

while :
do
    case "$1" in
        20|19)
            # SIGTSTP/SIGSTOP
            scontrol suspend $job
            break
            ;;
        18)
            # SIGCONT
            scontrol resume $job
            break
            ;;
        *)
            # throw error
            false
            ;;
    esac
done
echo "{\"signal\": $1, \"pid\": $pid}"
exit 0
