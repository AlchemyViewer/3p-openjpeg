#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

OPENJPEG_VERSION="1.5.1"
OPENJPEG_SOURCE_DIR="openjpeg-1.5.1"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"

echo "${OPENJPEG_VERSION}" > "${stage}/VERSION.txt"

pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            load_vsvars

            cmake . -G"Visual Studio 14" -DCMAKE_INSTALL_PREFIX=$stage
            
            build_sln "OPENJPEG.sln" "Release|Win32"
            build_sln "OPENJPEG.sln" "Debug|Win32"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp bin/Release/openjpeg{.dll,.lib} "$stage/lib/release"
            cp bin/Debug/openjpeg.dll "$stage/lib/debug/openjpegd.dll"
            cp bin/Debug/openjpeg.lib "$stage/lib/debug/openjpegd.lib"
            cp bin/Debug/openjpeg.pdb "$stage/lib/debug/openjpegd.pdb"
            mkdir -p "$stage/include/openjpeg"
            cp libopenjpeg/openjpeg.h "$stage/include/openjpeg"
        ;;
        "windows64")
            load_vsvars

            cmake . -G"Visual Studio 14 Win64" -DCMAKE_INSTALL_PREFIX=$stage
            
            build_sln "OPENJPEG.sln" "Release|x64"
            build_sln "OPENJPEG.sln" "Debug|x64"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp bin/Release/openjpeg{.dll,.lib} "$stage/lib/release"
            cp bin/Debug/openjpeg.dll "$stage/lib/debug/openjpegd.dll"
            cp bin/Debug/openjpeg.lib "$stage/lib/debug/openjpegd.lib"
            cp bin/Debug/openjpeg.pdb "$stage/lib/debug/openjpegd.pdb"
            mkdir -p "$stage/include/openjpeg"
            cp libopenjpeg/openjpeg.h "$stage/include/openjpeg"
        ;;
        "darwin")
	    cmake . -GXcode -D'CMAKE_OSX_ARCHITECTURES:STRING=i386;x86_64' -D'BUILD_SHARED_LIBS:bool=off' -D'BUILD_CODEC:bool=off' -DCMAKE_OSX_DEPLOYMENT_TARGET=10.8 -DCMAKE_INSTALL_PREFIX=$stage
	    xcodebuild -configuration Release -target openjpeg -project openjpeg.xcodeproj
	    xcodebuild -configuration Release -target install -project openjpeg.xcodeproj
            mkdir -p "$stage/lib/release"
	    cp "$stage/lib/libopenjpeg.a" "$stage/lib/release/libopenjpeg.a"
            mkdir -p "$stage/include/openjpeg"
	    cp "libopenjpeg/openjpeg.h" "$stage/include/openjpeg"
	  
        ;;
        "linux")
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector-strong -D_FORTIFY_SOURCE=2"
            CFLAGS="-m32 -O3 -ffast-math $HARDENED" CPPFLAGS="-m32" LDFLAGS="-m32" ./configure --target=i686-linux-gnu --prefix="$stage" \
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
            CFLAGS="-m64 -O3 -ffast-math $HARDENED" CPPFLAGS="-m64" LDFLAGS="-m64" ./configure --target=x86_64-linux-gnu --prefix="$stage" \
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

pass
