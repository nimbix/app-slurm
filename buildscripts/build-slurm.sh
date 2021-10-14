#!/bin/bash
#
# Copyright (c) 2021, Nimbix, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are
# those of the authors and should not be interpreted as representing official
# policies, either expressed or implied, of Nimbix, Inc.
#
set -e
set -x

[[ -z "$TMPDIR" ]] && TMPDIR=/tmp
GIT_VERSION="${SLURM_VERSION//./-}-1"
WORK=$TMPDIR/install/slurm-${SLURM_VERSION}
mkdir -p ${WORK}

OS_ID=$((cat /etc/os-release | grep ^ID_LIKE= || cat /etc/os-release | grep ^ID=) | cut -d = -f2 | tr -d '"')
OS_ID=$(echo $OS_ID | grep -o debian || echo $OS_ID | grep -o fedora)
if [ "$OS_ID" = "debian" ]; then
    exit 0
else
    SLURM_VERSION=${SLURM_VERSION:-19.05.5}

    cd ${WORK}

    TAR_ARCHIVE="slurm-${GIT_VERSION}.tar.gz"
    TAR_HOST="https://github.com/SchedMD/slurm/archive/refs/tags"

    yum install -y epel-release
    yum groupinstall -y 'Development Tools'
    yum install -y rpm-build wget munge-devel munge-libs python3 readline-devel \
	    perl pam-devel perl-ExtUtils-MakeMaker mysql-devel

    [[ ! -f "${TAR_ARCHIVE}" ]] && wget "${TAR_HOST}/${TAR_ARCHIVE}" || true
    # change to format expected by rpmbuild
    tar -xf ${TAR_ARCHIVE}
    mv "slurm-slurm-${GIT_VERSION}" "slurm-${SLURM_VERSION}"
 
    RPM_ARCHIVE="slurm-${SLURM_VERSION}.tar"
    tar -cf ${RPM_ARCHIVE} "slurm-${SLURM_VERSION}"
    bzip2 ${RPM_ARCHIVE}
    rpmbuild -ta --with mysql slurm-*.tar.bz2

    cp /root/rpmbuild/RPMS/x86_64/slurm-*.rpm .
fi

exit 0
