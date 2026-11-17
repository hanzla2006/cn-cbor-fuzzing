# cn-cbor Fuzzing Campaign

A coverage-guided fuzzing harness and campaign targeting [**jimsch/cn-cbor**](https://github.com/jimsch/cn-cbor) at commit `f713bf6`, a compact C implementation of CBOR (RFC 8949) used in constrained IoT and embedded devices.

> **Finding #1:** heap out-of-bounds read (CWE-125) in the integer decode path, caused by an incorrect `unsigned long` cast (CWE-704, Incorrect Type Conversion or Cast). `ntoh32p` casts a 4-byte field pointer to `unsigned long` (8 bytes on LP64) and reads 4 bytes past the bounds-checked end. Triggered by the 5-byte input `1a 00 01 02 03`; reproduces on x86-64 and is **LP64-only** (not ILP32 or 64-bit Windows), see the Scope note in the finding. Reported as [issue #24](https://github.com/jimsch/cn-cbor/issues/24); CVE pending (MITRE CNA-LR). Full detail, reproducer, and sanitizer log in [`findings/README.md`](findings/README.md).

## Which cn-cbor

- **[jimsch/cn-cbor](https://github.com/jimsch/cn-cbor)** — Jim Schaad's original tree. Maintainer deceased (Oct 2020), so it is **unmaintained**, still vendored directly by downstream projects, and **not on OSS-Fuzz**. **This is the repository under test, pinned at `f713bf6`.**
- **[cose-wg/cn-cbor](https://github.com/cose-wg/cn-cbor)** — a later maintained fork, noted only for disambiguation. Not the subject of this campaign.

## Approach

- **Engines:** AFL++ (persistent mode) and libFuzzer, same harness. libFuzzer's exact-size allocation is what lets ASan see small over-reads, so it is the recommended engine for triage.
- **Sanitizers:** AddressSanitizer + UndefinedBehaviorSanitizer. ASan reports the out-of-bounds read; UBSan reports the unaligned load. Both fire on x86-64, independent of architecture.
- **Harnesses:** two, both over attacker-controlled input. `fuzz_cbor_decode` (decode only) and `fuzz_cbor_roundtrip` (decode, encode, decode again, encode again, then `memcmp` the two encodings and abort on any mismatch).
- **Seed corpus:** `corpus/` ships 20 valid CBOR items spanning every major type (integers of each width, byte/text strings, arrays, maps, tags, floats, and indefinite-length items).
- **Dictionary:** CBOR initial-byte tokens to reach deep parse states faster.
- **Triage:** each unique crash is minimized, root-caused from the sanitizer report, and pinned to the commit it reproduces on.

## Layout

```
cn-cbor-fuzzing/
├── harness/
│   ├── fuzz_cbor_decode.c      # decode-only entry point
│   └── fuzz_cbor_roundtrip.c   # round-trip + byte-compare
├── dictionaries/cbor.dict      # CBOR token dictionary
├── corpus/                     # 20 seed inputs, one per major type
├── findings/
│   ├── README.md               # Finding #1 (public): CWE-125 OOB read
│   ├── crash-oob-read-ai4.cbor # 5-byte reproducer
│   └── asan-oob-read.log       # captured ASan + UBSan output
├── patches/
│   └── 0001-fix-oob-read-ntoh32p.patch   # upstream fix (verified)
├── tools/
│   └── repro.c                 # standalone replay driver for the harness
├── build.sh                    # builds either harness under libFuzzer or AFL++
├── LICENSE                     # MIT (harness + scripts)
└── README.md
```

## Build

```bash
# the exact tree under test
git clone https://github.com/jimsch/cn-cbor.git
git -C cn-cbor checkout f713bf6

# libFuzzer, decode harness (recommended for triage)
./build.sh ./cn-cbor

# AFL++ build, or the roundtrip harness
./build.sh ./cn-cbor afl
./build.sh ./cn-cbor libfuzzer harness/fuzz_cbor_roundtrip.c
```

## Run

```bash
# reproduce Finding #1 (crashes immediately on the unpatched build)
./fuzz_cbor_decode findings/crash-oob-read-ai4.cbor

# AFL++
mkdir -p afl_out
afl-fuzz -i corpus -o afl_out -x dictionaries/cbor.dict -- ./fuzz_cbor_decode_afl
```

### Fuzzing past Finding #1

On the unpatched default build, `./fuzz_cbor_decode corpus/` crashes on the
first 4-byte-integer input (three seeds already trigger it), so a campaign can't
make progress until the bug is neutralized. Either apply the fix first:

```bash
git -C cn-cbor apply ../patches/0001-fix-oob-read-ntoh32p.patch
./build.sh ./cn-cbor
```

or build with the alignment-safe path via the `EXTRA_CFLAGS` passthrough:

```bash
EXTRA_CFLAGS=-DCBOR_ALIGN_READS ./build.sh ./cn-cbor
./fuzz_cbor_decode -dict=dictionaries/cbor.dict corpus/
```

## Campaign metrics

| Metric | Value |
|--------|-------|
| Engine | AFL++ (persistent mode); libFuzzer for triage |
| Sanitizers | ASan + UBSan |
| Harnesses | 2 — decode-only, decode + encode roundtrip |
| Campaign host | ARM64 (AArch64), Oracle Cloud instance |
| Defect architecture | LP64 only (64-bit Linux/macOS/BSD); reproduced on x86-64; not ILP32 or 64-bit Windows |
| Total executions | 21M+ |
| Result | 1 defect: heap OOB read (CWE-125) at `cn-cbor.c:219` |

## Responsible disclosure

cn-cbor is unmaintained (maintainer deceased), so Finding #1 was disclosed via a public upstream [issue](https://github.com/jimsch/cn-cbor/issues/24) and a direct CVE request to MITRE. A verified fix is in [`patches/`](patches/). This log is limited to what is already public; the defect is a denial-of-service out-of-bounds read, not a code-execution bug.

## License

Harness, build scripts, dictionary, corpus, and documentation here are MIT ([LICENSE](LICENSE)). cn-cbor is the property of its respective authors under its own license.
