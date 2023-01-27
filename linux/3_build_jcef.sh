#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=./../../

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR_64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_linux64"`
CEF_RELEASE_DIR_32=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_linux32"`
CEF_RELEASE_DIR_ARM64=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_*.$BRANCH.*_linuxarm64"`


if [ ! -d "$CEF_RELEASE_DIR_64" ]; then
    if [ ! -d "$CEF_RELEASE_DIR_32" ]; then
        if [ ! -d "$CEF_RELEASE_DIR_ARM64" ]; then
            echo "ERROR: Did not find a matching CEF branch release build in binary_distrib directory"
            exit 1
        else
            echo "Found arm64 CEF build"
            BITNESS=64
            JOGAMP_ARCH=aarch64
            CEF_RELEASE_DIR=$CEF_RELEASE_DIR_ARM64
            CMAKE_ARGS="-DPROJECT_ARCH=arm64"
        fi
    else
        echo "Found x86 CEF build"
        CEF_RELEASE_DIR=$CEF_RELEASE_DIR_32
        BITNESS=32
        JOGAMP_ARCH=i586
        CMAKE_ARGS="-DCMAKE_C_FLAGS=-m32 -DCMAKE_CXX_FLAGS=-m32 -DPROJECT_ARCH=x86"
    fi
else
    echo "Found x64 CEF build"
    CEF_RELEASE_DIR=$CEF_RELEASE_DIR_64
    BITNESS=64
    JOGAMP_ARCH=amd64
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_linux.+ ]]; then
    CEF_RELEASE_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to extract CEF version number"
    exit 1
fi

if [ -d "$CEF_RELEASE_DIR/Debug" ]; then
    BUILDTYPE="Debug"
else
    BUILDTYPE="Release"
fi

echo "Found binary $BITNESS bit $JOGAMP_ARCH CEF $BUILDTYPE distribution in version $CEF_RELEASE_VERSION at $CEF_RELEASE_DIR"

if ! [ -x "$(command -v docker)" ]; then
    if [ $BITNESS == 64 ]; then
        echo "You seem to be inside of a Docker container. The 64 bit JCEF build may NOT be performed inside the container necessary for 32 bit building! This script thus expects you to run 64 bit builds on bare metal."
        exit 1
    fi
else
    if [ $BITNESS == 32 ]; then
        echo "You seem to be outside of a Docker container. Will now attempt to run this script inside the 32bit-jcef-build docker image (which is expected to have been built already on the local system)."
        ./32bit-docker/run.sh $(dirname $(readlink -f $0))/$(basename $0)
        if [[ $? == 0 ]]; then
            exit 0
        else
            exit 1
        fi
    fi
fi

OUTPUT_DIR=./out
JCEF_BINARIES_DIR=$OUTPUT_DIR/jcef-binaries-linux
JCEF_SUBDIR=$JCEF_BINARIES_DIR/jcef

echo "Cleaning output directory"
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR
mkdir $JCEF_BINARIES_DIR
mkdir $JCEF_SUBDIR

echo "Copying CEF distribution to output directory"
cp -r $CEF_RELEASE_DIR $OUTPUT_DIR

JCEF_DIR=$BASEDIR/java-cef
JCEF_THIRDPARTY_DIR=$JCEF_DIR/third_party
if [ ! -d "$JCEF_THIRDPARTY_DIR/cef" ]; then
    echo "ERROR: Did not find the CEF third-party dir where expected ($JCEF_THIRDPARTY_DIR/cef)"
    exit 1
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
bash -l -c "cd $JCEF_BUILD_DIR && cmake -G 'Unix Makefiles' $CMAKE_ARGS -DCEF_PLATFORM=linux$BITNESS -DCMAKE_BUILD_TYPE=$BUILDTYPE -DCEF_VERSION=$CEF_RELEASE_VERSION .."

if [ ! -f  $JCEF_BUILD_DIR/Makefile ]; then
    echo "ERROR: Did not find the generated JCEF Makefile"
    exit 1
fi

echo "Building JCEF"
bash -l -c "cd $JCEF_BUILD_DIR && make -j8"

if [[ $? == 0 ]]; then
    echo "Successful build!"
else
    echo "BUILD FAILED!"
    exit 1
fi

echo "Copying JCEF binaries to output directory"
# JCEF Classes are deliberately not copied here, as those must be built only on the MacOS build machine. The classes are
# generally cross-platform, except for one Mac-specific class which can only be built on MacOS, thus MacOS is the designated
# build platform for the JCEF jar file.
cp -r $JCEF_BUILD_DIR/native/$BUILDTYPE/* $JCEF_SUBDIR/

echo "Extracting JOGL binaries to output directory"
JOGL_DIR=$JCEF_BINARIES_DIR/jogl
mkdir $JOGL_DIR
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/gluegen-rt-natives-linux-$JOGAMP_ARCH.jar "*.so" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/jogl-all-natives-linux-$JOGAMP_ARCH.jar "*.so" -d $JOGL_DIR/

echo "Packaging jcef-binaries-linux$BITNESS"
bash -l -c "cd $JCEF_BINARIES_DIR && zip -r ../jcef-binaries-linux$BITNESS.jar ./*"

echo "Extracting version number from version header file"
cat $JCEF_DIR/native/jcef_version.h | grep "define JCEF_VERSION" | cut -d'"' -f2 | cut -d'+' -f1 > $OUTPUT_DIR/jcef_version.txt

echo "All done!"
