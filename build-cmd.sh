#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

PNG_VERSION="1.4"
PNG_SOURCE_DIR="openjpeg_v1_4_sources_r697"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"
pushd "$PNG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            load_vsvars

	    cmake . -G"Visual Studio 10" -DCMAKE_INSTALL_PREFIX=$stage
            
            build_sln "OPENJPEG.sln" "Release|Win32"
            build_sln "OPENJPEG.sln" "Debug|Win32"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp bin/Release/openjpeg* "$stage/lib/release"
            cp bin/Debug/openjpeg* "$stage/lib/debug"
            mkdir -p "$stage/include/openjpeg"
            cp libopenjpeg/openjpeg.h "$stage/include/openjpeg"
        ;;
        "darwin")
            ./configure --prefix="$stage" --with-zlib-prefix="$stage/packages" --enable-png=no --enable-lcms1=no --enable-lcms2=no --enable-tiff=no
            make
            make install
#	    mkdir -p "$stage/lib/release"
#	    cp "$stage/lib/libpng15.a" "$stage/lib/release/"
        ;;
        "linux")
	    CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$stage" --enable-png=no --enable-lcms1=no --enable-lcms2=no --enable-tiff=no
            make
            make install
#	    mkdir -p "$stage/lib/release"
#	    cp "$stage/lib/libpng15.a" "$stage/lib/release/"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/openjpeg.txt"
popd

pass
