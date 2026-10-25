# SCF Compliance Agent — Narration Script

Target length: **~6–7 minutes** at ~130–140 words/min. Conversational, not
read-aloud-stiff. `[advance]` marks each slide transition. The on-screen
presenter notes (press **N** in the deck) are condensed versions of these.

Twelve slides, twelve sections — one-to-one with the deck.

---

## Slide 1 — Title  (~0:00–0:25)

Hi — thanks for joining. I want to walk you through the SCF Compliance Agent.
In one line: it's an AI agent that performs security-compliance assessment
against the Secure Controls Framework, it runs on Amazon Bedrock AgentCore, and
it's built to be called by *other agents*, not just by people. Let me show you
what it does and how it's put together.

`[advance]`

## Slide 2 — The problem  (~0:25–1:05)

Here's the problem it solves. The Secure Controls Framework is big — over
fifteen hundred controls, cross-referenced to more than two hundred fifty laws,
regulations, and frameworks around the world. Teams work through gap analysis,
framework mapping, and evidence gathering by hand, and then they do it again next
quarter. Security questionnaires ask the same questions over and over. And all
that knowledge lives in spreadsheets and in people's heads — nowhere a system can
actually query it. That's the gap this agent fills.

`[advance]`

## Slide 3 — What it does  (~1:05–1:45)

The agent does eight things. Gap analysis — what controls are you missing against
a target framework. Maturity assessment — scoring against the SCR capability
maturity model, levels zero through five. Framework mapping — translating between
the SCF and hundreds of regulations. Evidence checklists for audits. Compensating
controls when you have a gap you can't close yet. Reusing approved answers to
security questionnaires. Live web research for regulatory updates and CVEs. And
long-term memory, so it remembers your organization between sessions. One agent,
all eight.

`[advance]`

## Slide 4 — Architecture  (~1:45–2:35)

Architecturally, there's a single agent core — the Strands framework running
Claude Sonnet on AgentCore Runtime, with a Bedrock Guardrail applied to every
model call. The important design choice is that it's *grounded in data* rather
than relying on the model's memory. A knowledge base backed by S3 Vectors does
fast semantic discovery. DynamoDB holds the complete control records — all
fifteen hundred — plus the approved questionnaire answers. AgentCore Memory keeps
organizational context. And an MCP gateway gives it live web search. The pattern
is two-step: vector search finds the right control IDs quickly, DynamoDB returns
the full untruncated detail, and the model reasons over that. That keeps answers
accurate instead of hallucinated.

`[advance]`

## Slide 5 — Three ways in  (~2:35–3:15)

There are three front doors, and each has its own authentication model. AWS
principals and command-line scripts invoke the runtime directly with IAM SigV4.
Other agents call it over the open A2A protocol — JSON-RPC through an API
Gateway, authenticated with OAuth or OpenID Connect bearer tokens from either
Amazon Cognito or Microsoft Entra ID. And there's an optional Streamlit web UI
for humans, which is currently switched off to save cost but ready to turn back
on. Same agent behind all three doors — the only difference is who's allowed to
call it.

`[advance]`

## Slide 6 — A2A deep dive  (~3:15–4:00)

Let me zoom in on the agent-to-agent path, because the design there is
deliberate. API Gateway caps any single request at thirty seconds — but a full
gap analysis takes longer than that. So the call is non-blocking. When an agent
sends a message, a bridge Lambda writes a task and returns "submitted" in under a
second. An SQS-triggered worker Lambda then runs the actual agent turn out of
band, with a dead-letter queue to catch failures. The caller just polls until the
task is done. The upshot: long assessments never time out, and a buggy caller
can't drive the model in an infinite retry loop.

`[advance]`

## Slide 7 — Security  (~4:00–4:45)

Because the callers here are machines, the security model is built around
non-human identities. Every model call goes through a Bedrock Guardrail that
filters prompt-injection attempts, personal data, and harmful content. Machine
callers authenticate with OAuth client-credentials, scoped narrowly to just an
"invoke" permission, with sixty-minute tokens so a leaked token has a short
lifespan. Sessions are isolated per caller, so two agents never share context.
And the whole thing is mapped against the OWASP Non-Human Identities Top Ten —
least privilege, short-lived secrets, and no credential reuse.

`[advance]`

## Slide 8 — Cost  (~4:45–5:25)

Cost was engineered on purpose. Originally the project hosted a human web UI —
Fargate, a load balancer, and CloudFront — which ran twenty-four-seven and cost
roughly thirty to forty dollars a month even when nobody used it. Turning that
off is a single Terraform flag. The core agent itself is pay-per-use, essentially
free when it's idle. And since machine callers don't self-limit the way a person
clicking a screen does, we added per-route API throttling and a monthly budget
alarm — so a runaway or compromised caller can't quietly run up the bill.

`[advance]`

## Slide 9 — Data freshness  (~5:25–5:55)

The data keeps itself current. A weekly EventBridge job runs a Lambda that checks
the published SCF version. If a new release is out, it uploads the new data,
re-indexes the knowledge base, reloads DynamoDB, and emails the team. Nobody has
to watch for framework updates — the agent's knowledge stays fresh on its own.

`[advance]`

## Slide 10 — Real output  (~5:55–6:35)

Here's what it produces in practice. Ask it to map a baseline — say GovRAMP or
FedRAMP — and it returns the relevant SCF controls along with their NIST 800-53
references. From exactly that, we built audit-style worksheets: every control
paired with concrete AWS implementation guidance, the official SCF
evidence-request references, and example evidence an assessor would accept. All
of it grounded in the real 2026.2 catalog — nothing invented. We produced a
GovRAMP Core worksheet at eighty-six controls and a FedRAMP Low worksheet at
three hundred eighty-three.

`[advance]`

## Slide 11 — Infrastructure & ops  (~6:35–7:00)

Operationally it's infrastructure-as-code from top to bottom. The entire AWS
footprint is Terraform. Five Lambdas run the A2A bridge and worker, the weekly
updater, the audit logger, and document OCR. Four DynamoDB tables, including a
full year-long audit trail on every change to an approved answer. The guardrail,
the throttling, the budget alarm — all codified and version-controlled.

`[advance]`

## Slide 12 — Close  (~7:00–7:25)

So to sum up: this is a compliance expert that your other agents can call. It's
grounded in real framework data with guardrailed reasoning. It's agent-native —
open protocol, OAuth-secured, and non-blocking. It's cost-aware by design. And it
stays current and fully auditable, all as code. The repo link is on screen.
Thanks for watching.
