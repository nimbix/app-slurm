#!/bin/bash
set -e
set -x

[[ -z "$TMPDIR" ]] && TMPDIR=/tmp
WORK=$TMPDIR/install
mkdir -p ${WORK}
cd ${WORK}

COREDNS_VERSION=${1:-1.8.3}

COREDNS_ARCHIVE="https://github.com/coredns/coredns/releases/download/v${COREDNS_VERSION}/"
COREDNS_ARCHIVE+="coredns_${COREDNS_VERSION}_linux_amd64.tgz" 

wget "$COREDNS_ARCHIVE"
wget "$COREDNS_ARCHIVE.sha256"
sha256sum  $(basename $COREDNS_ARCHIVE)

tar -xvf "$(basename ${COREDNS_ARCHIVE})"
mv coredns /usr/local/bin/coredns

exit 0
