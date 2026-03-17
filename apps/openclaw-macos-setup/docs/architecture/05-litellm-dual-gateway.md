# LiteLLM Dual Gateway Architecture v1

## 1. Goal

Deploy one LiteLLM gateway in each universe:

- macOS local universe
- GCP Singapore universe

Each gateway is sovereign inside its own universe and serves as:
- model access plane
- routing plane
- fallback plane
- budget control plane
- observability point

LiteLLM is not treated as a mere transport proxy.
It is treated as policy enforcement infrastructure.

---

## 2. Why LiteLLM Exists in This System

The system requires:
- multiple providers
- model fallback
- budget-aware routing
- stable OpenAI-style interface for OpenClaw
- reduced coupling between agent definitions and provider-specific APIs

LiteLLM provides:
- unified OpenAI-format I/O
- retry / fallback logic
- routing / load balancing
- provider / model / tag budgets

Therefore, OpenClaw should primarily talk to the local universe's LiteLLM endpoint rather than directly to all external providers.

---

## 3. Dual-Gateway Principle

Both universes run their own LiteLLM instance.

### macOS LiteLLM
Purpose:
- domestic-first routing
- stable access to China-friendly providers
- optional local embedding access
- low-latency control for local OpenClaw

### GCP LiteLLM
Purpose:
- international-first routing
- stable access to Gemini and other global providers
- online ingress support
- fallback-rich routing for Telegram-facing flows

The two LiteLLM gateways do not depend on each other for critical operation.

---

## 4. Network Philosophy

### macOS universe
Priority order:
1. local services
2. domestic-accessible providers
3. globally reachable providers only when necessary

### GCP universe
Priority order:
1. globally reachable providers
2. multi-provider fallback groups
3. backup compatibility endpoints if needed

This reduces cross-border latency and instability.

---

## 5. OpenClaw Integration Principle

OpenClaw should point to the local LiteLLM gateway using an OpenAI-compatible endpoint where possible.

This gives:
- stable model naming
- easier fallback management
- simpler agent policy design
- easier future provider replacement

OpenClaw supports OpenAI-compatible local or proxied gateways such as LiteLLM.

---

## 6. Model Group Design

The system should define model groups rather than bind agents directly to vendor-specific model IDs.

Recommended abstract groups:

- fast_chat
- balanced_chat
- deep_reasoning
- coding_primary
- coding_backup
- writing_primary
- research_primary
- summarization_economy
- embedding_local
- embedding_remote_backup

These group names become stable internal contracts.

LiteLLM then maps these groups to concrete providers and models.

---

## 7. Environment-Specific Routing

## 7.1 macOS universe routing
Recommended direction:
- domestic-accessible providers as primary
- local embeddings where possible
- expensive international calls only for selected tasks

Suggested priorities:
- fast_chat -> low-cost domestic-friendly model
- balanced_chat -> stronger domestic-friendly model
- deep_reasoning -> best available stable reasoning model reachable from local environment
- coding_primary -> strongest reliable coding-capable model accessible from China network path
- coding_backup -> second reliable coding-capable model
- embedding_local -> Ollama-based local embedding service

## 7.2 GCP universe routing
Recommended direction:
- Gemini and other global providers as primary
- richer fallback chains
- stronger use of online research-capable models where available

Suggested priorities:
- fast_chat -> low-cost global model
- balanced_chat -> mid-cost global model
- deep_reasoning -> strongest reasoning model in active use
- coding_primary -> strongest coding model in active use
- coding_backup -> second provider coding model
- embedding_remote_backup -> only if needed

---

## 8. Budget Policy

Every major model group should eventually have:
- default budget
- burst policy
- downgrade path
- fallback path

Recommended governance:
- fast_chat: generous
- balanced_chat: moderate
- deep_reasoning: controlled
- coding_primary: moderate to high
- research_primary: controlled
- embedding: cheap-first

Budget enforcement belongs in LiteLLM where possible, not scattered across prompts.

---

## 9. Fallback Policy

Fallback should be defined at model-group level.

Examples:
- coding_primary -> coding_backup -> balanced_chat
- deep_reasoning -> balanced_chat
- writing_primary -> balanced_chat -> fast_chat

Fallback criteria should include:
- provider unavailability
- timeout
- hard errors
- quota errors
- unacceptable latency thresholds

---

## 10. Agent Access Policy

Not every agent should access every model group.

Recommended direction:

### Chief
Allowed:
- balanced_chat
- deep_reasoning
- summarization_economy

### Coder
Allowed:
- coding_primary
- coding_backup
- balanced_chat

### Strategist
Allowed:
- deep_reasoning
- research_primary
- balanced_chat

### Steward
Allowed:
- fast_chat
- balanced_chat
- summarization_economy

### Writer
Allowed:
- writing_primary
- balanced_chat
- summarization_economy

### Reader
Allowed:
- research_primary
- balanced_chat
- summarization_economy

### Archivist
Allowed:
- summarization_economy
- balanced_chat

---

## 11. Security and Trust Boundary

LiteLLM does not replace trust-boundary design.

Secrets remain per-universe.
API keys remain per-universe.
Logs remain per-universe unless explicitly exported.
No cross-universe shared credentialing.

OpenClaw is not treated as a hostile multi-tenant system.
The design assumes one trusted operator boundary per universe.

---

## 12. Phase 1 Implementation

Phase 1 goals:
- deploy LiteLLM locally in both universes
- expose one local endpoint per universe
- define abstract model groups
- connect OpenClaw to LiteLLM
- verify fallback works
- verify one budget rule works
- verify one agent-to-model policy path works

No advanced cross-universe routing is required in Phase 1.

---

## 13. Phase 2 Evolution

Phase 2 may add:
- model access restrictions by agent
- better cost tagging
- traffic mirroring / shadow routing
- response logging for evals
- model quality comparisons on fixed test sets

---

## 14. Design Rule

OpenClaw agents should think in terms of capability groups.
LiteLLM should translate capability groups into concrete providers.

This keeps the digital organization stable while provider choices evolve.
