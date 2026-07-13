# Contributing to MiaoJi

Thank you for helping improve MiaoJi. Contributions of code, tests, documentation, design feedback, and reproducible bug reports are welcome.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

For a bug, search existing issues first and include:

- the iOS, Xcode, macOS, or Python version involved;
- clear reproduction steps and the expected behavior;
- relevant logs with tokens, financial details, email addresses, and recording URLs removed;
- a minimal sample when possible.

For a substantial feature or architecture change, open an issue before implementation so its scope and privacy impact can be discussed. Security vulnerabilities must be reported privately according to [SECURITY.md](SECURITY.md), not in a public issue.

## Development setup

Follow the setup instructions in [README.md](README.md). Keep client-safe publishable values in `client/MiaoJiConfig.xcconfig` and server-only credentials in `server/.env`. Never commit API keys, `service_role` credentials, user recordings, or real ledger exports.

## Branches and commits

- Create a focused branch from the current default branch.
- Prefer names such as `feat/voice-review`, `fix/csv-escaping`, or `docs/setup`.
- Keep commits small and explain why the change is needed.
- Conventional Commit prefixes such as `feat:`, `fix:`, `test:`, `docs:`, and `refactor:` are encouraged.

## Code guidelines

### Swift and SwiftUI

- Follow the existing naming and composition style.
- Keep user-facing strings clear and consistent with the existing Chinese interface.
- Preserve local-first behavior and avoid blocking the main actor with network or file work.
- Add accessibility labels or hints for custom interactive controls.
- Include tests for parsing, persistence, export, and synchronization behavior when applicable.

### Python and Flask

- Validate all client and model input at the API boundary.
- Never expose internal exceptions, secrets, or service-role credentials in responses.
- Keep model output normalization deterministic and constrained to client-provided categories.
- Add or update `unittest` coverage for every endpoint behavior change.

### Database changes

- Add forward-only SQL migrations under `supabase/migrations/`.
- Enable RLS on user-owned tables and scope policies to `auth.uid()`.
- Document any new bucket, environment variable, authentication, or retention requirement.

## Testing

Before opening a pull request, run the relevant checks:

```bash
python -m unittest server/test_app.py
```

Run iOS tests from Xcode with **Product → Test**. If a change affects layout, verify it on at least one compact iPhone and one iPad or explain why that was not possible.

## Pull requests

A good pull request:

- explains the problem, approach, and user-visible result;
- links the related issue when one exists;
- stays focused and avoids unrelated formatting changes;
- includes tests or explains why tests are not applicable;
- updates English and Chinese documentation when behavior changes;
- includes before/after visuals for meaningful UI changes, with private data removed;
- confirms that no secrets, recordings, or personal finance records were added.

Maintainers may request changes to preserve security, privacy, accessibility, or product consistency. All contributions are licensed under the repository's [MIT License](LICENSE).
