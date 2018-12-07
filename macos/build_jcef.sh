#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=/Users/cefbuild/code/

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_3.$BRANCH.*_macosx64"`

if [ ! -d "$CEF_RELEASE_DIR" ]; then
    echo "ERROR: Did not find a matching CEF branch release build in binary_distrib directory"
    exit
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_macosx64 ]]; then
    CEF_RELEASE_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to extract CEF version number"
    exit
fi

echo "Found binary CEF distribution in version $CEF_RELEASE_VERSION at $CEF_RELEASE_DIR"

OUTPUT_DIR=./out
JCEF_BINARIES_DIR=$OUTPUT_DIR/jcef-binaries-macos

echo "Cleaning output directory"
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR
mkdir $JCEF_BINARIES_DIR
echo "Copying CEF distribution to output directory"
cp -r $CEF_RELEASE_DIR $OUTPUT_DIR
cp -r "$CEF_RELEASE_DIR/Release/Chromium Embedded Framework.framework" $JCEF_BINARIES_DIR/

JCEF_DIR=$BASEDIR/java-cef
JCEF_THIRDPARTY_DIR=$JCEF_DIR/third_party
if [ ! -d "$JCEF_THIRDPARTY_DIR/cef" ]; then
    echo "ERROR: Did not find the CEF third-party dir where expected ($JCEF_THIRDPARTY_DIR/cef)"
    exit
fi


echo "Cleaning JCEF third-party directory of older CEF releases"
rm -rf $JCEF_THIRDPARTY_DIR/cef/cef_binary*

echo "Copying CEF distribution to JCEF third-party directory"
cp -r $CEF_RELEASE_DIR $JCEF_THIRDPARTY_DIR/cef/

echo "Cleaning JCEF build directory"
JCEF_BUILD_DIR=$JCEF_DIR/jcef_build
rm -rf $JCEF_BUILD_DIR
mkdir $JCEF_BUILD_DIR

echo "Preparing to build JCEF"
bash -l -c "cd $JCEF_BUILD_DIR && cmake -G Xcode -DPROJECT_ARCH=x86_64 -DCEF_VERSION=$CEF_RELEASE_VERSION .."

if [ ! -d $JCEF_BUILD_DIR/jcef.xcodeproj ]; then
    echo "ERROR: Did not find the generated JCEF XCode Project"
    exit
fi

echo "Building JCEF"
xcodebuild -project $JCEF_BUILD_DIR/jcef.xcodeproj -scheme ALL_BUILD -configuration Release

echo "Copying JCEF binaries to output directories"
cp $JCEF_BUILD_DIR/native/Release/jcef.jar $OUTPUT_DIR/jcef-classes.jar
cp $JCEF_BUILD_DIR/native/Release/libjcef.dylib $JCEF_BINARIES_DIR/
cp "$JCEF_BUILD_DIR/native/Release/jcef Helper.app" $JCEF_BINARIES_DIR/

echo "Extracting JOGL binaries to output directory"
JOGL_DIR=$JCEF_BINARIES_DIR/jogl
mkdir $JOGL_DIR
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/gluegen-rt-natives-macosx-universal.jar "*.jnilib" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/jogl-all-natives-macosx-universal.jar "*.jnilib" -d $JOGL_DIR/

echo "Packaging jcef-binaries-macos"
bash -l -c "cd $JCEF_BINARIES_DIR && zip -r ../jcef-binaries-macos.jar ./*"

echo "All done!"
