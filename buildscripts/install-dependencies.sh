#!/bin/bash
set -e
set -x

PACKAGES="sudo wget curl openssh-server"

OS_ID=$((cat /etc/os-release | grep ^ID_LIKE= || cat /etc/os-release | grep ^ID=) | cut -d = -f2 | tr -d '"')
OS_ID=$(echo $OS_ID | grep -o debian || echo $OS_ID | grep -o fedora)
if [ "$OS_ID" = "debian" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get -yq install ${PACKAGES} dnsutils
else
    yum -y install ${PACKAGES} bind-utils
fi
cat <<EOF >/etc/sudoers.d/00-nimbix
Defaults: nimbix !requiretty
Defaults: root !requiretty
nimbix ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/00-nimbix

exit 0
