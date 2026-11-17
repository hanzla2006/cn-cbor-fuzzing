# Findings

Triaged results from the fuzzing campaign. Finding #1 is public (upstream issue
filed), so full technical detail, a reproducer, and the sanitizer log are
included here.

## Target under test

**[jimsch/cn-cbor](https://github.com/jimsch/cn-cbor)** at commit **`f713bf6`**.
Jim Schaad, the original maintainer, passed away in October 2020, so the tree is
unmaintained. Many downstream projects still vendor this legacy code directly,
and it is not covered by OSS-Fuzz, so a defect here reaches real shipped code.
Because upstream is unmaintained, disclosure was a public GitHub issue plus a
direct CVE request to MITRE.

## Finding #1 — heap out-of-bounds read in the integer decode path

| Field | Value |
|-------|-------|
| **Class** | CWE-125 Out-of-bounds Read (primary); CWE-704 Incorrect Type Conversion or Cast (the root-cause `unsigned long` cast). UBSan also reports a misaligned load as a side effect of the same cast. |
| **Location** | `ntoh32p` macro, `src/cn-cbor.c:95`; crash observed at the call site `src/cn-cbor.c:219` (`ntoh32p(pos)` for a 4-byte argument). The 8-byte path via `ntoh64p` (`:114`/`:116`) is reachable by inspection but was not observed to fault under ASan in testing |
| **Tested commit** | `f713bf6` |
| **Affected versions** | tag `1.0.0` and master through `f713bf6`, default build (`CBOR_ALIGN_READS` undefined); only `f713bf6` was dynamically tested |
| **Architectures** | **LP64 only** (64-bit Linux, macOS, BSD); reproduced on x86-64. Not ARM-specific, but also not present on ILP32 or LLP64, see Scope below |
| **Impact** | denial of service: a conditional crash, only when the input ends at unmapped memory (not attacker-controlled). A big-endian information-disclosure case exists by analysis but is largely theoretical and untested (see severity notes). Not code execution. |
| **Reproducer** | [`crash-oob-read-ai4.cbor`](crash-oob-read-ai4.cbor), the 5 bytes `1a 00 01 02 03`; also three valid seeds (`03_uint32`, `10_tag_epoch`, `15_single_float`) |
| **Sanitizer log** | [`asan-oob-read.log`](asan-oob-read.log), generated from the harness via [`../tools/repro.c`](../tools/repro.c) |
| **Disclosure** | [issue #24](https://github.com/jimsch/cn-cbor/issues/24), filed 2026-11-14; CVE request submitted to MITRE (CNA-LR) |

### Root cause

On the default build, the decode path reads multi-byte integer fields through:

```c
#define ntoh32p(p) (ntohl(*(unsigned long *)(p)))   /* src/cn-cbor.c:95 */
```

On any LP64 platform `unsigned long` is **8 bytes**, so reading a **4-byte**
CBOR field dereferences 8 bytes. The bounds check guarding the read,

```c
#define TAKE(pos, ebuf, n, stmt) if ((n) > (size_t)((ebuf) - (pos))) ...  /* :137 */
```

only validates `n` (= 4) bytes are present, so `ntoh32p` reads **4 bytes past**
the validated end of the input buffer. With an exact-size heap allocation this
is a heap-buffer-overflow read; the same cast is also an unaligned access.

The general trigger is any well-formed message where a **4-byte argument**, that
is a 32-bit integer, a `float32`, or a 4-byte byte-string / text-string / array /
map length, falls within the last 4 bytes of the input. Confirmed on the
unpatched default build with `1a 00 01 02 03` (uint32), `fa 3f 80 00 00`
(float32), `5a 00 00 00 00` (byte-string length), and `9a 00 00 00 00` (array
length). It is reachable with ordinary valid CBOR, not just crafted input.

### Scope: LP64 only

The out-of-bounds read exists only where `unsigned long` is wider than the
4-byte field being read, i.e. **LP64** data models (64-bit Linux, macOS, BSD),
where it is 8 bytes. On **LLP64** (64-bit Windows) and **ILP32** (most 32-bit
microcontroller firmware), `unsigned long` is 4 bytes, so the cast reads exactly
the field and there is no overread. The secondary misalignment (CWE-704) can
still fault on strict-alignment 32-bit cores, but the CWE-125 overread requires
an LP64 target. This tempers the "reaches shipped IoT firmware" impact, since a
large share of constrained firmware is ILP32 and unaffected by the overread.

### Reproduce

The committed log [`asan-oob-read.log`](asan-oob-read.log) was generated from
the harness itself (`fuzz_cbor_decode.c`) via the standalone replay driver
[`../tools/repro.c`](../tools/repro.c), which hands the file to the harness in an
exact-size heap buffer (required for ASan to see a 4-byte overrun):

```bash
# build the harness + replay driver with ASan + UBSan (default build)
gcc -fsanitize=address,undefined -g -O1 -I cn-cbor/include \
    harness/fuzz_cbor_decode.c tools/repro.c cn-cbor/src/*.c -o repro
./repro findings/crash-oob-read-ai4.cbor

# or feed it straight to the libFuzzer binary
./fuzz_cbor_decode findings/crash-oob-read-ai4.cbor
```

Observed (see [`asan-oob-read.log`](asan-oob-read.log); addresses redacted):

```
cn-cbor.c:219:4: runtime error: load of misaligned address ... requires 8 byte alignment
ERROR: AddressSanitizer: heap-buffer-overflow ... READ of size 8
    #0 decode_item cn-cbor/src/cn-cbor.c:219
    #1 cn_cbor_decode cn-cbor/src/cn-cbor.c:365
```

### Fix

Building with `-DCBOR_ALIGN_READS` already routes these reads through a
`memcpy` into an exact-width type and eliminates both the overread and the
misalignment. The proper upstream fix is to make that path the default; see
[`../patches/0001-fix-oob-read-ntoh32p.patch`](../patches/0001-fix-oob-read-ntoh32p.patch),
which was verified to clear the reproducer under ASan + UBSan.

## Notes on severity

The overread is 4 bytes into adjacent heap, and its functional effect depends on
byte order, because the 8-byte load is narrowed to `ntohl`'s 32-bit argument:

- **Little-endian LP64** (x86-64, AArch64): the low 32 bits selected are the
  field's own 4 bytes, so the decoded value is correct and the overread bytes
  are discarded. Realistic impact is a crash (DoS) on a guard page or hardened
  allocator. This is the configuration tested here.
- **Big-endian LP64** (analysis, not tested): the low 32 bits selected are the 4
  bytes *after* the field rather than the field itself, so every 4-byte integer
  would decode from the following bytes. For an in-bounds field that is simply a
  wrong value, which means the default build is likely already unusable on
  big-endian LP64; only a field at the very end of the buffer turns it into an
  over-read that may expose adjacent memory. The information-disclosure scenario
  is therefore largely theoretical and untested.

The realistic impact is denial of service (a crash, and only when the input
happens to end at unmapped memory, which the attacker does not control), not
code execution. Any CVSS score should reflect that conditional crash.
