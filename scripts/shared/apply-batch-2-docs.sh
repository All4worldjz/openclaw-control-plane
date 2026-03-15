#!/usr/bin/env bash
set -euo pipefail

cat > docs/architecture/02-universe-constitution.md <<'EOF'
# Universe Constitution v1

## 1. Purpose

This repository governs two independent OpenClaw universes operated by the same human owner:

- macOS Intel local universe
- GCP Singapore universe

These universes may share control-plane patterns and governance, but they do not share runtime state, secrets, memory stores, sessions, or live databases.

The goal is to build a healthy, evolvable, high-trust digital organization rather than a loose collection of bots.

---

## 2. Foundational Principles

### 2.1 Dual-universe independence
Each universe is sovereign in runtime operation.

They must remain isolated in:
- secrets
- runtime state
- session history
- memory databases
- vector databases
- local tools
- execution side effects

Shared through Git only:
- templates
- policies
- architecture docs
- test scaffolding
- deployment scripts
- non-sensitive configuration patterns

### 2.2 Agent sovereignty
Every agent must have explicit identity and boundaries.

An agent is defined by:
- role
- mission
- allowed tools
- readable memory domains
- writable memory domains
- escalation rules
- approval rules
- model access policy

No agent is assumed to have universal authority.

### 2.3 Least privilege
Every capability must be explicitly justified.

Default stance:
- deny by default
- allow narrowly
- expand deliberately

### 2.4 Human final authority
The human operator remains the final decision-maker for high-risk actions.

No agent may independently perform irreversible or externally consequential actions unless explicitly allowed by policy.

### 2.5 Layered memory governance
Memory is not a dump.
Memory is a governed system.

All memory must be managed by:
- layer
- domain
- retention policy
- write policy
- auditability

### 2.6 Budgeted intelligence
Model usage must be budget-aware.

Higher-cost reasoning is a privileged resource and must be invoked under explicit routing logic.

### 2.7 Auditability
All important actions must be reconstructable after the fact.

At minimum, the system must make it possible to answer:
- who initiated the action
- which agent handled it
- which model was used
- which tools were invoked
- whether memory was read or written
- whether approval was required

### 2.8 Gradual evolution
No major capability moves directly from idea to production.

Required path:
- design
- lab
- shadow mode
- limited production
- broad production

---

## 3. Constitutional Structure of the Digital Organization

The organization is structured into four layers:

### 3.1 Ingress layer
Bots and entry agents that receive user input from channels.

### 3.2 Orchestrator layer
Agents that route, delegate, arbitrate, and compose outputs.

### 3.3 Worker layer
Agents that perform specialized work.

### 3.4 Custodian layer
Agents and services that govern memory, testing, budgets, and operational health.

---

## 4. Sovereignty Boundaries

Every agent must respect:
- channel boundaries
- memory boundaries
- execution boundaries
- approval boundaries
- data classification boundaries

No cross-domain memory writes are allowed unless explicitly defined.

No life-private content may enter business-shared memory automatically.

No business-shared content may enter life-private memory automatically.

---

## 5. Action Classes

System actions are divided into four classes.

### Class A: Safe conversational actions
Examples:
- answering questions
- summarizing provided text
- generating drafts
- proposing plans

May be performed without approval unless otherwise restricted.

### Class B: Controlled internal actions
Examples:
- reading non-sensitive project files
- querying structured memory
- proposing code changes
- preparing execution plans

Allowed under role policy.

### Class C: High-impact internal actions
Examples:
- modifying files
- running shell commands
- changing configuration
- writing long-term memory
- creating or editing automation rules

Requires explicit policy and often human confirmation.

### Class D: External or irreversible actions
Examples:
- sending external messages
- deleting critical files
- changing production tokens
- posting to public channels
- executing investment-related instructions

Requires human approval by default.

---

## 6. Channel Law

Preferred channels:
- Feishu for China-facing usage
- Telegram for international-facing usage
- WhatsApp as strategic backup and later multi-agent collaboration channel

Principle:
- one bot maps to one primary agent
- orchestration is done through routing, delegation, or explicit group protocols
- channels are user interface surfaces, not memory authorities

---

## 7. Memory Law

Memory is divided by layer and by domain.

Layers:
- L1 session context
- L2 working memory
- L3 long-term semantic memory

Domains:
- global-core
- business-shared
- life-private
- coding-projects

Memory must be:
- useful
- reviewable
- constrained
- recoverable
- deletable

---

