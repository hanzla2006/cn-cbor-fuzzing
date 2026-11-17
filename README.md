# cn-cbor Fuzzing Campaign

A coverage-guided fuzzing harness and campaign targeting [**jimsch/cn-cbor**](https://github.com/jimsch/cn-cbor), a compact C implementation of the CBOR (Concise Binary Object Representation, RFC 8949) data format used in constrained IoT and embedded devices. The goal is to find memory-safety defects in the decoder and report them through coordinated disclosure.

> **Status:** Active. This repository documents the methodology, harness, and build so results are reproducible. Confirmed findings are disclosed responsibly to maintainers before any public detail appears here.

## Which cn-cbor

There are two trees with the same name, and this campaign targets the original:

- **[jimsch/cn-cbor](https://github.com/jimsch/cn-cbor)** — Jim Schaad's original implementation. It is effectively **archived/unmaintained**, but a large number of downstream IoT and firmware projects still vendor this legacy tree directly into their source. A memory-safety bug here therefore has real, shipped-code impact even though upstream is quiet. **This is the repository under test.**
- **[cose-wg/cn-cbor](https://github.com/cose-wg/cn-cbor)** — a later, more actively maintained fork. Noted only for disambiguation; it is *not* the subject of this campaign.

## Why cn-cbor

A CBOR decoder is fed untrusted bytes by design, so a single out-of-bounds read or write in the parse path can translate into a real remote memory-safety issue on shipped firmware. cn-cbor is small, widely vendored, and written in C, which makes it a high-value, tractable target for coverage-guided fuzzing.

## Approach

- **Engines:** libFuzzer (in-process, coverage-guided) by default, with an **AFL++** driver provided as an alternative (`./build.sh <src> afl`).
- **Sanitizers:** AddressSanitizer (heap/stack/global overflows, use-after-free) and UndefinedBehaviorSanitizer.
- **Target function:** the decode entry point (`cn_cbor_decode`), which takes an attacker-controlled buffer and length.
- **Seed corpus:** minimal valid CBOR items spanning every major type (unsigned/negative integers, byte/text strings, arrays, maps, tags, simple/float values) so the fuzzer starts with broad structural coverage.
- **Dictionary:** CBOR initial-byte tokens to help the mutator reach deep parse states faster.
- **Triage:** each unique crash is minimized, root-caused from the ASan report, and checked against the tested commit before any disclosure.

## Layout

```
cn-cbor-fuzzing/
├── harness/
│   └── fuzz_cbor_decode.c   # libFuzzer / AFL++ entry point (LLVMFuzzerTestOneInput)
├── dictionaries/
│   └── cbor.dict            # CBOR token dictionary
├── corpus/                  # seed inputs (add your own valid CBOR samples)
├── findings/
│   └── README.md            # honest, running log of triaged crashes
├── build.sh                 # builds the libFuzzer or AFL++ driver
├── LICENSE                  # MIT (harness + scripts)
└── README.md
```

## Build

Requires `clang` with the fuzzer + sanitizer runtimes (libFuzzer mode) or `afl-clang-fast` from AFL++ (AFL mode), plus the cn-cbor sources.

```bash
# 1. Get the target (the original tree)
git clone https://github.com/jimsch/cn-cbor.git

# 2a. libFuzzer build (default): clang, libFuzzer + ASan + UBSan
./build.sh ./cn-cbor

# 2b. AFL++ build: afl-clang-fast + aflpp_driver + ASan/UBSan
./build.sh ./cn-cbor afl
```

The same harness (`LLVMFuzzerTestOneInput`) compiles under both engines; the AFL++ build links AFL++'s `aflpp_driver` so no second harness file is needed.

## Run

libFuzzer:

```bash
mkdir -p corpus
./fuzz_cbor_decode -dict=dictionaries/cbor.dict corpus/

# reproduce a saved crash
./fuzz_cbor_decode crash-<hash>

# minimize a crashing input
./fuzz_cbor_decode -minimize_crash=1 -runs=100000 crash-<hash>
```

AFL++:

```bash
mkdir -p afl_out
afl-fuzz -i corpus -o afl_out -x dictionaries/cbor.dict -- ./fuzz_cbor_decode_afl
```

## Campaign metrics

Reproducible numbers from the current campaign. Fill each value from your own run
rather than quoting estimates; the commands that produce each figure are listed
so the measurement is repeatable.

| Metric | Value | How it was measured |
|--------|-------|---------------------|
| Tested commit | `<git rev-parse --short HEAD of cn-cbor>` | pinned so findings are reproducible |
| Total runtime | `<e.g. 24h>` | wall-clock of the run below |
| Executions/sec | `<exec/s>` | libFuzzer `-print_final_stats=1` |
| Total executions | `<N>` | libFuzzer final stats |
| Line / branch coverage | `<L% / B%>` | `llvm-cov report` (see below) |
| Corpus size (pre-merge) | `<N inputs>` | raw corpus before minimization |
| Corpus size (post-merge) | `<N inputs>` | after `-merge=1` |

Generate the figures:

```bash
# runtime + exec/s + total execs
./fuzz_cbor_decode -print_final_stats=1 -max_total_time=86400 \
    -dict=dictionaries/cbor.dict corpus/

# corpus minimization (pre/post counts)
ls corpus | wc -l                                   # pre-merge
./fuzz_cbor_decode -merge=1 corpus_min/ corpus/
ls corpus_min | wc -l                               # post-merge

# coverage: build a separate coverage binary, replay the corpus, report
clang -fprofile-instr-generate -fcoverage-mapping -g -O1 \
    -I./cn-cbor/include harness/fuzz_cbor_decode.c ./cn-cbor/src/*.c \
    -fsanitize=fuzzer -o fuzz_cov
LLVM_PROFILE_FILE=cov.profraw ./fuzz_cov -runs=0 corpus/
llvm-profdata merge -sparse cov.profraw -o cov.profdata
llvm-cov report ./fuzz_cov -instr-profile=cov.profdata
```

## Responsible disclosure

This project exists to improve the security of open-source software. Any confirmed, exploitable, or memory-unsafe defect is reported privately to the maintainers first, with a reasonable remediation window, before technical details are published here. No working exploit code is distributed. See [`findings/README.md`](findings/README.md) for the current, sanitized status.

## Repository metadata

For the GitHub "About" panel:

- **Description:** `Coverage-guided fuzzing of the jimsch/cn-cbor CBOR decoder (libFuzzer + AFL++, ASan/UBSan).`
- **Topics:** `fuzzing` · `libfuzzer` · `aflplusplus` · `cbor` · `iot-security` · `vulnerability-research` · `memory-safety`

## License

The harness, build scripts, dictionary, and documentation here are released under the [MIT License](LICENSE). cn-cbor is the property of its respective authors and carries its own license.
