#!/bin/bash
cd "$(dirname "$0")"

echo "This script wipes the compile output dirs."
echo "It is intended to be used to reclaim disk space, NOT for regular building."
echo "Running 1_build_cef.sh also wipes the output dir if not building incrementally!"

echo "Do you want to continue?"
read -p "Hit ENTER to start!"

rm -rf ./out
rm -rf ../../chromium_git/chromium/src/out

echo "Delete completed!"