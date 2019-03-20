#!/bin/bash
cd "$(dirname "$0")"

BASEDIR=/home/cefbuild/code/

read -r BRANCH<../branch.txt

CEF_RELEASE_DIR=`find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name "cef_binary_3.$BRANCH.*_linux64"`

if [ ! -d "$CEF_RELEASE_DIR" ]; then
    echo "ERROR: Did not find a matching CEF branch release build in binary_distrib directory"
    exit
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_linux64 ]]; then
    CEF_RELEASE_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to extract CEF version number"
    exit
fi

echo "Found binary CEF distribution in version $CEF_RELEASE_VERSION at $CEF_RELEASE_DIR"

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
bash -l -c "cd $JCEF_BUILD_DIR && cmake -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=Release -DCEF_VERSION=$CEF_RELEASE_VERSION .."

if [ ! -f  $JCEF_BUILD_DIR/Makefile ]; then
    echo "ERROR: Did not find the generated JCEF Makefile"
    exit
fi

echo "Building JCEF"
bash -l -c "cd $JCEF_BUILD_DIR && make -j8"

if [[ $? == 0 ]]; then
    echo "Successful build!"
else
    echo "BUILD FAILED!"
    exit
fi

echo "Copying JCEF binaries to output directory"
# JCEF Classes are deliberately not copied here, as those must be built only on the MacOS build machine. The classes are
# generally cross-platform, except for one Mac-specific class which can only be built on MacOS, thus MacOS is the designated
# build platform for the JCEF jar file.
cp -r $JCEF_BUILD_DIR/native/Release/* $JCEF_SUBDIR/

echo "Extracting JOGL binaries to output directory"
JOGL_DIR=$JCEF_BINARIES_DIR/jogl
mkdir $JOGL_DIR
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/gluegen-rt-natives-linux-amd64.jar "*.so" -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/jogl-all-natives-linux-amd64.jar "*.so" -d $JOGL_DIR/

echo "Packaging jcef-binaries-linux"
bash -l -c "cd $JCEF_BINARIES_DIR && zip -r ../jcef-binaries-linux.jar ./*"

echo "All done!"
