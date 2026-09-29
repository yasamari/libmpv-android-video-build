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

unset CC CXX # meson wants these unset

# libplacebo 6.338.2 以降は mpv 0.41 の必須依存。`demos` は既定で on だが
# mpv 側が default_options で demos=false を渡すので、こちらは off にする。
# `vulkan` は Android では不要 (mpv 側も -Dvulkan=disabled を渡す) で、
# 有効にすると src/vulkan/utils_gen.py が走るがこれが Python 3.12 以降で
# 落ちる (ET.parse の戻り値を ET.Element に渡す非互換)。off にすると
# vulkan/stubs.c にフォールバックして生成器自体を呼ばない。
# `shaderc` / `glslang` は Vulkan 専用の GLSL コンパイラなので一緒に切る。
# その他の依存 (libdovi / lcms2 / libunwind / libxxhash) は `auto` なので、
# 見つからなければ自動で無効化される。
meson setup $build --cross-file "$prefix_dir"/crossfile.txt \
	--prefer-static \
	--default-library static \
	-Ddemos=false \
	-Dvulkan=disabled \
	-Dshaderc=disabled \
	-Dglslang=disabled

ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install
