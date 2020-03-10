#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=./../../
OUTPUT_DIR=./out

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR_64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_linux64"`
CEF_RELEASE_DIR_32=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_linux32"`

if [ ! -d "$CEF_RELEASE_DIR_64" ]; then
    if [ ! -d "$CEF_RELEASE_DIR_32" ]; then
        echo "ERROR: Did not find a matching CEF branch release build in binary_distrib directory"
        exit 1
    else
        CEF_RELEASE_DIR=$CEF_RELEASE_DIR_32
        BITNESS=32
        BITNESS_32ONLY=32
        JOGAMP_ARCH=i586
    fi
else
    CEF_RELEASE_DIR=$CEF_RELEASE_DIR_64
    BITNESS=64
    JOGAMP_ARCH=amd64
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_linux$BITNESS ]]; then
    CEF_RELEASE_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to extract CEF version number"
    exit 1
fi

if [[ $CEF_RELEASE_VERSION =~ (.+\..+\.[^+]+)\+.* ]]; then
    CEF_CLEAN_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to clean up CEF version number"
    exit 1
fi

JCEF_VERSION_FILE=$OUTPUT_DIR/jcef_version.txt
if [ ! -f "$JCEF_VERSION_FILE" ]; then
    echo "ERROR: Did not find a JCEF version file"
    exit 1
fi

JCEF_RELEASE_VERSION=$(cat $JCEF_VERSION_FILE)

# Really big binary is a safe indication of a debug build
if [ $(stat -c%s "$OUTPUT_DIR/jcef-binaries-linux/jcef/libcef.so") -gt 1000000000 ]; then
    BUILD_TYPE="Debug"
else
    BUILD_TYPE="Release"
fi

echo "Found $BITNESS bit CEF version $CEF_RELEASE_VERSION (cleaned-up: $CEF_CLEAN_VERSION)"
echo "Found $BITNESS bit JCEF version $JCEF_RELEASE_VERSION which will be our artifact version"
echo "The build to be packaged is a $BUILD_TYPE build"

if [ ! -f "$OUTPUT_DIR/jcef-binaries-linux$BITNESS.jar" ]; then
    echo "ERROR: Did not find jcef-binaries-linux$BITNESS.jar"
    exit 1
fi

echo -n "Please enter a qualifier for this artifact release version: "
read QUALIFIER
if [ -z "$QUALIFIER" ]; then
    echo "ERROR: No qualifier was provided"
    exit 1
fi

if [ $BUILD_TYPE == "Debug" ]; then
    read -p "ATTENTION: You are about to deploy a DEBUG BUILD! These are very big, slow, and NOT SUITABLE FOR ANY USE except for CEF/JCEF native library debugging purposes. Are you sure that you want to deploy this build under qualifier $QUALIFIER? Hit Enter to continue, CTRL-C to abort!"
fi

VERSION=$JCEF_RELEASE_VERSION-$QUALIFIER

echo "Deploying $BITNESS bit JCEF binary package for Linux in version $VERSION to Nexus"
mvn deploy:deploy-file -DartifactId=jcef-binaries-linux$BITNESS_32ONLY -Dfile=$OUTPUT_DIR/jcef-binaries-linux$BITNESS.jar -Dversion=$VERSION
