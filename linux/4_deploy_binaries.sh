#!/bin/bash
cd "$(dirname "$0")"

if [ "$1" == "local" ]; then
    DEPLOYTYPE="locally"
    DEPLOYCMD="install:install-file"
else
    DEPLOYTYPE="remotely"
    DEPLOYCMD="deploy:deploy-file"
fi

BASEDIR=./../../
OUTPUT_DIR=./out

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR_64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_linux64"`
CEF_RELEASE_DIR_32=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_linux32"`
CEF_RELEASE_DIR_ARM64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_linuxarm64"`


if [ ! -d "$CEF_RELEASE_DIR_64" ]; then
    if [ ! -d "$CEF_RELEASE_DIR_32" ]; then
        if [ ! -d "$CEF_RELEASE_DIR_ARM64" ]; then
            echo "ERROR: Did not find a matching CEF branch release build in binary_distrib directory"
            exit
        else
            echo "Found arm64 CEF build"
            ARCH_NAME="arm64"
            CEF_PLATFORM=linuxarm64
            CEF_PLATFORM_DEPLOY=arm64
            CEF_RELEASE_DIR=$CEF_RELEASE_DIR_ARM64
        fi
    else
        echo "Found x86 CEF build"
        CEF_RELEASE_DIR=$CEF_RELEASE_DIR_32
        BITNESS=32
        BITNESS_32ONLY=32
        ARCH_NAME="x86"
        CEF_PLATFORM=linux32
        JOGAMP_ARCH=i586
    fi
else
    echo "Found x64 CEF build"
    CEF_RELEASE_DIR=$CEF_RELEASE_DIR_64
    BITNESS=64
    JOGAMP_ARCH=amd64
    ARCH_NAME="x64"
    CEF_PLATFORM=linux64
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
if [ $(stat -c%s "$OUTPUT_DIR/jcef-binaries-linux/jcef/libcef.so") -gt 400000000 ]; then
    BUILD_TYPE="Debug"
else
    BUILD_TYPE="Release"
fi

echo "Found $ARCH_NAME CEF version $CEF_RELEASE_VERSION (cleaned-up: $CEF_CLEAN_VERSION)"
echo "Found $ARCH_NAME JCEF version $JCEF_RELEASE_VERSION which will be our artifact version"
echo "The build to be packaged is a $BUILD_TYPE build"

if [ ! -f "$OUTPUT_DIR/jcef-binaries-$CEF_PLATFORM.jar" ]; then
    echo "ERROR: Did not find jcef-binaries-$CEF_PLATFORM.jar"
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

echo "Deploying $ARCH_NAME JCEF binary package for Linux in version $VERSION $DEPLOYTYPE"

if [ "$DEPLOYTYPE" == "remotely" ]; then
    echo -n "Please enter the username: "
    read NEXUS_USER
    if [ -z "$NEXUS_USER" ]; then
        echo "ERROR: No username was provided"
        exit
    fi

    echo -n "Please enter the password: "
    read -s NEXUS_PASS
    echo ""
    if [ -z "$NEXUS_PASS" ]; then
        echo "ERROR: No password was provided"
        exit
    fi
fi

mvn $DEPLOYCMD -DgroupId=de.gebit.jcef -Dpackaging=jar -Drepo.user=$NEXUS_USER -Drepo.pass=$NEXUS_PASS -DartifactId=jcef-binaries-linux-$ARCH_NAME -Dfile=$OUTPUT_DIR/jcef-binaries-$CEF_PLATFORM.jar -Dversion=$VERSION
