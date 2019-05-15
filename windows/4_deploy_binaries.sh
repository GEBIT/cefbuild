#!/bin/bash
cd "$(dirname "$0")"

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

JCEF_RELEASE_VERSION=$(cat $JCEF_VERSION_FILE)

echo "Found CEF version $CEF_RELEASE_VERSION (cleaned-up: $CEF_CLEAN_VERSION)"
echo "Found JCEF version $JCEF_RELEASE_VERSION which will be our artifact version"

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

VERSION=$JCEF_RELEASE_VERSION-$QUALIFIER

echo "Deploying JCEF binary package for Windows in version $VERSION to Nexus"
mvn deploy:deploy-file -DartifactId=jcef-binaries-windows -Dfile=$OUTPUT_DIR/jcef-binaries-windows.jar -Dversion=$VERSION
