#!/usr/bin/env bash

# Compiles the vendored cmark-gfm C sources into a universal static library (one slice per
# architecture in $ARCHS), cached by source hash. The linker picks the matching slice, so the
# same library serves native test builds and universal app builds.
# stdout: absolute path to libcmark-gfm.a. All logging goes to stderr.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
cd "$project_dir"

source "${script_dir}/config.sh"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/${APP_NAME,,}"
vendor="Vendor/cmark-gfm"

if [[ ! -d "$vendor/src" || ! -d "$vendor/extensions" ]]; then
    printf '%s\n' "Error: vendored cmark-gfm sources not found in ${vendor}" >&2
    exit 1
fi

# The key covers the vendored sources plus this script, the deployment target, and the
# architectures, so changing the code or the compile flags forces a rebuild.
hash="$(
    {
        find "$vendor" -type f \( -name '*.c' -o -name '*.h' -o -name '*.inc' \) -print0 | sort -z | xargs -0 shasum
        shasum "${script_dir}/build_cmark.sh"
        printf '%s\n' "$MIN_MACOS_VERSION" "$ARCHS"
    } | shasum | cut -c1-16
)"
out="${cache_dir}/cmark/${hash}"
lib="${out}/libcmark-gfm.a"

if [[ -f "$lib" ]]; then
    printf '%s\n' "Using cached cmark-gfm (${hash})" >&2
else
    printf '%s\n' "Compiling vendored cmark-gfm for ${ARCHS} (${hash})..." >&2
    rm -rf "${out}/obj"
    slices=()
    for arch in $ARCHS; do
        mkdir -p "${out}/obj/${arch}"
        for f in "$vendor"/src/*.c "$vendor"/extensions/*.c; do
            clang -c -O2 -std=c99 \
                -target "${arch}-apple-macos${MIN_MACOS_VERSION}" \
                -I"$vendor/src/include" -I"$vendor/extensions/include" \
                -I"$vendor/src" -I"$vendor/extensions" \
                "$f" -o "${out}/obj/${arch}/$(basename "${f%.c}").o"
        done
        rm -f "${out}/obj/libcmark-gfm-${arch}.a"
        ar rcs "${out}/obj/libcmark-gfm-${arch}.a" "${out}/obj/${arch}"/*.o
        slices+=("${out}/obj/libcmark-gfm-${arch}.a")
    done
    rm -f "${lib}.tmp"
    lipo -create "${slices[@]}" -output "${lib}.tmp"
    mv "${lib}.tmp" "$lib" # atomic publish
fi

printf '%s\n' "$lib"
