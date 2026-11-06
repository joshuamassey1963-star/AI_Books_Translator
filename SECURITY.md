# Security Policy

## Reporting
Please report vulnerabilities privately via GitHub Security Advisories on this repository, not in public issues.

## Principles
- Bring-your-own-key; keys stored only in Android Keystore / iOS Keychain. Never in source, logs, analytics or git.
- Explicit consent before any book text leaves the device.
- Imported files are untrusted: hardened against path traversal, ZIP bombs, XXE, malformed XML, oversized images, unsafe HTML.
- Original files are never modified.
- Minimal platform permissions. Telemetry is opt-in and never contains book text.

## Supported versions
Pre-release; only the latest `develop` is supported.
