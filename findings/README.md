# Findings

Log of triaged results from the fuzzing campaign. The finding below is already
public (upstream issue filed), so technical detail is included.

## Target under test

This campaign targets **[jimsch/cn-cbor](https://github.com/jimsch/cn-cbor)**,
Jim Schaad's original tree. The maintainer passed away in October 2020 and the
repository is unmaintained, but many downstream IoT and firmware projects still
vendor this legacy tree directly (e.g. it appears embedded in larger codebases
and is not covered by OSS-Fuzz), so defects found here reach real shipped code.
Because upstream is unmaintained, disclosure was handled via a public GitHub
issue plus a direct CVE request to MITRE.

## Status

**Finding #1 — confirmed, reported, CVE pending.**

| ID | Class | Affected functions | Trigger condition | Impact | Platform | Disclosure |
|----|-------|--------------------|-------------------|--------|----------|------------|
| F1 | Misaligned memory access (CWE-704) → SIGBUS / undefined behavior | `ntoh32p`, `ntoh64p`, `decode_half` (`cn-cbor.c:114, 116, 216`) | multi-byte integer reads from unaligned buffer offsets with the library's default `CN_CBOR_ALIGN_READS=OFF` | Denial of service only; no memory corruption, no code execution | ARM (AArch64) | [issue #24](https://github.com/jimsch/cn-cbor/issues/24), filed 2026-11-14; CVE request submitted to MITRE (CNA-LR); CVSS 4.0 ≈ 6.9 (Medium) |

Found with AFL++ (persistent mode) under AddressSanitizer + UndefinedBehaviorSanitizer,
21M+ executions across two harnesses (decode-only and decode+encode roundtrip),
on an ARM64 Oracle Cloud instance. UBSan on AArch64 is what surfaces the
unaligned reads that a default x86 build silently tolerates.

## Disclosure policy

1. Minimize and root-cause the crash from the sanitizer report.
2. Record the exact cn-cbor commit it reproduces on.
3. For a maintained project, report privately first. cn-cbor is unmaintained
   (maintainer deceased), so disclosure was a public upstream issue plus a
   direct CVE request to MITRE.
4. Keep this log factual and limited to what is already public.
