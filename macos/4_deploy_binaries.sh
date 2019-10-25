#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=./../../
OUTPUT_DIR=./out

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR=`find $OUTPUT_DIR -type d -name "cef_binary_*.$BRANCH.*_macosx64"`

if [ ! -d "$CEF_RELEASE_DIR" ]; then
    echo "ERROR: Did not find a matching CEF branch release build in out directory"
    exit
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_macosx64 ]]; then
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
if [ $(stat -c%s "$OUTPUT_DIR/jcef-binaries-macos/jcef/libcef.dylib") -gt 1000000000 ]; then
    BUILD_TYPE="Debug"
else
    BUILD_TYPE="Release"
fi

JCEF_RELEASE_VERSION=$(cat $JCEF_VERSION_FILE)

echo "Found CEF version $CEF_RELEASE_VERSION (cleaned-up: $CEF_CLEAN_VERSION)"
echo "Found JCEF version $JCEF_RELEASE_VERSION which will be our artifact version"
echo "The build to be packaged is a $BUILD_TYPE build"

if [ ! -f "$OUTPUT_DIR/jcef-binaries-macos.jar" ]; then
    echo "ERROR: Did not find jcef-binaries-macos.jar"
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

echo "Deploying JCEF binary package for MacOS in version $VERSION to Nexus"
mvn -gs ../../mvn-settings/settings.xml deploy:deploy-file -DartifactId=jcef-binaries-macos -Dfile=$OUTPUT_DIR/jcef-binaries-macos.jar -Dversion=$VERSION
