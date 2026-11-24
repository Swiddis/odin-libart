#!/bin/sh
# usage: ./build_asan.sh && LIBART_CLIENT=./client_asan.bin uv run pytest
set -eu
cd "$(dirname "$0")"
clang -g -O1 -fno-omit-frame-pointer -fsanitize=address -fPIC -shared \
    -std=c99 -D_GNU_SOURCE ../libart/src/art.c -o libart_asan.so
odin build . -sanitize:address -debug -define:LIBART_LIB=tests/libart_asan.so -out:client_asan.bin
