#!/bin/bash
cd "$(dirname "$0")"

# By default, this script will build full x64 arch release builds.
# This can be modified by two possible parameters provided to this script:
# debug - will cause a debug build to be made (with full debug symbols)
# incremental - will allow the build system to only build whatever it thinks has changed since last build
# clean - will cause all Chromium dependencies to be wiped and redownloaded (use in case of dependency problems)
# arm64 - build for arm64 arch instead of x64 arch

if [ "$1" == "debug" ] || [ "$2" == "debug" ] || [ "$3" == "debug" ] || [ "$4" == "debug" ]; then
    BUILDTYPE="debug"
    BUILD_GN="is_official_build=false is_debug=true symbol_level=2 chrome_pgo_phase=0"
    AUTOMATE_FLAGS="--no-release-build"
else
    BUILDTYPE="release"
    BUILD_GN="is_official_build=true symbol_level=0 chrome_pgo_phase=0"
    AUTOMATE_FLAGS="--no-debug-build"
fi
if [ "$1" == "incremental" ] || [ "$2" == "incremental" ] || [ "$3" == "incremental" ] || [ "$4" == "incremental" ]; then
    BUILDTYPE="an incremental $BUILDTYPE"
    export CEF_SKIP_PATCHES=true
else
    BUILDTYPE="a full $BUILDTYPE"
    AUTOMATE_FLAGS="$AUTOMATE_FLAGS --force-clean"
fi
if [ "$1" == "clean" ] || [ "$2" == "clean" ] || [ "$3" == "clean" ] || [ "$4" == "clean" ]; then
    BUILDTYPE="$BUILDTYPE build with clean dependencies"
	  AUTOMATE_FLAGS="$AUTOMATE_FLAGS --force-clean-deps"
else
    BUILDTYPE="$BUILDTYPE build"
fi
if [ "$1" == "arm64" ] || [ "$2" == "arm64" ] || [ "$3" == "arm64" ] || [ "$4" == "arm64" ]; then
    BUILDTYPE="$BUILDTYPE for arm64"
    export CEF_ENABLE_ARM64=1
    AUTOMATE_FLAGS="$AUTOMATE_FLAGS --arm64-build"
    if [[ $(pwd) =~ .*x64.* ]]; then
        echo "You chose an arm64 build, but apparently this directory is for x64 builds. Sure this is right?"
        read -p "Hit ENTER to ignore this warning, or abort now using CTRL-C!"
    fi
else
    BUILDTYPE="$BUILDTYPE for x64"
    export CEF_ENABLE_AMD64=1
    AUTOMATE_FLAGS="$AUTOMATE_FLAGS --x64-build"
    if [[ $(pwd) =~ .*arm64.* ]]; then
        echo "You chose an x64 build, but apparently this directory is for arm64 builds. Sure this is right?"
        read -p "Hit ENTER to ignore this warning, or abort now using CTRL-C!"
    fi
fi

read -r BRANCH<../branch.txt
echo "You are about to perform $BUILDTYPE of branch $BRANCH."
read -p "Hit ENTER to start!"

rm -rf ./out

export GN_DEFINES="$BUILD_GN use_sysroot=true proprietary_codecs=true ffmpeg_branding=Chrome"

echo "Downloading automate-git.py script from CEF repository"
# Downloading the file from the master branch is the way to go according to the CEF build documentation, even if not building master, but a maintenance branch
curl -o automate-git.py https://bitbucket.org/chromiumembedded/cef/raw/master/tools/automate/automate-git.py
# But since the CEF repository URL is part of the script, we must replace that dynamically
sed -i "" "s/cef_git_url = .*/cef_git_url = 'https:\/\/github.com\/GEBIT\/cef.git'/" automate-git.py

# in order to disable sandbox building, the following param can be added: "--distrib-subdir='' --no-sandbox --no-symbols --no-docs"
python3 automate-git.py $AUTOMATE_FLAGS --force-build --branch=$BRANCH --download-dir=./../../chromium_git --depot-tools-dir=./../../depot_tools

if [ $? -eq 0 ]; then
    echo "Finished performing $BUILDTYPE of branch $BRANCH."
else
    echo "Failed performing $BUILDTYPE of branch $BRANCH."
fi
