# Security policy

## Reporting a vulnerability

Report vulnerabilities through the
[private security advisory form](https://github.com/ebrindley/OpenCodeGuard/security/advisories/new).
It is the only private channel. No email address is published.

Include the OpenCode Guard release you installed, the macOS version and chip,
the OpenCode version, the launch route (terminal or app) and the steps that
reproduce the problem. Do not include credentials or other secrets.

This is a personal project with one maintainer. Reports are handled on a
best-effort basis. There is no bug bounty.

## Supported versions

Only the latest release is supported.

## Bug or vulnerability

A vulnerability is a reliable way for an agent running under the guard to do
what the sandbox should stop:

- write outside ALLOW and the folders OpenCode needs;
- read a DENY entry;
- change the guard, the Guard List or another always-protected path;
- start OpenCode unguarded through the guard's `opencode` command or app
  without the plugin's refusal.

Everything else is a bug and goes to a public issue: a wrong refusal, a
destructive command cc-safety-net misses while the sandbox still holds, an
install or uninstall failure, and the limits listed in the
[README](README.md#limits). When unsure, use the advisory form.
