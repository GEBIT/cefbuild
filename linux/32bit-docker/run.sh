#!/bin/sh

BUILDROOT=$(cd ../../../ && pwd)

if [ -z "$1" ]; then
    INTERACTIVE=-it
else
    COMMAND="-c $1"
fi

docker run $INTERACTIVE --user $(id -u):$(id -g) --mount type=bind,source=$BUILDROOT,target=$BUILDROOT --entrypoint /bin/bash 32bit-jcef-build $COMMAND
