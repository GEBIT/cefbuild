#!/bin/bash

read -r BRANCH<../branch.txt
export GN_DEFINES="use_allocator=none is_official_build=true use_sysroot=true symbol_level=0"
python automate-git.py --no-debug-build --minimal-distrib --client-distrib --force-clean --x64-build --build-target=cefsimple --force-build --branch=$BRANCH --download-dir=/home/cefbuild/code/chromium_git --depot-tools-dir=/home/cefbuild/code/depot_tools

