#!/usr/bin/env bash
#
# Build the cn-cbor decode fuzzer with libFuzzer + ASan + UBSan.
#
# Usage: ./build.sh <path-to-cn-cbor-source>
#
set -euo pipefail

CN_CBOR_SRC="${1:-./cn-cbor}"
CC="${CC:-clang}"
OUT="fuzz_cbor_decode"

if [[ ! -d "${CN_CBOR_SRC}/src" ]]; then
  echo "error: cn-cbor sources not found at ${CN_CBOR_SRC}" >&2
  echo "clone it first:  git clone https://github.com/cose-wg/cn-cbor.git" >&2
  exit 1
fi

SAN="-fsanitize=fuzzer,address,undefined -fno-omit-frame-pointer -g -O1"

"${CC}" ${SAN} \
  -I"${CN_CBOR_SRC}/include" \
  harness/fuzz_cbor_decode.c \
  "${CN_CBOR_SRC}"/src/*.c \
  -o "${OUT}"

echo "built ./${OUT}"
echo "run:  ./${OUT} -dict=dictionaries/cbor.dict corpus/"
