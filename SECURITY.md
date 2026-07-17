# Security Policy

## Supported versions

MiaoJi is currently in active pre-release development. Security fixes are applied to the latest version on the default branch; older commits and forks are not supported.

| Version | Supported |
| --- | --- |
| Latest default branch | Yes |
| Older versions | No |

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability. Email [zdjoey@126.com](mailto:zdjoey@126.com) with the subject `MiaoJi security report`.

Include, when available:

- the affected component and commit;
- a clear description of the impact;
- reproducible steps or a minimal proof of concept;
- suggested mitigations;
- whether the issue has been disclosed elsewhere.

Do not include real financial records, authentication tokens, service-role keys, private recording URLs, or another person's personal data. Use synthetic data and redact logs.

You should receive an acknowledgement within 5 business days. The maintainer will aim to validate the report, communicate its status, and coordinate a fix and disclosure timeline. Response and remediation times depend on severity and project availability.

## Scope priorities

Reports are especially valuable when they involve:

- authentication or authorization bypasses;
- Supabase RLS or cross-account data exposure;
- disclosure of API keys, JWTs, or `service_role` credentials;
- unsafe audio upload or URL validation behavior;
- prompt or model-output manipulation that bypasses server normalization;
- injection, remote code execution, or denial of service;
- unintended exposure of ledger exports, email addresses, or voice recordings.

General feature requests, availability problems without a security impact, and reports that require access to another user's account without permission are outside the security-reporting scope.

## Deployment guidance

- Keep `SUPABASE_SERVICE_ROLE_KEY` and `DASHSCOPE_API_KEY` on the server only.
- Use HTTPS for production API traffic and restrict server access appropriately.
- Treat the current public `user-audio` bucket as sensitive infrastructure. Define retention and deletion controls, avoid predictable identifiers, and do not use it for sensitive recordings without an explicit risk review.
- Apply the supplied RLS migration and verify policies with separate test accounts.
- Rotate any credential immediately if it is accidentally committed or logged.
- Keep dependencies, Xcode, and deployment runtimes updated with supported security releases.

## Safe harbor

Good-faith research that avoids privacy violations, data destruction, service disruption, and access beyond what is necessary to demonstrate the issue will be treated respectfully. Please allow reasonable time for remediation before public disclosure.
