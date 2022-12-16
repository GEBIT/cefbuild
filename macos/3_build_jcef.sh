#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=./../../

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR_X64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_macosx64"`
CEF_RELEASE_DIR_ARM64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_macosarm64"`

if [ ! -d "$CEF_RELEASE_DIR_X64" ]; then
    if [ ! -d "$CEF_RELEASE_DIR_ARM64" ]; then
        echo "ERROR: Did not find a matching CEF branch release build in binary_distrib directory"
        exit
    else
        echo "Found arm64 CEF build"
        ARCH_PARAM="-DPROJECT_ARCH=arm64"
        ARCH_NAME="arm64"
        XCODE_PARAM="-target ALL_BUILD"
        CEF_RELEASE_DIR=$CEF_RELEASE_DIR_ARM64
    fi
else
    echo "Found x64 CEF build"
    ARCH_PARAM="-DPROJECT_ARCH=x86_64"
    ARCH_NAME="x64"
    XCODE_PARAM="-scheme ALL_BUILD"
    CEF_RELEASE_DIR=$CEF_RELEASE_DIR_X64
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_macos ]]; then
    CEF_RELEASE_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to extract CEF version number"
    exit
fi

if [ -d "$CEF_RELEASE_DIR/Debug" ]; then
    BUILDTYPE="Debug"
else
    BUILDTYPE="Release"
fi

echo "Found binary CEF $BUILDTYPE distribution in version $CEF_RELEASE_VERSION at $CEF_RELEASE_DIR"

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
bash -l -c "cd $JCEF_BUILD_DIR && cmake -G Xcode $ARCH_PARAM -DCEF_VERSION=$CEF_RELEASE_VERSION .."

if [ ! -d $JCEF_BUILD_DIR/jcef.xcodeproj ]; then
    echo "ERROR: Did not find the generated JCEF XCode Project"
    exit
fi

echo "Building JCEF"
xcodebuild CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -project $JCEF_BUILD_DIR/jcef.xcodeproj $XCODE_PARAM -configuration $BUILDTYPE
if [[ $? == 0 ]]; then
    echo "Successful build!"
else
    echo "BUILD FAILED!"
    exit
fi

echo "Copying JCEF binaries to output directories"
cp $JCEF_BUILD_DIR/native/$BUILDTYPE/jcef.jar $OUTPUT_DIR/jcef-classes.jar
cp $JCEF_BUILD_DIR/native/$BUILDTYPE/jcef-sources.jar $OUTPUT_DIR/jcef-classes-sources.jar
cp $JCEF_BUILD_DIR/native/$BUILDTYPE/libjcef.dylib $JCEF_BINARIES_DIR/
cp -r "$JCEF_BUILD_DIR/native/$BUILDTYPE/jcef Helper.app" $JCEF_BINARIES_DIR/
cp -r "$JCEF_BUILD_DIR/native/$BUILDTYPE/jcef Helper (GPU).app" $JCEF_BINARIES_DIR/
cp -r "$JCEF_BUILD_DIR/native/$BUILDTYPE/jcef Helper (Plugin).app" $JCEF_BINARIES_DIR/
cp -r "$JCEF_BUILD_DIR/native/$BUILDTYPE/jcef Helper (Renderer).app" $JCEF_BINARIES_DIR/

echo "Extracting JOGL binaries to output directory"
JOGL_DIR=$JCEF_BINARIES_DIR/jogl
mkdir $JOGL_DIR
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/gluegen-rt-natives-macosx-universal.jar "*.jnilib" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/gluegen-rt-natives-macosx-universal.jar "*.dylib" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/jogl-all-natives-macosx-universal.jar "*.jnilib" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/jogl-all-natives-macosx-universal.jar "*.dylib" -d $JOGL_DIR/

echo "Packaging jcef-binaries-macos"
bash -l -c "cd $JCEF_BINARIES_DIR && zip -r ../jcef-binaries-macos.jar ./*"

echo "Extracting version number from version header file"
cat $JCEF_DIR/native/jcef_version.h | grep "define JCEF_VERSION" | cut -d'"' -f2 | cut -d'+' -f1 > $OUTPUT_DIR/jcef_version.txt

echo "All done!"
