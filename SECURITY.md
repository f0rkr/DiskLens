# Security Policy

DiskLens runs entirely **on your Mac**, it never uploads your files, file names,
or scan results anywhere, and it ships with **zero third-party runtime
dependencies** (only Apple system frameworks). Cleanup actions only ever move
items to the **Trash**, never an unrecoverable delete. Even so, we take security
seriously and welcome reports.

## Supported versions

DiskLens is shipped as a rolling release, the latest published
[release](https://github.com/f0rkr/DiskLens/releases/latest) is the only
supported version. Please reproduce issues against the latest build before
reporting.

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Instead, use GitHub's private vulnerability reporting:

1. Go to the [**Security** tab](https://github.com/f0rkr/DiskLens/security) of this repository.
2. Click **Report a vulnerability**.
3. Describe the issue, steps to reproduce, affected version, and impact.

You can expect:

- An acknowledgement within **72 hours**.
- An assessment and, where applicable, a fix timeline within **7 days**.
- Credit in the release notes once a fix ships, if you'd like it.

## Scope

In scope:

- The macOS app (`app/`), e.g. path-traversal, unsafe file handling, privilege issues, anything that could delete data outside the Trash or read files the user didn't choose.
- The website (`web/`), e.g. XSS, dependency vulnerabilities, supply-chain risks.
- CI/CD workflows (`.github/`), e.g. token exposure, injection.

Out of scope:

- Vulnerabilities in macOS itself or Apple frameworks.
- The app not being notarized (this is documented; it's a cost decision, not a vulnerability).
- Reports generated solely by automated scanners with no demonstrated impact.

Thank you for helping keep DiskLens and its users safe.
