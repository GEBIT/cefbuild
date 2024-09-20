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
            CEF_PLATFORM=linuxarm64
            JOGAMP_ARCH=aarch64
            CEF_RELEASE_DIR=$CEF_RELEASE_DIR_ARM64
            CMAKE_ARGS="-DPROJECT_ARCH=arm64 --toolchain $(pwd)/cmake_toolchain_arm64"
            export JAVA_HOME=$(pwd)/amazon-corretto-11.0.24.8.1-linux-aarch64
        fi
    else
        echo "Found x86 CEF build"
        CEF_RELEASE_DIR=$CEF_RELEASE_DIR_32
        CEF_PLATFORM=linux32
        JOGAMP_ARCH=i586
        CMAKE_ARGS="-DCMAKE_C_FLAGS=-m32 -DCMAKE_CXX_FLAGS=-m32 -DPROJECT_ARCH=x86"
    fi
else
    echo "Found x64 CEF build"
    CEF_RELEASE_DIR=$CEF_RELEASE_DIR_64
    CEF_PLATFORM=linux64
    JOGAMP_ARCH=amd64
    CMAKE_ARGS="-DPROJECT_ARCH=amd64"
    export JAVA_HOME=$(pwd)/amazon-corretto-11.0.24.8.1-linux-x64
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_$CEF_PLATFORM ]]; then
    CEF_RELEASE_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to extract CEF version number"
    exit 1
fi

# Relatively big binary is an indication of a debug build ('debug' as in 'has symbols', not actually a real debug build)
if [ $(stat -c%s "$CEF_RELEASE_DIR/Release/libcef.so") -gt 300000000 ]; then
     BUILDTYPE="Debug"
    cp -r $CEF_RELEASE_DIR/Release $CEF_RELEASE_DIR/Debug
    # We actually want to create a real debug build of JCEF, because that's not such a size problem as with CEF, but
    # debug builds of JCEF expect CEF to be in a Debug directory. Hence we do the copying here.
else
    BUILDTYPE="Release"
fi

echo "Found binary $CEF_PLATFORM CEF $BUILDTYPE distribution in version $CEF_RELEASE_VERSION at $CEF_RELEASE_DIR"

if ! [ -x "$(command -v docker)" ]; then
    if [ $CEF_PLATFORM == 'linux64' ]; then
        echo "You seem to be inside of a Docker container. The 64 bit JCEF build may NOT be performed inside the container necessary for 32 bit building! This script thus expects you to run 64 bit builds on bare metal."
        exit 1
    fi
else
    if [ $CEF_PLATFORM == 'linux32' ]; then
        echo "You seem to be outside of a Docker container. Will now attempt to run this script inside the 32bit-jcef-build docker image (which is expected to have been built already on the local system)."
        ./32bit-docker/run.sh $(dirname $(readlink -f $0))/$(basename $0)
        if [[ $? == 0 ]]; then
            exit 0
        else
            exit 1
        fi
    fi
fi

# libcef_dll_wrapper is not strictly necessary for JCEF, but we build it nevertheless in this script because
# the build process is very similar, thus we can re-use a lot of the infrastructure
echo "Preparing to build libcef_dll_wrapper"
WRAPPER_BUILD_DIR=$CEF_RELEASE_DIR/build
rm -rf $WRAPPER_BUILD_DIR
mkdir $WRAPPER_BUILD_DIR
bash -l -c "cd $WRAPPER_BUILD_DIR && cmake -G 'Ninja' $CMAKE_ARGS -DCMAKE_BUILD_TYPE=$BUILDTYPE .."

echo "Building libcef_dll_wrapper"
bash -l -c "cd $WRAPPER_BUILD_DIR && ninja -j8 libcef_dll_wrapper"
if [[ $? == 0 ]]; then
    echo "Successful libcef_dll_wrapper build!"
else
    echo "libcef_dll_wrapper BUILD FAILED!"
    exit
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
bash -l -c "cd $JCEF_BUILD_DIR && cmake -G 'Ninja' $CMAKE_ARGS -DCMAKE_BUILD_TYPE=$BUILDTYPE -DCEF_VERSION=$CEF_RELEASE_VERSION .."

echo "Building JCEF"
bash -l -c "cd $JCEF_BUILD_DIR && ninja -j8"

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

echo "Copying CEF header files to output directory"
CEF_HEADER_DIR=$JCEF_BINARIES_DIR/include
mkdir $CEF_HEADER_DIR
cp -r $CEF_RELEASE_DIR/include/* $CEF_HEADER_DIR

echo "Copying CEF libcef_dll source files to output directory"
CEF_HEADER_DIR=$JCEF_BINARIES_DIR/libcef_dll
mkdir $CEF_HEADER_DIR
cp -r $CEF_RELEASE_DIR/libcef_dll/* $CEF_HEADER_DIR

echo "Copying CEF cmake source files to output directory"
CEF_HEADER_DIR=$JCEF_BINARIES_DIR/cmake
mkdir $CEF_HEADER_DIR
cp -r $CEF_RELEASE_DIR/cmake/* $CEF_HEADER_DIR

echo "Copying libcef_dll_wrapper to output directory"
CEF_WRAPPER_DIR=$JCEF_BINARIES_DIR/libcef_dll_wrapper
mkdir $CEF_WRAPPER_DIR
cp -r $CEF_RELEASE_DIR/build/libcef_dll_wrapper/*.a $CEF_WRAPPER_DIR

echo "Packaging jcef-binaries-$CEF_PLATFORM"
bash -l -c "cd $JCEF_BINARIES_DIR && zip -r ../jcef-binaries-$CEF_PLATFORM.jar ./*"

echo "Extracting version number from version header file"
cat $JCEF_DIR/native/jcef_version.h | grep "define JCEF_VERSION" | cut -d'"' -f2 | cut -d'+' -f1 > $OUTPUT_DIR/jcef_version.txt

echo "All done!"
