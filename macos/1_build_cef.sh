#!/bin/bash
cd "$(dirname "$0")"

# By default, this script will build full release builds.
# This can be modified by two possible parameters provided to this script:
# debug - will cause a debug build to be made (with full debug symbols)
# incremental - will allow the build system to only build whatever it thinks has changed since last build

if [ "$1" == "debug" ] || [ "$2" == "debug" ]; then
    BUILDTYPE="debug"
    BUILD_GN="is_official_build=false is_debug=true symbol_level=2"
    AUTOMATE_FLAGS="--no-release-build"
else
    BUILDTYPE="release"
    BUILD_GN="is_official_build=true symbol_level=0"
    AUTOMATE_FLAGS="--no-debug-build"
fi
if [ "$1" == "incremental" ] || [ "$2" == "incremental" ]; then
    BUILDTYPE="an incremental $BUILDTYPE"
else
    BUILDTYPE="a full $BUILDTYPE"
    AUTOMATE_FLAGS="$AUTOMATE_FLAGS --force-clean"
fi

read -r BRANCH<../branch.txt
echo "You are about to perform $BUILDTYPE build of branch $BRANCH."
read -p "Hit ENTER to start!"

rm -rf ./out

export GN_DEFINES="use_allocator=none $BUILD_GN use_sysroot=true proprietary_codecs=true ffmpeg_branding=Chrome"

echo "Downloading automate-git.py script from CEF repository"
# Downloading the file from the master branch is the way to go according to the CEF build documentation, even if not building master, but a maintenance branch
curl -o automate-git.py https://bitbucket.org/chromiumembedded/cef/raw/master/tools/automate/automate-git.py
# But since the CEF repository URL is part of the script, we must replace that dynamically
sed -i "" "s/cef_git_url = .*/cef_git_url = 'https:\/\/github.com\/GEBIT\/cef.git'/" automate-git.py

python3 automate-git.py $AUTOMATE_FLAGS --x64-build --force-build --branch=$BRANCH --download-dir=./../../chromium_git --depot-tools-dir=./../../depot_tools

if [ $? -eq 0 ]; then
    echo "Finished performing $BUILDTYPE build of branch $BRANCH."
else
    echo "Failed performing $BUILDTYPE build of branch $BRANCH."
fi