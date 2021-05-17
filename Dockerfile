FROM ubuntu:focal

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -yq install slurmctld slurmd sudo vim \
        openssh-server curl jq

RUN mkdir -p /var/log/munge && chown -R munge:munge /var/log/munge && \
    mkdir -p /var/log/slurm

COPY slurm.conf /etc/slurm-llnl/slurm.conf

RUN printf '%s\n' \
'Defaults: nimbix !requiretty' \
'Defaults: root !requiretty' \
'nimbix ALL=(ALL) NOPASSWD: ALL' \
> /etc/sudoers.d/00-nimbix

COPY start-slurm.sh /etc/slurm-llnl/start-slurm.sh
COPY start-worker.sh /etc/slurm-llnl/start-worker.sh
COPY suspend-node.sh /etc/slurm-llnl/suspend-node.sh
COPY resume-node.sh /etc/slurm-llnl/resume-node.sh

COPY AppDef.json /etc/NAE/AppDef.json
RUN curl --fail -X POST -d @/etc/NAE/AppDef.json https://cloud.nimbix.net/api/jarvice/validate

RUN mkdir -p /etc/NAE && touch /etc/NAE/screenshot.png && \
    touch /etc/NAE/screenshot.txt && \
    touch /etc/NAE/license.txt && \
    touch /etc/NAE/AppDef.json
