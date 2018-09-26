#!/bin/bash

read -r BRANCH<../branch.txt
python automate-git.py --download-dir=/Users/cefbuild/code/chromium_git --depot-tools-dir=/Users/cefbuild/code/depot_tools --no-distrib --no-build --x64-build --branch=$BRANCH