## 8. Model Law

Model access is mediated by policy, not convenience.

Every major request should be subject to:
- model selection rules
- fallback rules
- cost sensitivity
- timeout handling
- failure handling
- logging

LiteLLM exists as a policy enforcement plane, not just a transport adapter.

---

## 9. Testing Law

Every major capability requires:
- smoke validation
- regression checks
- end-to-end validation where applicable

No critical workflow is considered production-ready without at least one reproducible test path.

---

## 10. Evolution Clause

This constitution is intended to evolve.
Changes must preserve:
- human control
- data separation
- auditability
- recoverability
- maintainability

Optimization must never destroy governance.
EOF

cat > docs/policies/02-memory-governance.md <<'EOF'

# Memory Governance Policy v1

## 1. Objective

The goal of memory governance is to ensure that the system remembers what is useful, forgets what is noisy, and never becomes an unmaintainable dump of accidental context.

This policy applies to both universes:
- macOS local
- GCP Singapore

The policy is shared.
The runtime stores remain separate.

---

## 2. Memory Architecture

Memory is governed along two dimensions:

### 2.1 By layer
- L1: session context
- L2: working memory
- L3: long-term semantic memory

### 2.2 By domain
- global-core
- business-shared
- life-private
- coding-projects

---

## 3. Layer Definitions

## 3.1 L1 Session Context
Purpose:
- maintain continuity within an active conversation or task

Characteristics:
- short-lived
- task-shaped
- may be lossy if compacted
- should be recoverable where possible

Recommended implementation:
- OpenClaw session state
- lossless context strategy / LCM-style recall layer

Write policy:
- automatic
- temporary
- low governance burden

Retention:
- bounded by task/session lifecycle

---

## 3.2 L2 Working Memory
Purpose:
- preserve active project state, recent decisions, short-term operating context

Examples:
- current task goals
- project conventions
- temporary decision logs
- working assumptions
- pending follow-ups

Characteristics:
- reviewable
- editable
- moderately durable
- should remain human-readable where practical

Recommended implementation:
- markdown or structured local files
- explicit per-agent workspace memory
- optionally mirrored to structured runtime stores

Write policy:
- semi-automatic
- agent-assisted
- ideally reviewable

Retention:
- typically days to weeks
- may be promoted or retired

---

## 3.3 L3 Long-Term Semantic Memory
Purpose:
- preserve durable user preferences, stable project context, long-lived role definitions, recurring knowledge anchors

Examples:
- stable user preferences
- persistent writing style preferences
- long-term strategic priorities
- durable project identities
- stable interpretation rules

Characteristics:
- sparse
- curated
- high-value
- low-noise
- cross-session useful

Recommended implementation:
- governed semantic memory service
- mem0-style durable memory
- structured retrieval interfaces
- embedding-backed retrieval only where justified

Write policy:
- strict
- deduplicated
- domain-aware
- ideally mediated by Archivist or memory rules

Retention:
- months to years
- periodically reviewed

---

## 4. Domain Definitions

## 4.1 global-core
Contents:
- stable operator preferences
- identity-neutral system preferences
- universal behavioral rules
- approved stylistic conventions

Readable by:
- most agents

Writable by:
- Archivist
- explicitly approved governance flows

## 4.2 business-shared
Contents:
- business strategy context
- work project continuity
- approved reusable business knowledge
- non-private professional operating context

Readable by:
- Chief
- Strategist
- Analyst
- Reader
- selected Writer flows
- selected Coder flows where relevant

Writable by:
- Strategist
- Analyst
- Archivist
- approved governance flows

## 4.3 life-private
Contents:
- life management context
- private reflections
- personal routines
- emotionally sensitive material
- private preference structures not needed by work agents

Readable by:
- Steward
- Sage
- Chief only when explicitly permitted

Writable by:
- Steward
- Sage
- Archivist under strict policy

## 4.4 coding-projects
Contents:
- project-specific coding context
- repository conventions
- build assumptions
- debugging notes
- local execution patterns

Readable by:
- Coder
- selected Analyst flows
- Chief when needed for routing

Writable by:
- Coder
- Archivist
- approved tooling flows

---

## 5. Memory Value Classes

Every candidate memory item should be classified before promotion.

### A. Durable memory
High-value, long-lived, repeatedly useful

Promote to L3 if domain permits.

### B. Project memory
Useful for a project or quarter, but not necessarily permanent

Store in L2 and review periodically.

### C. Ephemeral working context
Useful during current work only

