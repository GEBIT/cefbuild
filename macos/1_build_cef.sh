#!/bin/bash
cd "$(dirname "$0")"

read -r BRANCH<../branch.txt
export GN_DEFINES="use_allocator=none is_official_build=true use_sysroot=true symbol_level=0"
python automate-git.py --no-debug-build --minimal-distrib --client-distrib --force-clean --x64-build --force-build --branch=$BRANCH --download-dir=./../../chromium_git --depot-tools-dir=./../../depot_tools

