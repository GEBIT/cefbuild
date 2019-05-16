#!/bin/bash
cd "$(dirname "$0")"

read -r BRANCH<../branch.txt
export GN_DEFINES="use_allocator=none is_official_build=true use_sysroot=true symbol_level=0 proprietary_codecs=true ffmpeg_branding=Chrome"

echo "Downloading automate-git.py script from CEF repository"
# Downloading the file from the master branch is the way to go according to the CEF build documentation, even if not building master, but a maintenance branch
curl -o automate-git.py https://bitbucket.org/chromiumembedded/cef/raw/master/tools/automate/automate-git.py
# But since the CEF repository URL is part of the script, we must replace that dynamically
sed -i "" "s/cef_git_url = .*/cef_git_url = 'https:\/\/github.com\/GEBIT\/cef.git'/" automate-git.py

python automate-git.py --no-debug-build --minimal-distrib --client-distrib --force-clean --x64-build --force-build --branch=$BRANCH --download-dir=./../../chromium_git --depot-tools-dir=./../../depot_tools

