# Security policy

Report vulnerabilities through the repository's
[private security advisory form](https://github.com/emanoelims/hugeicons/security/advisories/new).
Do not open a public issue with exploit details or share license keys, tokens,
or personal data.

Include the affected version or commit, reproduction steps, expected impact,
and a minimal example using synthetic data. Maintainers will coordinate fixes
and disclosure through the private report.

Areas of particular interest:

- the Hugeicons license key leaking anywhere other than the `Authorization`
  header of requests to `npm.hugeicons.com` (logs, error messages, cache files,
  other hosts, compiled artifacts);
- downloads accepted without matching the registry's integrity hash, or from an
  unexpected host;
- package data reaching the compiled HEEx templates unescaped;
- Pro icons ending up in the Hex package or the repository.

The project is experimental. Security fixes target the current `main` branch;
there is no long-term support or backport commitment for older releases.
