#!/usr/bin/env bash
#
# Build a cn-cbor fuzzer.
#
# Usage: ./build.sh <path-to-cn-cbor-source> [libfuzzer|afl] [harness.c]
#
#   mode:    libfuzzer (default) -> clang, libFuzzer + ASan + UBSan
#            afl                 -> afl-clang-fast + aflpp_driver + ASan/UBSan
#   harness: harness/fuzz_cbor_decode.c (default) or harness/fuzz_cbor_roundtrip.c
#
# Extra compiler flags can be passed via EXTRA_CFLAGS, e.g. to fuzz PAST the
# known out-of-bounds read (Finding #1) instead of crashing on it immediately:
#
#     EXTRA_CFLAGS=-DCBOR_ALIGN_READS ./build.sh ./cn-cbor
#
# or apply patches/0001-fix-oob-read-ntoh32p.patch to the source first. Without
# one of those, ./fuzz_cbor_decode crashes on the first 4-byte integer input.
#
set -euo pipefail

CN_CBOR_SRC="${1:-./cn-cbor}"
MODE="${2:-libfuzzer}"
HARNESS="${3:-harness/fuzz_cbor_decode.c}"
EXTRA_CFLAGS="${EXTRA_CFLAGS:-}"

if [[ ! -d "${CN_CBOR_SRC}/src" ]]; then
  echo "error: cn-cbor sources not found at ${CN_CBOR_SRC}" >&2
  echo "clone it first:  git clone https://github.com/jimsch/cn-cbor.git" >&2
  exit 1
fi
if [[ ! -f "${HARNESS}" ]]; then
  echo "error: harness not found: ${HARNESS}" >&2
  exit 1
fi

BASE="$(basename "${HARNESS}" .c)"
COMMON_SRC=( "-I${CN_CBOR_SRC}/include" -fno-omit-frame-pointer -g -O1
  ${EXTRA_CFLAGS} "${HARNESS}" "${CN_CBOR_SRC}"/src/*.c )

case "${MODE}" in
  libfuzzer)
    CC="${CC:-clang}"
    "${CC}" -fsanitize=fuzzer,address,undefined "${COMMON_SRC[@]}" -o "${BASE}"
    echo "built ./${BASE}"
    echo "run:  ./${BASE} -dict=dictionaries/cbor.dict corpus/"
    ;;

  afl)
    CC="${AFL_CC:-afl-clang-fast}"
    if ! command -v "${CC}" >/dev/null 2>&1; then
      echo "error: ${CC} not found. Install AFL++ or set AFL_CC." >&2
      exit 1
    fi
    DRIVER="${AFL_DRIVER:-}"
    if [[ -z "${DRIVER}" ]]; then
      for d in \
        "$(dirname "$(command -v "${CC}")")/../lib/afl/libAFLDriver.a" \
        /usr/lib/afl/libAFLDriver.a \
        /usr/local/lib/afl/libAFLDriver.a; do
        [[ -f "${d}" ]] && DRIVER="${d}" && break
      done
    fi
    if [[ -z "${DRIVER}" ]]; then
      echo "error: aflpp_driver (libAFLDriver.a) not found." >&2
      echo "       set AFL_DRIVER=/path/to/libAFLDriver.a" >&2
      exit 1
    fi
    AFL_USE_ASAN=1 AFL_USE_UBSAN=1 "${CC}" "${COMMON_SRC[@]}" "${DRIVER}" -o "${BASE}_afl"
    echo "built ./${BASE}_afl"
    echo "run:  mkdir -p afl_out && afl-fuzz -i corpus -o afl_out -x dictionaries/cbor.dict -- ./${BASE}_afl"
    ;;

  *)
    echo "error: unknown mode '${MODE}' (use 'libfuzzer' or 'afl')" >&2
    exit 1
    ;;
esac
