# cn-cbor Fuzzing Campaign

A coverage-guided fuzzing harness and campaign targeting [**jimsch/cn-cbor**](https://github.com/jimsch/cn-cbor), a compact C implementation of the CBOR (Concise Binary Object Representation, RFC 8949) data format used in constrained IoT and embedded devices.

> **Finding #1:** confirmed misaligned-memory-access defect (CWE-704) in the decode path (`ntoh32p` / `ntoh64p` / `decode_half`), causing SIGBUS / undefined behavior on ARM with the library's default build. Reported upstream as [issue #24](https://github.com/jimsch/cn-cbor/issues/24); CVE ID pending (MITRE CNA-LR). DoS only, no code execution (CVSS 4.0 ≈ 6.9, Medium). Details in [`findings/README.md`](findings/README.md).

## Which cn-cbor

There are two trees with the same name; this campaign targets the original:

- **[jimsch/cn-cbor](https://github.com/jimsch/cn-cbor)** — Jim Schaad's original implementation. The maintainer passed away in October 2020, so the tree is **unmaintained**, yet many downstream IoT and firmware projects still vendor it directly and it is **not covered by OSS-Fuzz**. A defect here therefore has real, shipped-code impact. **This is the repository under test.**
- **[cose-wg/cn-cbor](https://github.com/cose-wg/cn-cbor)** — a later, more actively maintained fork, noted only for disambiguation. Not the subject of this campaign.

## Why cn-cbor

A CBOR decoder is fed untrusted bytes by design, so a defect in the parse path can translate into a real issue on shipped firmware. cn-cbor is small, widely vendored, unmaintained, and off OSS-Fuzz, which makes it a high-value, tractable target.

## Approach

- **Engine:** AFL++ in persistent mode (primary), with a libFuzzer build of the same harness as an alternative.
- **Sanitizers:** AddressSanitizer + UndefinedBehaviorSanitizer. UBSan on AArch64 is what surfaces the unaligned reads a default x86 build tolerates silently.
- **Harnesses:** two, both exercising attacker-controlled input — `fuzz_cbor_decode` (decode only) and `fuzz_cbor_roundtrip` (decode + re-encode).
- **Target:** the decode entry point (`cn_cbor_decode`) and, in the roundtrip harness, `cn_cbor_encoder_write`.
- **Seed corpus:** minimal valid CBOR items spanning every major type, for broad structural coverage.
- **Dictionary:** CBOR initial-byte tokens to reach deep parse states faster.
- **Triage:** each unique crash is minimized, root-caused from the sanitizer report, and pinned to the commit it reproduces on.

## Layout

```
cn-cbor-fuzzing/
├── harness/
│   ├── fuzz_cbor_decode.c      # decode-only entry point
│   └── fuzz_cbor_roundtrip.c   # decode + encode roundtrip
├── dictionaries/
│   └── cbor.dict               # CBOR token dictionary
├── corpus/                     # seed inputs
├── findings/
│   └── README.md               # triaged findings (Finding #1 public)
├── build.sh                    # builds either harness under libFuzzer or AFL++
├── LICENSE                     # MIT (harness + scripts)
└── README.md
```

## Build

Requires `clang` with the fuzzer + sanitizer runtimes (libFuzzer mode) or `afl-clang-fast` from AFL++ (AFL mode), plus the cn-cbor sources.

```bash
# 1. Get the target (the original tree)
git clone https://github.com/jimsch/cn-cbor.git

# 2. AFL++ build of the decode harness (how the finding was reproduced)
./build.sh ./cn-cbor afl

# alternatives:
./build.sh ./cn-cbor                                   # libFuzzer, decode harness
./build.sh ./cn-cbor afl harness/fuzz_cbor_roundtrip.c # AFL++, roundtrip harness
```

## Run

AFL++:

```bash
mkdir -p afl_out
afl-fuzz -i corpus -o afl_out -x dictionaries/cbor.dict -- ./fuzz_cbor_decode_afl
```

libFuzzer:

```bash
mkdir -p corpus
./fuzz_cbor_decode -dict=dictionaries/cbor.dict corpus/
./fuzz_cbor_decode crash-<hash>                        # reproduce
./fuzz_cbor_decode -minimize_crash=1 -runs=100000 crash-<hash>
```

## Campaign metrics

| Metric | Value |
|--------|-------|
| Engine | AFL++ (persistent mode) |
| Sanitizers | ASan + UBSan |
| Harnesses | 2 — decode-only, decode + encode roundtrip |
| Platform | ARM64 (AArch64), Oracle Cloud instance |
| Library build | `CN_CBOR_ALIGN_READS=OFF` (library default) |
| Total executions | 21M+ (across both harnesses) |
| Result | 1 defect class: misaligned memory access (CWE-704), DoS only |

## Responsible disclosure

cn-cbor is unmaintained (maintainer deceased), so Finding #1 was disclosed via a public upstream [issue](https://github.com/jimsch/cn-cbor/issues/24) and a direct CVE request to MITRE rather than a private report. This log is limited to what is already public. No working exploit is distributed; the defect is a denial-of-service alignment fault, not a code-execution bug.

## License

The harness, build scripts, dictionary, and documentation here are released under the [MIT License](LICENSE). cn-cbor is the property of its respective authors and carries its own license.
