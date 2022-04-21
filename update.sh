#!/bin/bash

TAG=master
if [[ "$1" != "" ]]; then
    TAG="$1"
fi

wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/upgrade.sh -O ~/upgrade.sh
chmod 744 ~/upgrade.sh

sudo ~/upgrade.sh "$@" | tee ~/upgrade.log