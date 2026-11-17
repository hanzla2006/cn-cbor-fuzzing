# cn-cbor Fuzzing Campaign

A coverage-guided fuzzing harness and campaign targeting [**cn-cbor**](https://github.com/cose-wg/cn-cbor), a compact C implementation of the CBOR (Concise Binary Object Representation, RFC 8949) data format used in constrained IoT and embedded devices. The goal is to find memory-safety defects in the decoder and report them through coordinated disclosure.

> **Status:** Active. This repository documents the methodology, harness, and build so results are reproducible. Confirmed findings are disclosed responsibly to maintainers before any public detail appears here.

## Why cn-cbor

CBOR parsers sit on the attack surface of huge numbers of IoT and embedded deployments (COSE, LwM2M/Wakaama, and other constrained-device protocols). A decoder is fed untrusted bytes by design, so a single out-of-bounds read or write in the parse path can translate into a real remote-memory-safety issue on shipped firmware. cn-cbor is small, widely vendored, and written in C, which makes it a high-value, tractable target for coverage-guided fuzzing.

## Approach

- **Engine:** libFuzzer (in-process, coverage-guided). An AFL++ build is provided as an alternative driver.
- **Sanitizers:** AddressSanitizer (heap/stack/global overflows, use-after-free) and UndefinedBehaviorSanitizer.
- **Target function:** the decode entry point (`cn_cbor_decode`), which takes an attacker-controlled buffer and length.
- **Seed corpus:** minimal valid CBOR items spanning every major type (unsigned/negative integers, byte/text strings, arrays, maps, tags, simple/float values) so the fuzzer starts with broad structural coverage.
- **Dictionary:** CBOR initial-byte tokens to help the mutator reach deep parse states faster.
- **Triage:** each unique crash is minimized, root-caused from the ASan report, and checked against the latest upstream `master` before any disclosure.

## Layout

```
cn-cbor-fuzzing/
├── harness/
│   └── fuzz_cbor_decode.c   # libFuzzer entry point
├── dictionaries/
│   └── cbor.dict            # CBOR token dictionary
├── corpus/                  # seed inputs (add your own valid CBOR samples)
├── findings/
│   └── README.md            # honest, running log of triaged crashes
├── build.sh                 # one-shot build script
└── README.md
```

## Build

Requires `clang` (with the fuzzer + sanitizer runtimes) and the cn-cbor sources.

```bash
# 1. Get the target
git clone https://github.com/cose-wg/cn-cbor.git

# 2. Build the fuzzer (clang, libFuzzer + ASan + UBSan)
./build.sh ./cn-cbor
```

`build.sh` compiles the cn-cbor sources together with the harness under
`-fsanitize=fuzzer,address,undefined`.

## Run

```bash
mkdir -p corpus
./fuzz_cbor_decode -dict=dictionaries/cbor.dict corpus/
```

Useful flags:

```bash
# reproduce a saved crash
./fuzz_cbor_decode crash-<hash>

# minimize a crashing input
./fuzz_cbor_decode -minimize_crash=1 -runs=100000 crash-<hash>
```

## Responsible disclosure

This project exists to improve the security of open-source software. Any confirmed, exploitable, or memory-unsafe defect is reported privately to the cn-cbor maintainers first, with a reasonable remediation window, before technical details are published here. No working exploit code is distributed. See [`findings/README.md`](findings/README.md) for the current, sanitized status.

## License

Harness and scripts in this repository are released under the MIT License. cn-cbor is the property of its respective authors and carries its own license.
