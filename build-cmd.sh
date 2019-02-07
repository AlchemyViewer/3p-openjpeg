#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

top="$(pwd)"
stage="$(pwd)/stage"

mkdir -p $stage

# Load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

OPENJPEG_VERSION="1.5.1"
OPENJPEG_SOURCE_DIR="openjpeg"

VERSION_HEADER_FILE="$OPENJPEG_SOURCE_DIR/libopenjpeg/openjpeg.h"

build=${AUTOBUILD_BUILD_ID:=0}

# version will be (e.g.) "1.4.0"
version=`sed -n -E 's/#define OPENJPEG_VERSION "([0-9])[.]([0-9])[.]([0-9]).*/\1.\2.\3/p' "${VERSION_HEADER_FILE}"`
# shortver will be (e.g.) "230": eliminate all '.' chars
#since the libs do not use micro in their filenames, chop off shortver at minor
short="$(echo $version | cut -d"." -f1-2)"
shortver="${short//.}"

echo "${version}.${build}" > "${stage}/VERSION.txt"

# Create the staging folders
mkdir -p "$stage/lib"/{debug,release,relwithdebinfo}
mkdir -p "$stage/include/openjpeg"
mkdir -p "$stage/LICENSES"

pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        # ------------------------ windows, windows64 ------------------------
        windows*)
            load_vsvars

            cmake . -G "$AUTOBUILD_WIN_CMAKE_GEN" -DCMAKE_INSTALL_PREFIX=$stage
            
            cmake --build . --config Debug --clean-first
            cmake --build . --config Release --clean-first

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp bin/Release/openjpeg{.dll,.lib} "$stage/lib/release"
            cp bin/Debug/openjpeg{.dll,.lib,.pdb} "$stage/lib/debug"
            mkdir -p "$stage/include/openjpeg"
            cp libopenjpeg/openjpeg.h "$stage/include/openjpeg"
        ;;

        "darwin")
	    cmake . -GXcode -DCMAKE_OSX_ARCHITECTURES:STRING=x86_64 \
            -DBUILD_SHARED_LIBS:BOOL=ON -DBUILD_CODEC:BOOL=ON -DUSE_LTO:BOOL=ON \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=10.8 -DCMAKE_INSTALL_PREFIX=$stage
	    xcodebuild -configuration Release -sdk macosx10.11 \
            -target openjpeg -project openjpeg.xcodeproj
	    xcodebuild -configuration Release -sdk macosx10.11 \
            -target install -project openjpeg.xcodeproj
        install_name_tool -id "@executable_path/../Resources/libopenjpeg.dylib" "${stage}/lib/libopenjpeg.5.dylib"
            mkdir -p "${stage}/lib/release"
	    cp "${stage}"/lib/libopenjpeg.* "${stage}/lib/release/"
            mkdir -p "${stage}/include/openjpeg"
	    cp "libopenjpeg/openjpeg.h" "${stage}/include/openjpeg"
	  
        ;;
        "linux")
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector-strong -D_FORTIFY_SOURCE=2"
            CFLAGS="-m32 -O3 -ffast-math $HARDENED" CPPFLAGS="-m32" LDFLAGS="-m32" ./configure --prefix="$stage" \
                --enable-png=no --enable-lcms1=no --enable-lcms2=no --enable-tiff=no
            make -j$JOBS
            make install

            mv "$stage/include/openjpeg-1.5" "$stage/include/openjpeg"

            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
        ;;
        "linux64")
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector-strong -D_FORTIFY_SOURCE=2"
            CFLAGS="-m64 -O3 -ffast-math $HARDENED" CPPFLAGS="-m64" LDFLAGS="-m64" ./configure --prefix="$stage" \
                --enable-png=no --enable-lcms1=no --enable-lcms2=no --enable-tiff=no
            make -j$JOBS
            make install

            mv "$stage/include/openjpeg-1.5" "$stage/include/openjpeg"

            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/openjpeg.txt"
popd
