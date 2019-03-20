#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=/home/cefbuild/code/

read -r BRANCH<../branch.txt

JCEF_DIR=$BASEDIR/java-cef

echo "Checking out JCEF branch gebit_$BRANCH"
git -C $JCEF_DIR fetch
git -C $JCEF_DIR -c advice.detachedHead=false checkout -f origin/gebit_$BRANCH

echo "All done!"
