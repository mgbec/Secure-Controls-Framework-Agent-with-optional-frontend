# Non-Human Identities in A2A and Agentic Workflows

*A research briefing with references, written to follow up on the SCF Compliance
Agent's move to an agents-only ingress.*

> Scope note: this is a technical/architectural briefing, not legal or compliance
> advice. Dates and statistics are attributed to their sources; verify current
> figures before citing them externally. Content from external sources has been
> paraphrased and summarized for licensing compliance.

---

## 1. Why this matters now

When you removed the human-facing frontend from this project and left only the
Agent-to-Agent (A2A) path, you changed *who* — or rather *what* — authenticates
to the system. The caller is no longer a person logging in through a browser; it
is a **non-human identity (NHI)**: a workload that holds a credential, mints a
token, and calls an API on its own schedule.

This is now the dominant case, not an edge case. Industry research through 2025
consistently reports that non-human identities vastly outnumber human ones in
enterprises, with commonly cited ratios ranging from dozens to over a hundred
NHIs per human user, and the gap widening as organizations deploy AI agents
([Okta](https://www.okta.com/blog/identity-security/securing-agentic-ai-workforce.julie-mason/),
[Aembit / Entro Security data](https://aembit.io/blog/owasps-top-security-risks-for-non-human-identities-and-how-to-address-them/),
[Cloud Security Alliance](https://cloudsecurityalliance.org/blog/2026/07/08/governing-non-human-identities-in-agentic-systems)).
The specific numbers vary by vendor and methodology, so treat any single ratio
as illustrative rather than authoritative.

The important shift is qualitative. As the Cloud Security Alliance frames it, a
new and riskier class of NHI is emerging: unlike a static service account, an
agentic identity behaves non-deterministically because a language model drives
its actions, it runs continuously, and it often inherits broad privileges to get
its work done ([CSA, 2026](https://cloudsecurityalliance.org/blog/2026/07/08/governing-non-human-identities-in-agentic-systems)).
That combination — autonomy, always-on, over-broad access — is exactly what
makes agent identities harder to govern than the machine identities we are used
to.

---

## 2. How A2A handles identity (and what it deliberately leaves to you)

The A2A protocol is now an open standard governed under the Linux Foundation
([A2A spec](https://a2a-protocol.org/latest/specification/),
[google-a2a/A2A](https://github.com/google-a2a/A2A)). Its design philosophy for
security is *don't reinvent* — integrate with existing enterprise identity
infrastructure rather than inventing a new scheme. The A2A "Enterprise-Ready"
guidance spells out the model
([A2A enterprise-ready topic](https://a2a-protocol.org/latest/topics/enterprise-ready/)):

- **Transport security is mandatory.** All production A2A traffic must run over
  HTTPS, with TLS 1.2+ and certificate validation to prevent
  machine-in-the-middle attacks.
- **Identity lives at the transport/HTTP layer, not in the payload.** A2A
  JSON-RPC messages do not carry caller identity. Authentication is established
  through HTTP headers using standards like OAuth 2.0 and OpenID Connect.
- **The Agent Card advertises the scheme.** A server declares its supported
  authentication schemes in the Agent Card's `security` field, aligned with the
  OpenAPI authentication definitions. Clients read the card to learn how to
  authenticate.
- **Credentials are obtained out-of-band.** The client acquires its OAuth token
  or key through a process external to A2A (for example, an OAuth
  `client_credentials` flow), then presents it as `Authorization: Bearer
  <token>`.
- **The server validates every request** and returns `401 Unauthorized` for
  missing/invalid credentials or `403 Forbidden` when a valid caller lacks
  permission.
- **Authorization should be granular and least-privilege**, including
  *skill-based* authorization where specific OAuth scopes grant access to some
  agent skills but not others.
- **API management is recommended** for centralized policy: authentication,
  authorization, **rate limiting, and quotas**.

The key takeaway: A2A standardizes the *handshake and conversation*, but it
intentionally treats credential provisioning, trust establishment, and identity
verification as out of scope — those are your responsibility
([SecureW2 overview](https://securew2.com/blog/a2a-protocol-security)). Academic
and industry analyses of A2A echo this: the protocol has a more thorough security
considerations section than most comparable specs, but the hard problems of
*who issued this credential and should I trust it* sit outside the wire protocol
([Systematic Security Analysis of the A2A Protocol, arXiv](https://arxiv.org/html/2609.10871);
[Safeguarding Sensitive Data in Multi-Agent Systems, arXiv](https://arxiv.org/html/2505.12490v1);
[Tyk A2A security guide](https://tyk.io/learning-center/a2a-security-the-developers-complete-guide/)).

### How this project maps to the model

This repository already implements the A2A model faithfully, which is worth
noting because it means the follow-up work is incremental, not a rewrite:

- API Gateway terminates TLS and hosts the JSON-RPC routes.
- Native **JWT authorizers** (Amazon Cognito and, optionally, Microsoft Entra ID)
  validate the bearer token before the bridge Lambda runs — matching A2A's
  transport-layer authentication.
- The machine caller uses the **OAuth 2.0 `client_credentials`** grant against
  Cognito, with a **custom `invoke` scope** — matching A2A's out-of-band
  credential acquisition and skill/scope model.
- Cognito M2M access tokens are configured with a **60-minute lifetime** — short,
  per the guidance below.
- Per-route **throttling** (added in the cost-controls work) is exactly the "rate
  limiting and quotas" that A2A's API-management guidance calls for.

See [`docs/a2a-integration.md`](a2a-integration.md) for the concrete auth flows.

---

## 3. Machine-to-machine authentication: the current standard

For non-human callers, the well-established pattern is the **OAuth 2.0 Client
Credentials grant** (RFC 6749 §4.4): the workload holds a `client_id` and either
a `client_secret` or a private key for a signed `client_assertion`, exchanges
them at the authorization server's token endpoint for a short-lived access token
(commonly 5–60 minutes), and presents that token on subsequent calls
([Security Boulevard M2M guide](https://securityboulevard.com/2026/05/machine-to-machine-m2m-authentication-complete-guide-with-oauth-2-0-client-credentials-flow/),
[SSOJet](https://ssojet.com/blog/service-account-authentication-best-practices-api-keys-oauth),
[Authgear](https://www.authgear.com/post/the-complete-guide-to-machine-to-machine-m2m-authentication/)).

Two nuances matter for agentic systems:

1. **Client credentials define *how* a workload authenticates, not *whether* it
   should be trusted.** Strong implementations pair the grant with short token
   lifetimes, narrow scopes, and secret rotation
   ([nhimg.org glossary](https://nhimg.org/glossary/oauth-20-client-credentials/)).
2. **Prefer workload identity federation over stored secrets where the platform
   supports it.** Rather than storing a long-lived client secret, the workload
   proves its provenance at runtime (environment attestation or a signed identity
   token) and exchanges that proof for short-lived access. This is the direction
   of travel in both vendor guidance and the IETF WIMSE working group's
   "Workload Identity Practices" draft
   ([IETF WIMSE draft](https://www.ietf.org/archive/id/draft-ietf-wimse-workload-identity-practices-04.html),
   [nhimg.org FAQ](https://nhimg.org/faq/how-should-security-teams-replace-static-secrets-in-service-to-service-oauth-flo/),
   [Google Cloud WIF best practices](https://docs.cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation)).
   On AWS, the equivalent is having the calling workload assume an IAM role via
   its execution environment instead of holding a Cognito client secret.

For token lifetime specifically, the trade-off is blast-radius vs. token-endpoint
load: shorter tokens limit how long a stolen token is useful, at the cost of more
frequent token requests ([IDPro Body of Knowledge on OAuth token lifetimes](https://bok.idpro.org/article/108/galley/264/download)).

---

## 4. The risk landscape: OWASP Non-Human Identities Top 10 (2025)

The most directly useful reference for this work is the **OWASP Non-Human
Identities Top 10 (2025)** — the first OWASP list dedicated to NHI risk, launched
in December 2024 and ranked by exploitability, prevalence, detectability, and
impact ([OWASP NHI Top 10 project](https://owasp.org/projects/non-human-identities-top-10),
[index / list source](https://github.com/OWASP/www-project-non-human-identities-top-10/blob/master/index.md)).
The ten risks, paraphrased, with how they apply to an A2A agent:

| # | Risk | Relevance to an A2A agent |
|---|------|---------------------------|
| NHI1 | **Improper Offboarding** — NHIs not deactivated when no longer needed | Retire M2M clients / Entra app registrations for callers that are decommissioned. |
| NHI2 | **Secret Leakage** — keys/tokens leaked into code, config, or chat | The calling agent's Cognito client secret must never land in source or logs. |
| NHI3 | **Vulnerable Third-Party NHI** — compromised extensions/SaaS with granted access | Vet any third-party agent you grant an `invoke` credential to. |
| NHI4 | **Insecure Authentication** — deprecated/weak auth methods | Use OAuth2/OIDC JWT validation (as this project does), not static API keys. |
| NHI5 | **Overprivileged NHI** — more permissions than the function requires | Keep the token scope to `invoke` only; don't widen it into a catch-all. |
| NHI6 | **Insecure Cloud Deployment Configurations** — static creds or poorly validated OIDC in CI/CD | Validate token claims (issuer, audience) strictly; prefer OIDC/role assumption over static keys. |
| NHI7 | **Long-Lived Secrets** — credentials that expire too far out or never | Short token TTLs (60 min here) plus a client-secret rotation runbook. |
| NHI8 | **Environment Isolation** — reusing the same NHI across dev/test/prod | Separate credentials per environment; don't share one client across stages. |
| NHI9 | **NHI Reuse** — one identity shared across apps/components | Issue one client per calling agent so a compromise is contained and revocable. |
| NHI10 | **Human Use of NHI** — people using machine identities for manual tasks | Don't let operators hand-drive the M2M credential; that destroys attribution. |

Sources summarizing these risks and mitigations include the OWASP project itself
and independent walkthroughs
([Orca Security](https://orca.security/resources/blog/owasp-non-human-identities-top-10/),
[Security Boulevard](https://securityboulevard.com/2025/05/tackling-the-owasp-top-10-nhi-risks-for-2025/),
[Aembit](https://aembit.io/blog/owasps-top-security-risks-for-non-human-identities-and-how-to-address-them/)).
Note that reported breach statistics (for example, the frequently cited figure
that a majority of organizations have had an incident involving a compromised
NHI) come from vendor and analyst surveys; cite the primary survey, not the blog,
if you use a number externally.

---

## 5. Governing agentic NHIs: the emerging playbook

Beyond the OWASP risk list, several 2025–2026 sources converge on a consistent
Zero Trust governance model for agent identities. The recurring themes:

- **Treat agents as first-class identities**, distinct from both human users and
  legacy service accounts, with an owner, a lifecycle, and an audit trail
  ([Rubrik: 8 strategies](https://www.rubrik.com/insights/8-strategies-for-ai-agent-security),
  [Okta](https://www.okta.com/blog/identity-security/securing-agentic-ai-workforce.julie-mason/)).
- **Just-in-time, least-standing-privilege access** — provision access when the
  task needs it rather than granting broad standing privilege
  ([Rubrik](https://www.rubrik.com/insights/8-strategies-for-ai-agent-security),
  [Erdal Ozkaya](https://erdalozkaya.com/non-human-identity-security-for-ai-agents/)).
- **Dynamic secrets, PKI, secret scanning, and auditing** as the operational
  backbone for NHIs at scale
  ([HashiCorp](https://www.hashicorp.com/en/blog/zero-trust-for-agentic-systems-managing-non-human-identities-at-scale)).
- **Full action traceability** — every agent action attributable to a specific
  identity, which is why NHI reuse and human-use-of-NHI are called out as risks
  ([Rubrik](https://www.rubrik.com/insights/8-strategies-for-ai-agent-security)).
- **Delegated-authority frameworks** that make an agent accountable for actions
  taken on a principal's behalf — an active research area, e.g. a Zero Trust
  governance framework for delegated authority and accountable non-human actors
  ([MDPI Informatics, 2025](https://www.mdpi.com/2227-9709/13/9/146)).

There is also a real, not hypothetical, threat backdrop. Reporting in late 2025
described what was characterized as an AI-orchestrated intrusion campaign abusing
an agentic coding tool against multiple organizations
([Vectra AI summary](https://www.vectra.ai/topics/agentic-ai-security)). Treat
the specifics as vendor-reported and follow the primary reporting before drawing
conclusions, but the direction is clear: agent credentials and agent autonomy are
becoming attacker targets and attacker tools.

---

## 6. Cost and performance differences: human vs. non-human callers

This dimension gets less coverage in the security literature but matters just as
much operationally, and it drove the concrete changes already made to this
project.

- **Traffic shape.** A human behind a UI is self-throttling — they read, think,
  and type. A machine caller has no such natural brake and can loop, retry, or
  fan out at machine speed. That makes non-human traffic *more predictable when
  bounded* (templated prompts, capped concurrency, scheduled runs) and
  *potentially unbounded when not* (a bug or a compromised credential can drive
  billable model calls fast).
- **The bill follows the compute, not the identity.** For this project the cost
  is dominated by Bedrock model tokens and AgentCore runtime session time. The
  identity type (Cognito M2M vs. human OIDC vs. IAM) is essentially free; what
  changes cost is how the identity *behaves*.
- **Async suits machines.** This project's non-blocking submit-then-poll model
  (`message/send` returns immediately, a worker runs the turn, the client polls
  `tasks/get`) is a good fit for machine callers, which tolerate polling and long
  runs that would frustrate a human. See [`docs/a2a-streaming.md`](a2a-streaming.md).
- **The controls that make it predictable** are rate limiting/quotas (which A2A's
  own API-management guidance recommends), a concurrency cap on the worker, and a
  spend alarm. These are defense-in-depth for *both* cost and abuse — a
  throttle that stops a runaway loop is simultaneously a security control and a
  cost control.

---

## 7. A follow-up checklist for this project

Grounded in the sources above and mapped to what already exists here:

- [x] TLS-terminated ingress with JWT authorizers (A2A transport auth) — *in place*
- [x] OAuth2 `client_credentials` with a narrow `invoke` scope (least privilege) — *in place*
- [x] Short (60 min) M2M token lifetime — *in place*
- [x] Per-route rate limiting + a monthly budget alarm — *added in the cost-controls work*
- [ ] **One credential per calling agent** (addresses NHI9 reuse, NHI1 offboarding) — today a single shared M2M client exists
- [ ] **Secret rotation runbook** for the Cognito client secret (NHI7 long-lived secrets)
- [ ] **Move toward workload identity federation / IAM role assumption** instead of a stored client secret where the caller runs on AWS (NHI2, NHI6)
- [ ] **Log `client_id` per request + alarm on per-caller request rate** (traceability, anomaly detection)
- [ ] **Environment isolation**: separate clients/pools for dev/test/prod (NHI8)
- [ ] **Drop the Entra route if unused**, or use an App role for pure app-to-app (reduce auth surface)
- [ ] **Offboarding process**: retire clients for decommissioned callers (NHI1)

---

## 8. References

**Primary standards & protocol**
- A2A Protocol specification — https://a2a-protocol.org/latest/specification/
- A2A Enterprise-Ready guidance (security, auth, API management) — https://a2a-protocol.org/latest/topics/enterprise-ready/
- A2A project (Linux Foundation) — https://github.com/google-a2a/A2A
- OWASP Non-Human Identities Top 10 (2025) — https://owasp.org/projects/non-human-identities-top-10 and list source https://github.com/OWASP/www-project-non-human-identities-top-10/blob/master/index.md
- IETF WIMSE, "Workload Identity Practices" (draft) — https://www.ietf.org/archive/id/draft-ietf-wimse-workload-identity-practices-04.html
- OAuth 2.0 Client Credentials grant (RFC 6749 §4.4) — https://datatracker.ietf.org/doc/html/rfc6749#section-4.4

**Machine-to-machine auth & token practices**
- Security Boulevard — M2M authentication with OAuth 2.0 client credentials — https://securityboulevard.com/2026/05/machine-to-machine-m2m-authentication-complete-guide-with-oauth-2-0-client-credentials-flow/
- SSOJet — service account authentication best practices — https://ssojet.com/blog/service-account-authentication-best-practices-api-keys-oauth
- Authgear — complete guide to M2M authentication — https://www.authgear.com/post/the-complete-guide-to-machine-to-machine-m2m-authentication/
- nhimg.org — OAuth 2.0 client credentials glossary — https://nhimg.org/glossary/oauth-20-client-credentials/
- nhimg.org — replacing static secrets with workload identity federation — https://nhimg.org/faq/how-should-security-teams-replace-static-secrets-in-service-to-service-oauth-flo/
- Google Cloud — Workload Identity Federation best practices — https://docs.cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation
- Google Identity — OAuth client credential handling — https://developers.google.com/identity/protocols/oauth2/resources/best-practices
- IDPro Body of Knowledge — OAuth 2.0 token lifetimes — https://bok.idpro.org/article/108/galley/264/download

**NHI & agentic identity governance**
- Cloud Security Alliance — Governing Non-Human Identities in Agentic Systems — https://cloudsecurityalliance.org/blog/2026/07/08/governing-non-human-identities-in-agentic-systems
- Okta — Securing the Agentic AI Workforce — https://www.okta.com/blog/identity-security/securing-agentic-ai-workforce.julie-mason/
- HashiCorp — Zero trust for agentic systems: managing NHIs at scale — https://www.hashicorp.com/en/blog/zero-trust-for-agentic-systems-managing-non-human-identities-at-scale
- Rubrik — Agentic AI security: 8 strategies — https://www.rubrik.com/insights/8-strategies-for-ai-agent-security
- MDPI Informatics — From Service Accounts to Agentic Identities (Zero Trust governance framework) — https://www.mdpi.com/2227-9709/13/9/146
- Orca Security — OWASP NHI Top 10 walkthrough — https://orca.security/resources/blog/owasp-non-human-identities-top-10/
- Aembit — OWASP top security risks for NHIs — https://aembit.io/blog/owasps-top-security-risks-for-non-human-identities-and-how-to-address-them/
- Security Boulevard — Tackling the OWASP Top 10 NHI risks for 2025 — https://securityboulevard.com/2025/05/tackling-the-owasp-top-10-nhi-risks-for-2025/
- Erdal Ozkaya — Non-Human Identity Security for AI Agents — https://erdalozkaya.com/non-human-identity-security-for-ai-agents/

**A2A security analysis & threat landscape**
- arXiv — Systematic Security Analysis of the A2A Protocol — https://arxiv.org/html/2609.10871
- arXiv — Safeguarding Sensitive Data in Multi-Agent Systems — https://arxiv.org/html/2505.12490v1
- Tyk — A2A security: the developer's complete guide — https://tyk.io/learning-center/a2a-security-the-developers-complete-guide/
- SecureW2 — What is A2A protocol security for AI agents? — https://securew2.com/blog/a2a-protocol-security
- Vectra AI — Agentic AI security: risks, threats & best practices — https://www.vectra.ai/topics/agentic-ai-security
- Microsoft Learn — Agent2Agent (A2A) authentication in Foundry — https://learn.microsoft.com/en-us/azure/ai-foundry/agents/concepts/agent-to-agent-authentication

*Compliance note: source content above has been paraphrased and summarized
rather than quoted, in line with content-licensing restrictions. Statistics and
dated claims are attributed to their publishers; confirm against the primary
source before external use.*
