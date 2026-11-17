# Findings

Running, sanitized log of triaged results from the fuzzing campaign. Technical
detail for any unfixed, unpatched defect is withheld until coordinated
disclosure completes.

## Status

No confirmed vulnerabilities have been publicly disclosed yet. Candidate crashes
are minimized, root-caused, and verified against upstream `master` before being
reported to the maintainers.

## Log

| ID | Sanitizer report | Parse path | Status | Disclosure |
|----|------------------|------------|--------|------------|
| _(add entries as triage completes, e.g. ASan heap-buffer-overflow)_ | | | reported / fixed / duplicate | date |

## Disclosure policy

1. Minimize and root-cause the crash from the sanitizer report.
2. Confirm it reproduces on the latest upstream commit.
3. Report privately to the cn-cbor maintainers with a reproducer and a
   reasonable remediation window.
4. Publish only sanitized detail here after a fix ships or the window elapses.
