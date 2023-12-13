#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=./../../

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR_X64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_macosx64"`
CEF_RELEASE_DIR_ARM64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_macosarm64"`

XCODE_CODE_SIGNING_PARAMS="CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"

if [ ! -d "$CEF_RELEASE_DIR_X64" ]; then
    if [ ! -d "$CEF_RELEASE_DIR_ARM64" ]; then
        echo "ERROR: Did not find a matching CEF branch release build in binary_distrib directory"
        exit
    else
        echo "Found arm64 CEF build"
        ARCH_PARAM="-DPROJECT_ARCH=arm64"
        ARCH_NAME="arm64"
        XCODE_TARGET_PARAM="-target"
        CEF_RELEASE_DIR=$CEF_RELEASE_DIR_ARM64
    fi
else
    echo "Found x64 CEF build"
    ARCH_PARAM="-DPROJECT_ARCH=x86_64"
    ARCH_NAME="x64"
    XCODE_TARGET_PARAM="-scheme"
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

# libcef_dll_wrapper is not strictly necessary for JCEF, but we build it nevertheless in this script because
# the build process is very similar, thus we can re-use a lot of the infrastructure
echo "Preparing to build libcef_dll_wrapper"
WRAPPER_BUILD_DIR=$CEF_RELEASE_DIR/build
rm -rf $WRAPPER_BUILD_DIR
mkdir $WRAPPER_BUILD_DIR
bash -l -c "cd $WRAPPER_BUILD_DIR && cmake -G Xcode $ARCH_PARAM -DCEF_VERSION=$CEF_RELEASE_VERSION .."

if [ ! -d $WRAPPER_BUILD_DIR/cef.xcodeproj ]; then
    echo "ERROR: Did not find the generated CEF XCode Project"
    exit
fi

echo "Building libcef_dll_wrapper"
xcodebuild $XCODE_CODE_SIGNING_PARAMS -project $WRAPPER_BUILD_DIR/cef.xcodeproj $XCODE_TARGET_PARAM libcef_dll_wrapper -configuration $BUILDTYPE
if [[ $? == 0 ]]; then
    echo "Successful libcef_dll_wrapper build!"
else
    echo "libcef_dll_wrapper BUILD FAILED!"
    exit
fi

OUTPUT_DIR=./out
JCEF_BINARIES_DIR=$OUTPUT_DIR/jcef-binaries-macos
JCEF_SUBDIR=$JCEF_BINARIES_DIR/jcef

echo "Cleaning output directory"
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR
mkdir $JCEF_BINARIES_DIR
mkdir $JCEF_SUBDIR
echo "Copying CEF distribution to output directory"
cp -r $CEF_RELEASE_DIR $OUTPUT_DIR
cp -r "$CEF_RELEASE_DIR/Release/Chromium Embedded Framework.framework" $JCEF_SUBDIR/

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
xcodebuild $XCODE_CODE_SIGNING_PARAMS -project $JCEF_BUILD_DIR/jcef.xcodeproj $XCODE_TARGET_PARAM ALL_BUILD -configuration $BUILDTYPE
if [[ $? == 0 ]]; then
    echo "Successful JCEF build!"
else
    echo "JCEF BUILD FAILED!"
    exit
fi

echo "Copying JCEF binaries to output directories"
cp $JCEF_BUILD_DIR/native/$BUILDTYPE/jcef.jar $OUTPUT_DIR/jcef-classes.jar
cp $JCEF_BUILD_DIR/native/$BUILDTYPE/jcef-sources.jar $OUTPUT_DIR/jcef-classes-sources.jar

cp $JCEF_BUILD_DIR/native/$BUILDTYPE/libjcef.dylib $JCEF_SUBDIR/
cp -r "$JCEF_BUILD_DIR/native/$BUILDTYPE/jcef Helper.app" $JCEF_SUBDIR/
cp -r "$JCEF_BUILD_DIR/native/$BUILDTYPE/jcef Helper (GPU).app" $JCEF_SUBDIR/
cp -r "$JCEF_BUILD_DIR/native/$BUILDTYPE/jcef Helper (Plugin).app" $JCEF_SUBDIR/
cp -r "$JCEF_BUILD_DIR/native/$BUILDTYPE/jcef Helper (Renderer).app" $JCEF_SUBDIR/

echo "Extracting JOGL binaries to output directory"
JOGL_DIR=$JCEF_BINARIES_DIR/jogl
mkdir $JOGL_DIR
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/gluegen-rt-natives-macosx-universal.jar "*.jnilib" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/gluegen-rt-natives-macosx-universal.jar "*.dylib" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/jogl-all-natives-macosx-universal.jar "*.jnilib" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/jogl-all-natives-macosx-universal.jar "*.dylib" -d $JOGL_DIR/

echo "Copying CEF header files to output directory"
CEF_HEADER_DIR=$JCEF_BINARIES_DIR/include
mkdir $CEF_HEADER_DIR
cp -r $CEF_RELEASE_DIR/include/* $CEF_HEADER_DIR

echo "Copying libcef_dll_wrapper to output directory"
CEF_WRAPPER_DIR=$JCEF_BINARIES_DIR/libcef_dll_wrapper
mkdir $CEF_WRAPPER_DIR
cp -r $CEF_RELEASE_DIR/build/libcef_dll_wrapper/$BUILDTYPE/* $CEF_WRAPPER_DIR

echo "Packaging jcef-binaries-macos"
bash -l -c "cd $JCEF_BINARIES_DIR && zip -r ../jcef-binaries-macos.jar ./*"

echo "Extracting version number from version header file"
cat $JCEF_DIR/native/jcef_version.h | grep "define JCEF_VERSION" | cut -d'"' -f2 | cut -d'+' -f1 > $OUTPUT_DIR/jcef_version.txt

echo "All done!"