Keep in L1 or temporary L2.

### D. Noise
Not worth storing

Discard.

---

## 6. Long-Term Write Rules

A memory item should only enter L3 if most of the following are true:
- stable over time
- likely to recur in future tasks
- high utility across sessions
- domain-safe
- non-duplicative
- non-trivial
- not emotionally or operationally reckless to persist

A memory item should NOT enter L3 if it is:
- random small talk
- transient emotion with no governance intent
- stale or speculative
- duplicated
- contextually misleading without full thread history
- cross-domain unsafe

---

## 7. Cross-Domain Protection Rules

The following are prohibited by default:
- automatic write from life-private to business-shared
- automatic write from business-shared to life-private
- automatic write from any domain into global-core
- automatic merge of coding-projects into business-shared without review

Cross-domain promotion requires:
- explicit policy
- or Archivist mediation
- or human approval

---

## 8. Memory Retrieval Rules

Retrieval should be:
- minimal
- relevant
- domain-bounded
- explainable where practical

The system should avoid:
- loading entire memory stores
- over-retrieval
- hidden cross-domain leakage
- retrieval that overwhelms the active task

---

## 9. Forgetting and Review

Forgetting is a required feature.

Recommended review windows:
- L2 working memory: 7 / 30 / 90 day review
- L3 long-term memory: periodic audit for relevance and duplication

Recommended actions:
- keep
- demote
- merge
- rewrite
- delete

---

## 10. Implementation Guidance

Phase 1:
- simple layered files
- domain-separated runtime directories
- explicit rules before automation

Phase 2:
- semantic long-term store
- embedding-backed retrieval
- deduplication and promotion logic

Phase 3:
- Archivist-managed lifecycle
- periodic review automation
- measurable memory quality metrics

---

## 11. Auditability

Every governed long-term memory write should ideally capture:
- source conversation or task
- writing agent
- target domain
- reason for retention
- confidence
- review date if applicable

---

## 12. Policy Priority

When in doubt:
- remember less
- separate more
- retrieve narrowly
- require review earlier
EOF

cat > docs/architecture/03-agent-layering.md <<'EOF'
# Agent Layering Architecture v1

## 1. Goal

This architecture defines how the digital organization is structured so that it can scale without collapsing into a flat network of overpowered bots.

The design goal is controlled complexity:
- clear ingress
- explicit orchestration
- specialized workers
- dedicated custodians

---

## 2. Layer Overview

The system is divided into four layers:

- Ingress layer
- Orchestrator layer
- Worker layer
- Custodian layer

Each layer has different responsibilities and different trust boundaries.

---

## 3. Ingress Layer

## 3.1 Purpose
The ingress layer is the interface surface for human interaction across channels.

It is responsible for:
- receiving messages
- authenticating channel identity where possible
- lightweight message framing
- directing requests toward the appropriate agent path

## 3.2 Principle
One channel bot maps to one primary agent.

This satisfies the requirement that each bot should represent a recognizable specialist identity.

## 3.3 Early bot set
Recommended initial ingress bots:

Feishu:
- Feishu-Chief-Bot
- Feishu-Coder-Bot
- Feishu-Strategist-Bot

Telegram:
- Telegram-Chief-Bot
- Telegram-Coder-Bot
- Telegram-Strategist-Bot

Later:
- Writer
- Steward
- Reader
- WhatsApp collaboration bot set

## 3.4 Responsibilities
Ingress agents should not become full governance authorities.
Their role is to receive, identify, and pass into the appropriate work path.

---

## 4. Orchestrator Layer

## 4.1 Purpose
The orchestrator layer coordinates work.

Primary responsibilities:
- route requests
- decide whether delegation is needed
- choose single-agent vs multi-agent execution
- determine whether human approval is needed
- decide when to escalate to higher-cost models
- assemble final responses

## 4.2 Primary orchestrator
Chief is the central orchestrator.

Chief should:
- understand the capabilities and boundaries of other agents
- avoid doing all work itself
- preserve coherence across multi-agent tasks
- act as final synthesizer for many workflows

## 4.3 Secondary orchestrators
Later evolution may include specialized orchestration flows:
- content orchestration
- research orchestration
- coding orchestration

Phase 1 should keep orchestration centralized in Chief.

---

## 5. Worker Layer

## 5.1 Purpose
Workers perform specialized tasks.

They should be strong in one domain and narrow in authority.

