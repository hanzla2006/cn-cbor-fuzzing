# Findings

Running, sanitized log of triaged results from the fuzzing campaign. Technical
detail for any unfixed, unpatched defect is withheld until coordinated
disclosure completes.

## Target under test

This campaign targets **[jimsch/cn-cbor](https://github.com/jimsch/cn-cbor)**,
Jim Schaad's original tree, which is effectively archived/unmaintained. It is
tested rather than the maintained [cose-wg/cn-cbor](https://github.com/cose-wg/cn-cbor)
fork because many downstream IoT and firmware projects still vendor the legacy
jimsch tree directly, so defects found here reach real shipped code. Each entry
below pins the exact commit tested.

## Status

No confirmed vulnerabilities have been publicly disclosed yet. Candidate crashes
are minimized, root-caused, and verified against the tested commit before being
reported to the maintainers.

## Log

| ID | Sanitizer report | Affected function | Tested commit | Status | Disclosure |
|----|------------------|-------------------|---------------|--------|------------|
| _(add entries as triage completes, e.g. ASan heap-buffer-overflow)_ | | | | reported / fixed / duplicate | date |

## Disclosure policy

1. Minimize and root-cause the crash from the sanitizer report.
2. Record the exact cn-cbor commit it reproduces on.
3. Report privately to the maintainers with a reproducer and a reasonable
   remediation window.
4. Publish only sanitized detail here after a fix ships or the window elapses.
