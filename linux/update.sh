#!/bin/bash

read -r BRANCH<../branch.txt
python automate-git.py --download-dir=/home/cefbuild/code/chromium_git --depot-tools-dir=/home/cefbuild/code/depot_tools --no-distrib --no-build --branch=$BRANCH

