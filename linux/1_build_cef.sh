#!/bin/bash
cd "$(dirname "$0")"

# By default, this script will build full release builds.
# This can be modified by some possible parameters provided to this script:
# debug - will cause a debug build to be made (with full debug symbols)
# incremental - will allow the build system to only build whatever it thinks has changed since last build
# clean - will cause all Chromium dependencies to be wiped and redownloaded (use in case of dependency problems)
# x86 - will build a 32bit build instead of 64bit

if [ "$1" == "debug" ] || [ "$2" == "debug" ] || [ "$3" == "debug" ] || [ "$4" == "debug" ]; then
    BUILDTYPE="debug"
    BUILD_GN="is_official_build=true symbol_level=1 chrome_pgo_phase=0 is_cfi=false"
    AUTOMATE_FLAGS="--no-debug-build"
    # Note that the "debug" build of CEF is actually not a real debug build, but still a release build just with
    # added basic symbols - this is because "real" debug builds of Chromium blow up the binary size to 10x 
    # (more than one gigabyte) and make the binary entirely impractical to handle - it also showed to throw 
    # linker errors due to an exhaustion of the TLS space. Thus what we call "debug" here is just a normal 
    # CEF build with added symbols, which is what we usually need for debug purposes to symbolize backtraces.
else
    BUILDTYPE="release"
    BUILD_GN="is_official_build=true symbol_level=0 chrome_pgo_phase=0 is_cfi=false"
    AUTOMATE_FLAGS="--no-debug-build"
fi
BUILDTYPE_PLAIN=$BUILDTYPE
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
if [ "$1" == "x86" ] || [ "$2" == "x86" ] || [ "$3" == "x86" ] || [ "$4" == "x86" ]; then
    BUILDTYPE="$BUILDTYPE 32-bit"
    STRIP_CMD=strip
else
    BUILDTYPE="$BUILDTYPE 64-bit"
    if [ "$1" == "arm64" ] || [ "$2" == "arm64" ] || [ "$3" == "arm64" ] || [ "$4" == "arm64" ]; then
        BUILDTYPE="$BUILDTYPE for arm64"
        export CEF_ENABLE_ARM64=1
        export CEF_INSTALL_SYSROOT=arm64
        BUILD_GN="$BUILD_GN use_thin_lto=false"
        AUTOMATE_FLAGS="$AUTOMATE_FLAGS --arm64-build"
        STRIP_CMD=/usr/bin/aarch64-linux-gnu-strip
        if [[ $(pwd) =~ .*x64.* ]]; then
            echo "You chose an arm64 build, but apparently this directory is for x64 builds. Sure this is right?"
            read -p "Hit ENTER to ignore this warning, or abort now using CTRL-C!"
        fi
    else
        BUILDTYPE="$BUILDTYPE for x64"
        AUTOMATE_FLAGS="$AUTOMATE_FLAGS --x64-build"
        STRIP_CMD=strip
        if [[ $(pwd) =~ .*arm64.* ]]; then
            echo "You chose an x64 build, but apparently this directory is for arm64 builds. Sure this is right?"
            read -p "Hit ENTER to ignore this warning, or abort now using CTRL-C!"
        fi
    fi
fi

read -r BRANCH<../branch.txt
echo "You are about to perform $BUILDTYPE of branch $BRANCH."
read -p "Hit ENTER to start!"

rm -rf ./out

export GN_DEFINES="use_allocator=none $BUILD_GN use_sysroot=true proprietary_codecs=true ffmpeg_branding=Chrome"

echo "Downloading automate-git.py script from CEF repository"
# Downloading the file from the master branch is the way to go according to the CEF build documentation, even if not building master, but a maintenance branch
curl -o automate-git.py https://bitbucket.org/chromiumembedded/cef/raw/master/tools/automate/automate-git.py
# But since the CEF repository URL is part of the script, we must replace that dynamically
sed -i "s/cef_git_url = .*/cef_git_url = 'https:\/\/github.com\/GEBIT\/cef.git'/" automate-git.py

# For some reason we need --build-target=cefsimple here, while we may not add this on MacOS and Windows without breaking the build
python3 automate-git.py $AUTOMATE_FLAGS --build-target=cefsimple --force-build --branch=$BRANCH --download-dir=./../../chromium_git --depot-tools-dir=./../../depot_tools

# For some odd reason the CEF build does not honor symbol_level=0 anymore, it still adds some very basic debug symbols
# Let's get rid of them for release builds
if [ "$BUILDTYPE_PLAIN" == "release" ]; then
    echo "Stripping libcef.so from all unneeded symbols"
    $STRIP_CMD --strip-unneeded ./../../chromium_git/chromium/src/cef/binary_distrib/*/Release/libcef.so
fi

if [ $? -eq 0 ]; then
    echo "Finished performing $BUILDTYPE build of branch $BRANCH."
else
    echo "Failed performing $BUILDTYPE build of branch $BRANCH."
fi
