FROM centos:7.5.1804 as getter

ARG SLURM_VERSION
ENV SLURM_VERSION=${SLURM_VERSION:-19.05.5}
ARG COREDNS_VERSION
ENV COREDNS_VERSION=${COREDNS_VERSION:-1.8.3}
# build slurm
COPY app-slurm/buildscripts/build-slurm.sh /usr/local/bin/build-slurm.sh
RUN /usr/local/bin/build-slurm.sh
# get coredns
COPY app-slurm/buildscripts/install-coredns.sh /usr/local/bin/install-coredns.sh
RUN /usr/local/bin/install-coredns.sh "${COREDNS_VERSION}"

############ main app #############
ARG BASE_IMAGE
FROM ${BASE_IMAGE:-centos:7.5.1804}

ARG SLURM_VERSION
ENV SLURM_VERSION=${SLURM_VERSION:-19.05.5}
# install slurm
COPY --from=getter /tmp/install/slurm-${SLURM_VERSION} /usr/lib/slurm/slurm-${SLURM_VERSION}
RUN mkdir -p /usr/lib/slurm
COPY app-slurm/buildscripts/install-slurm.sh /usr/local/bin/install-slurm.sh
RUN /usr/local/bin/install-slurm.sh
# install coredns
COPY --from=getter /usr/local/bin/coredns /usr/local/bin/coredns
# setup munge
RUN mkdir -p /var/log/munge && chown -R munge:munge /var/log/munge && \
    mkdir -p /var/log/slurm
# copy slurm plugin scripts
COPY app-slurm/conf/slurm.conf /etc/slurm/slurm.conf
# rename slurm path for CentOS
RUN sed -i 's/slurm-llnl/slurm/' /etc/slurm/slurm.conf
COPY app-slurm/scripts/start-slurm.sh /etc/slurm/start-slurm.sh
COPY app-slurm/scripts/suspend-node.sh /etc/slurm/suspend-node.sh
COPY app-slurm/scripts/resume-node.sh /etc/slurm/resume-node.sh
RUN sed -i "s/SLURM_VERSION/$SLURM_VERSION/" /etc/slurm/resume-node.sh
COPY app-slurm/scripts/resume-group.sh /etc/slurm/resume-group.sh
RUN echo '/etc/slurm/start-slurm.sh &> /dev/null &' >> /etc/profile
# using slurm prolog to setup JarviceXE job environment
RUN printf 'IFS=\n\
prologscript=\$(cat << PRO\n#!/bin/bash\n\
sudo cat /etc/JARVICE/jobenv.sh > /etc/profile.d/jarvice_jobenv.sh\n\
IFS=\n\
/usr/local/JARVICE/tools/bin/sshd_start\n\
PRO\n\
)\n\
echo \$prologscript | sudo tee /usr/bin/prolog.sh\n\
sudo chmod 755 /usr/bin/prolog.sh\n'\
| sed -i '/^epilogscript=.*/e cat \/dev\/stdin' /etc/slurm/resume-node.sh
RUN sed -i 's/#Prolog=/Prolog=\/usr\/bin\/prolog.sh/' /etc/slurm/slurm.conf
# setup AppDef
# COPY scripts/slurm.sh /usr/lib/jarvice.apps/slurm/slurm.sh
COPY NAE/AppDef.json /etc/NAE/AppDef.json
RUN curl --fail -X POST -d @/etc/NAE/AppDef.json https://cloud.nimbix.net/api/jarvice/validate

RUN bash -c 'mkdir -p /etc/NAE && touch /etc/NAE/{screenshot.png,screenshot.txt,license.txt,AppDef.json}'
