#!/bin/bash
cd "$(dirname "$0")"

# This builds JCEF and is intended to be executed in a GIT Bash on Windows
BASEDIR=./../../
VSDEVCMD_BAT="C:\Program^ Files\Microsoft^ Visual^ Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
CMAKE_VS_VERSION="Visual Studio 17 2022"

read -r BRANCH<../branch.txt

FIND_COMMAND="find $BASEDIR/chromium_git/chromium/src/cef/binary_distrib -type d -name 'cef_binary_*.$BRANCH.*_windows64'"
CEF_RELEASE_DIR=`eval $FIND_COMMAND`

if [ ! -d "$CEF_RELEASE_DIR" ]; then
    echo "ERROR: Did not find a matching CEF branch release build in binary_distrib directory"
    exit
fi

if [[ $CEF_RELEASE_DIR =~ cef_binary_(.+)_windows64 ]]; then
    CEF_RELEASE_VERSION=${BASH_REMATCH[1]}
else
    echo "ERROR: Failed to extract CEF version number"
    exit
fi

if [ -d "$CEF_RELEASE_DIR/Debug" ]; then
    BUILDTYPE="Debug"
    BUILDTYPE_LOWERCASE="debug"
else
    BUILDTYPE="Release"
    BUILDTYPE_LOWERCASE="release"
fi

echo "Found binary CEF $BUILDTYPE distribution in version $CEF_RELEASE_VERSION at $CEF_RELEASE_DIR"

# libcef_dll_wrapper is not strictly necessary for JCEF, but we build it nevertheless in this script because
# the build process is very similar, thus we can re-use a lot of the infrastructure
echo "Preparing to build libcef_dll_wrapper"
WRAPPER_BUILD_DIR=$CEF_RELEASE_DIR/build
rm -rf $WRAPPER_BUILD_DIR
mkdir $WRAPPER_BUILD_DIR
bash -l -c "cd $WRAPPER_BUILD_DIR && cmd.exe //C \"$VSDEVCMD_BAT & cmake -DCEF_RUNTIME_LIBRARY_FLAG=/MD -G \"$CMAKE_VS_VERSION\" ..\""

echo "Building libcef_dll_wrapper"
bash -l -c "cd $WRAPPER_BUILD_DIR && cmd.exe //C \"$VSDEVCMD_BAT & msbuild cef.sln /t:libcef_dll_wrapper /p:configuration=$BUILDTYPE_LOWERCASE\""
if [[ $? == 0 ]]; then
    echo "Successful libcef_dll_wrapper build!"
else
    echo "libcef_dll_wrapper BUILD FAILED!"
    exit
fi

OUTPUT_DIR=./out
JCEF_BINARIES_DIR=$OUTPUT_DIR/jcef-binaries-windows
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
bash -l -c "cd $JCEF_BUILD_DIR && cmd.exe //C \"$VSDEVCMD_BAT & cmake -G \"$CMAKE_VS_VERSION\" -D CEF_VERSION=$CEF_RELEASE_VERSION ..\""

if [ ! -f  $JCEF_BUILD_DIR/jcef.sln ]; then
    echo "ERROR: Did not find the generated JCEF Solution File"
    exit
fi

echo "Building JCEF"
bash -l -c "cd $JCEF_BUILD_DIR && cmd.exe //C \"$VSDEVCMD_BAT & msbuild jcef.sln /p:configuration=$BUILDTYPE_LOWERCASE\""  

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
cp -r $JCEF_BUILD_DIR/native/$BUILDTYPE/* $JCEF_SUBDIR/

# Also copy libcef.lib which is not strictly needed in JCEF usage, but in other cases of using libcef.dll...
cp -r $CEF_RELEASE_DIR/$BUILDTYPE/libcef.lib $JCEF_SUBDIR/

echo "Extracting JOGL binaries to output directory"
JOGL_DIR=$JCEF_BINARIES_DIR/jogl
mkdir $JOGL_DIR
# unzip command within GIT Bash does not seem to support wildcards in file filters :/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/gluegen-rt-natives-windows-amd64.jar natives/windows-amd64/gluegen_rt.dll -d $JOGL_DIR/
unzip -j $JCEF_THIRDPARTY_DIR/jogamp/jar/jogl-all-natives-windows-amd64.jar natives/windows-amd64/jogl_desktop.dll natives/windows-amd64/jogl_mobile.dll natives/windows-amd64/nativewindow_awt.dll natives/windows-amd64/nativewindow_win32.dll natives/windows-amd64/newt_head.dll -d $JOGL_DIR/

echo "Copying CEF header files to output directory"
CEF_HEADER_DIR=$JCEF_BINARIES_DIR/include
mkdir $CEF_HEADER_DIR
cp -r $CEF_RELEASE_DIR/include/* $CEF_HEADER_DIR

echo "Copying libcef_dll_wrapper to output directory"
CEF_WRAPPER_DIR=$JCEF_BINARIES_DIR/libcef_dll_wrapper
mkdir $CEF_WRAPPER_DIR
cp -r $CEF_RELEASE_DIR/build/libcef_dll_wrapper/$BUILDTYPE/*.lib $CEF_WRAPPER_DIR

echo "Packaging jcef-binaries-windows"
# zip command isn't even present in GIT Bash on Windows :( so we'll use a powershell workaround
bash -l -c "cd $JCEF_BINARIES_DIR && powershell.exe -nologo -noprofile -command \"& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::CreateFromDirectory('.', '../jcef-binaries-windows.jar'); }\""

echo "Extracting version number from version header file"
cat $JCEF_DIR/native/jcef_version.h | grep "define JCEF_VERSION" | cut -d'"' -f2 | cut -d'+' -f1 > $OUTPUT_DIR/jcef_version.txt

echo "All done!"