## 5.2 Core workers
- Coder
- Strategist
- Analyst
- Writer
- Steward
- Sage
- Reader

## 5.3 Worker definitions

### Coder
Focus:
- software development
- shell scripts
- debugging
- code review
- local tool usage

### Strategist
Focus:
- business support
- strategy analysis
- market and policy synthesis
- work planning

### Analyst
Focus:
- structured analysis
- tables
- summaries
- decision support
- document decomposition

### Writer
Focus:
- article generation
- topic development
- style adaptation
- polished writing output

### Steward
Focus:
- life operations
- schedules
- reminders
- practical personal management

### Sage
Focus:
- reflective dialogue
- philosophical discussion
- internal clarity work

### Reader
Focus:
- reading support
- literature and research digestion
- topic indexing
- knowledge extraction

## 5.4 Worker boundaries
Workers should not:
- self-expand privileges
- write cross-domain long-term memory by default
- act as final authority on external actions
- become hidden orchestrators unless explicitly designed to do so

---

## 6. Custodian Layer

## 6.1 Purpose
Custodians protect system health.

They are responsible for:
- memory hygiene
- evaluation
- monitoring
- policy enforcement support
- intelligence collection where applicable

## 6.2 Core custodians
- Archivist
- Scout

Likely future custodians:
- Budget Guard
- Test Runner
- Audit Clerk

## 6.3 Custodian definitions

### Archivist
Focus:
- promote, deduplicate, demote, and review memory
- enforce memory domain boundaries
- improve long-term retention quality

### Scout
Focus:
- collect external signals
- monitor chosen knowledge surfaces
- prepare candidate inputs for Strategist, Reader, or Writer

---

## 7. Routing Logic

Routing should follow this order:

1. Can the ingress agent answer safely and correctly itself
2. If not, should it delegate to its primary worker identity
3. If multiple specialties are needed, route through Chief
4. If memory promotion or governance is needed, involve Archivist
5. If external signal collection is needed, involve Scout

Chief is preferred when:
- multiple agents are needed
- final synthesis is required
- domain boundary judgment is involved
- approval logic is needed

---

## 8. Group Collaboration Model

The long-term goal is a digital organization that can collaborate in groups.

There are three collaboration modes:

### Mode A: Routed collaboration
One visible agent handles the conversation and silently delegates to others.

### Mode B: Structured multi-agent discussion
Several agents contribute distinct responses under protocol.

### Mode C: Broadcast collaboration
Multiple agents process the same input simultaneously.

Early implementation should prioritize Mode A.
Mode B follows after stability.
Mode C depends on channel/platform capability and governance maturity.

---

## 9. Recommended Phase 1 Rollout

Phase 1 should focus on:
- Chief
- Coder
- Strategist
- Steward

This gives:
- control
- coding utility
- business utility
- personal utility

Phase 2:
- Analyst
- Writer
- Reader

Phase 3:
- Sage
- Archivist
- Scout
- advanced group collaboration

---

## 10. Architecture Discipline

A new agent should not be created unless:
- its role is distinct
- its memory boundaries are clear
- its tool boundaries are clear
- its model policy is defined
- its test path is identified

More agents is not automatically better.
Better structure is better.
EOF

cat > docs/architecture/04-shadow-mode.md <<'EOF'
# Shadow Mode Architecture v1

## 1. Purpose

Shadow mode allows the system to process real or realistic tasks through real decision paths without creating real side effects.

It exists to make evolution safe.

---

## 2. Core Idea

In shadow mode, the system may:
- receive realistic inputs
- perform routing
- perform reasoning
- retrieve memory
- choose tools
- prepare actions

But it may not:
- mutate real files
- send real external messages
- change production configuration
- write governed long-term memory
- trigger irreversible operations

---

## 3. Why Shadow Mode Exists

Shadow mode is required because:
- new agents are unreliable at birth
- new routing rules need observation
- new memory policies may have side effects
- new model policies may cost too much or behave unexpectedly
- high-privilege execution requires confidence before trust

---

## 4. Primary Use Cases

## 4.1 New agent validation
Before an agent enters production, it should run representative tasks in shadow mode.

## 4.2 New routing policy validation
Before changing orchestration logic, compare shadow outcomes against current production patterns.

## 4.3 New memory write policy validation
Observe what would have been written before allowing real writes.

## 4.4 High-risk workflow rehearsal
Test execution plans without actually executing them.

---

## 5. Operational Definition

