#!/usr/bin/env bash

set -e

if ! type nix-prefetch-url &>/dev/null; then
	echo "This tool requires nix-prefetch-url"
	exit 1
fi

ljDistRepo="codebycruz/lj-dist"
ljDistTag="latest"

attrs() {
	indent="        "
	# echo "${indent}platform = \"$1\";"
	# echo "${indent}arch = \"$2\";"
	#(Silzinc) NOTE: Nix's mkDerivation exposes GNU's libc afaik
	if [ "$1" = "linux" ]; then
		suffix="-gnu"
	fi
	target="libluajit-$1-$2$suffix"
	echo "${indent}target = \"$target\";"
	url="https://github.com/$ljDistRepo/releases/download/$ljDistTag/$target.tar.gz"
	echo "${indent}url = \"$url\";"
	hash="$(nix-prefetch-url "$url" --unpack 2>/dev/null)"
	echo "${indent}hash = \"$hash\";"
}

cat <<EOF
platform_attrs = {
    "aarch64-darwin" = {
$(attrs macos aarch64)
    };
    "x86_64-darwin" = {
$(attrs macos x86-64)
    };
    "aarch64-linux" = {
$(attrs linux aarch64)
    };
    "x86_64-linux" = {
$(attrs linux x86-64)
    };
};
EOF
