#!/bin/bash
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