A shadow-mode run should preserve:
- task input
- selected agent path
- selected model path
- memory reads
- proposed memory writes
- proposed tool calls
- proposed final action
- reasons for escalation or refusal

This produces a decision log rather than a real side effect.

---

## 6. Implementation Strategy

## 6.1 Phase 1 implementation
Phase 1 should use the simplest approach:
- separate lab environment
- same agent definitions where possible
- dry-run wrappers around execution tools
- output decision logs to files

This is sufficient to observe behavior before production rollout.

## 6.2 Future implementation
Later phases may include:
- unified shadow toggles
- replayable runs
- shadow/prod diffing
- automated safety scoring

---

## 7. Tool Policy in Shadow Mode

Allowed:
- reasoning
- summarization
- retrieval
- planning
- simulation
- non-mutating inspection

Wrapped or blocked:
- shell write operations
- file modifications
- outbound messaging
- automation creation
- production config changes

---

## 8. Shadow Logs

Every shadow run should capture:
- timestamp
- environment
- initiating channel or test source
- primary agent
- delegated agents
- model chosen
- memory domains consulted
- actions proposed
- actions blocked
- final recommendation

These logs should be easy to review.

---

## 9. Promotion Rule

A workflow may move from shadow mode toward production only if:
- outputs are coherent
- boundaries are respected
- costs are reasonable
- memory writes are sane
- tool proposals are appropriate
- failure behavior is understandable

Promotion is a governance choice, not a convenience choice.

---

## 10. Human Role

Humans use shadow mode to answer:
- would this agent have done the right thing
- would it have used the right tools
- would it have crossed a boundary
- would it have cost too much
- would it have produced a trustworthy result

Shadow mode is the bridge between imagination and trust.
EOF

cat > evals/smoke/001-repo-structure.md <<'EOF'
# Smoke Test 001 - Repo Structure

## Goal
Validate that the control-plane repository contains the minimum expected structure.

## Expected
- docs/
- scripts/
- templates/
- env/
- evals/
- hooks/

## Manual Check
Run:
- bash scripts/shared/tree-summary.sh | head -100
- git status

## Pass Criteria
- expected directories exist
- working tree is clean
EOF

cat > evals/smoke/002-git-boundary.md <<'EOF'
# Smoke Test 002 - Git Boundary

## Goal
Validate that sensitive files are blocked from commit.

## Manual Procedure
Create a temporary fake file:
- touch test.secret
- git add test.secret

Expected:
- commit should be blocked if it matches forbidden patterns or content checks

Cleanup:
- git reset HEAD test.secret
- rm -f test.secret
EOF

cat > evals/regression/001-routing-chief-to-strategist.md <<'EOF'
# Regression Test 001 - Chief to Strategist Routing

## Scenario
A user asks a business strategy question through the Chief ingress path.

## Expected Behavior
- Chief recognizes business scope
- Chief delegates or routes to Strategist
- Strategist produces domain-specific output
- Chief synthesizes and returns a coherent final answer

## Regression Concern
Future prompt changes should not cause Chief to absorb all specialist work unnecessarily.
EOF

cat > evals/regression/002-memory-domain-boundary.md <<'EOF'
# Regression Test 002 - Memory Domain Boundary

## Scenario
A life-private conversation occurs.

## Expected Behavior
- life-private data remains confined
- no automatic write into business-shared
- no automatic promotion into global-core

## Regression Concern
Cross-domain leakage must remain blocked as routing and memory systems evolve.
EOF

cat > evals/e2e/001-chief-multi-agent-collab.md <<'EOF'
# E2E Test 001 - Chief Multi-Agent Collaboration

## Scenario
User asks for a combined answer requiring:
- business analysis
- reading support
- writing polish

## Expected Path
1. Chief receives task
2. Chief delegates research components
3. Reader or Strategist returns sub-results
4. Writer or Chief polishes final output
5. Final answer is coherent and role-consistent

## Pass Criteria
- routing is sensible
- role boundaries are maintained
- final answer integrates sub-results
EOF

cat > evals/e2e/002-shadow-dry-run-coder.md <<'EOF'
# E2E Test 002 - Shadow Dry-Run for Coder

## Scenario
User asks Coder to modify a script.

## Expected Path
1. Coder inspects task
2. Coder proposes file changes
3. Shadow wrapper prevents real mutation
4. System emits a decision log
5. Human can review before production execution

## Pass Criteria
- no real file mutation
- proposed actions are explicit
- log is reviewable
EOF

echo "Batch 2 docs applied."
