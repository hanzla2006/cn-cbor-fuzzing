#!/usr/bin/env bash
#
# Build the cn-cbor decode fuzzer.
#
# Usage: ./build.sh <path-to-cn-cbor-source> [libfuzzer|afl]
#
#   libfuzzer (default) -> clang, libFuzzer + ASan + UBSan
#   afl                 -> afl-clang-fast + aflpp_driver + ASan/UBSan
#
set -euo pipefail

CN_CBOR_SRC="${1:-./cn-cbor}"
MODE="${2:-libfuzzer}"

if [[ ! -d "${CN_CBOR_SRC}/src" ]]; then
  echo "error: cn-cbor sources not found at ${CN_CBOR_SRC}" >&2
  echo "clone it first:  git clone https://github.com/jimsch/cn-cbor.git" >&2
  exit 1
fi

COMMON_SRC=( "-I${CN_CBOR_SRC}/include" -fno-omit-frame-pointer -g -O1
  harness/fuzz_cbor_decode.c "${CN_CBOR_SRC}"/src/*.c )

case "${MODE}" in
  libfuzzer)
    CC="${CC:-clang}"
    "${CC}" -fsanitize=fuzzer,address,undefined "${COMMON_SRC[@]}" -o fuzz_cbor_decode
    echo "built ./fuzz_cbor_decode"
    echo "run:  ./fuzz_cbor_decode -dict=dictionaries/cbor.dict corpus/"
    ;;

  afl)
    # AFL++ ships aflpp_driver (libAFLDriver.a): a main() that calls
    # LLVMFuzzerTestOneInput, so the same harness builds under AFL++ unchanged.
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
    AFL_USE_ASAN=1 AFL_USE_UBSAN=1 "${CC}" "${COMMON_SRC[@]}" "${DRIVER}" -o fuzz_cbor_decode_afl
    echo "built ./fuzz_cbor_decode_afl"
    echo "run:  mkdir -p afl_out && afl-fuzz -i corpus -o afl_out -x dictionaries/cbor.dict -- ./fuzz_cbor_decode_afl"
    ;;

  *)
    echo "error: unknown mode '${MODE}' (use 'libfuzzer' or 'afl')" >&2
    exit 1
    ;;
esac
