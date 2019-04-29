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

echo "Found CEF version $CEF_RELEASE_VERSION (cleaned-up: $CEF_CLEAN_VERSION)"

if [ ! -f "$OUTPUT_DIR/jcef-classes.jar" ]; then
    echo "ERROR: Did not find jcef-classes.jar"
    exit
fi

echo -n "Please enter a qualifier for this release version: "
read QUALIFIER
if [ -z "$QUALIFIER" ]; then
    echo "ERROR: No qualifier was provided"
    exit
fi

VERSION=$CEF_CLEAN_VERSION-$QUALIFIER

echo "Deploying JCEF classes package for MacOS to Nexus"
mvn deploy:deploy-file -DartifactId=jcef-classes -Dfile=$OUTPUT_DIR/jcef-classes.jar -Dsources=$OUTPUT_DIR/jcef-classes-sources.jar -Dversion=$VERSION
