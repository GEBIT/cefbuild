#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=./../../
OUTPUT_DIR=./out

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR=`find $OUTPUT_DIR -type d -name "cef_binary_*.$BRANCH.*_macos*"`

if [ ! -d "$CEF_RELEASE_DIR" ]; then
    echo "ERROR: Did not find a matching CEF branch release build in out directory"
    exit
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_macos.* ]]; then
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

if [ ! -f "$OUTPUT_DIR/jcef-classes.jar" ]; then
    echo "ERROR: Did not find jcef-classes.jar"
    exit
fi

echo -n "Please enter a qualifier for this artifact release version: "
read QUALIFIER
if [ -z "$QUALIFIER" ]; then
    echo "ERROR: No qualifier was provided"
    exit
fi

VERSION=$JCEF_RELEASE_VERSION-$QUALIFIER

echo "Deploying JCEF classes package for MacOS to Nexus"

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

mvn deploy:deploy-file -Drepo.user=$NEXUS_USER -Drepo.pass=$NEXUS_PASS -DartifactId=jcef-classes -Dfile=$OUTPUT_DIR/jcef-classes.jar -Dsources=$OUTPUT_DIR/jcef-classes-sources.jar -Dversion=$VERSION
