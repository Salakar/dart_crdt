# Security Policy

## Supported Versions

Security fixes are prepared for the `main` branch and the latest published
package version. Pre-1.0 releases may receive fixes as a new pre-release rather
than a patch on an older line.

## Reporting A Vulnerability

Report suspected vulnerabilities privately using GitHub Security Advisories:
<https://github.com/mikediarmid/ycrdt/security/advisories/new>.

Do not open a public issue, discussion, or pull request for a suspected
vulnerability until a fix or mitigation is available.

## What To Include

Include enough detail for maintainers to reproduce and assess the issue:

- Affected package version, commit, platform, and Dart SDK version.
- Minimal reproduction or failing test.
- Impacted APIs, serialized payloads, or update flows.
- Whether the issue affects confidentiality, integrity, availability, or data
  corruption.
- Any known workaround.

## Coordinated Disclosure

Maintainers will acknowledge reports, validate the issue, prepare tests and a
fix, and coordinate disclosure through the advisory. Public disclosure happens
after a mitigation is available or when the report is determined not to be a
security issue.
