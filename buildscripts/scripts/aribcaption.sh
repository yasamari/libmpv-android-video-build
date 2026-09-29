#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

build=_build$ndk_suffix

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf $build
	exit 0
else
	exit 255
fi

# The NDK only supports cross compilation through a CMake toolchain file, and
# unlike every other dependency here libaribcaption has no make/meson cross
# support. Derive the ABI from the prefix dir name (armeabi-v7a, arm64-v8a,
# x86, x86_64 -- exactly what CMAKE_ANDROID_ARCH_ABI expects).
cmake_abi=$(basename "$prefix_dir")

mkdir -p $build
cat >$build/android.toolchain.cmake <<TOOLCHAIN
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 21)
set(CMAKE_ANDROID_ARCH_ABI $cmake_abi)
set(CMAKE_ANDROID_NDK $ndk_dir)
# Point at the prefixed clang directly instead of letting CMake go looking
# for $ndk_dir/toolchains/llvm/prebuilt/*/bin/<triple><api>-clang.
set(CMAKE_C_COMPILER $CC)
set(CMAKE_CXX_COMPILER $CXX)
# Only look inside the prefix for libraries, headers and packages so that the
# host's freetype is never picked up.
set(CMAKE_FIND_ROOT_PATH $prefix_dir)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
TOOLCHAIN

# /usr/local keeps GNUInstallDirs from using Debian's lib/<triplet> layout; the
# install prefix has to stay flat because prefix_dir symlinks local -> . (see
# setup_prefix in build.sh) and DESTDIR has to land inside prefix_dir/lib for
# PKG_CONFIG_LIBDIR to find libaribcaption.pc.
export DESTDIR="$prefix_dir"
cmake -G Ninja -S . -B $build \
	-DCMAKE_TOOLCHAIN_FILE=$PWD/$build/android.toolchain.cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr/local \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DCMAKE_PREFIX_PATH="$prefix_dir" \
	-DARIBCC_SHARED_LIBRARY=OFF \
	-DARIBCC_BUILD_TESTS=OFF \
	-DARIBCC_IS_ANDROID=ON \
	-DARIBCC_USE_FREETYPE=ON \
	-DARIBCC_USE_EMBEDDED_FREETYPE=OFF

cmake --build $build -j$cores
cmake --install $build
