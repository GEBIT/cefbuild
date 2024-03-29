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

FIND_COMMAND="find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name 'cef_binary_*.$BRANCH.*_windows64'"
CEF_RELEASE_DIR=`eval $FIND_COMMAND`

if [ ! -d "$CEF_RELEASE_DIR" ]; then
    echo "ERROR: Did not find a matching CEF branch release build in out directory"
    exit
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_windows64 ]]; then
    CEF_RELEASE_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to extract CEF version number"
    exit
fi

if [[ $CEF_RELEASE_VERSION =~ (.+\..+\.[^+]+)\+.* ]]; then
    CEF_CLEAN_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to clean up CEF version number"
    exit
fi

JCEF_VERSION_FILE=$OUTPUT_DIR/jcef_version.txt
if [ ! -f "$JCEF_VERSION_FILE" ]; then
    echo "ERROR: Did not find a JCEF version file"
fi

# Really big binary is a safe indication of a debug build
if [ $(stat -c%s "$OUTPUT_DIR/jcef-binaries-windows/jcef/libcef.dll") -gt 1000000000 ]; then
    BUILD_TYPE="Debug"
else
    BUILD_TYPE="Release"
fi

JCEF_RELEASE_VERSION=$(cat $JCEF_VERSION_FILE)

echo "Found CEF version $CEF_RELEASE_VERSION (cleaned-up: $CEF_CLEAN_VERSION)"
echo "Found JCEF version $JCEF_RELEASE_VERSION which will be our artifact version"
echo "The build to be packaged is a $BUILD_TYPE build"

if [ ! -f "$OUTPUT_DIR/jcef-binaries-windows.jar" ]; then
    echo "ERROR: Did not find jcef-binaries-windows.jar"
    exit
fi

echo -n "Please enter a qualifier for this artifact release version: "
read QUALIFIER
if [ -z "$QUALIFIER" ]; then
    echo "ERROR: No qualifier was provided"
    exit
fi

if [ $BUILD_TYPE == "Debug" ]; then
    read -p "ATTENTION: You are about to deploy a DEBUG BUILD! These are very big, slow, and NOT SUITABLE FOR ANY USE except for CEF/JCEF native library debugging purposes. Are you sure that you want to deploy this build under qualifier $QUALIFIER? Hit Enter to continue, CTRL-C to abort!"
fi

VERSION=$JCEF_RELEASE_VERSION-$QUALIFIER

echo "Deploying JCEF binary package for Windows in version $VERSION $DEPLOYTYPE"

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

mvn $DEPLOYCMD -DgroupId=de.gebit.jcef -Dpackaging=jar -Drepo.user=$NEXUS_USER -Drepo.pass=$NEXUS_PASS -DartifactId=jcef-binaries-windows -Dfile=$OUTPUT_DIR/jcef-binaries-windows.jar -Dversion=$VERSION
