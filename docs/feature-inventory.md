# Feature inventory — iPhone-first triage

Open Pilot is a **native iOS chat client** (SwiftUI, no backend). The goal is to
match the leading commercial chat app's UX and beat it on *transparency and cool
factor* — live speed, context cost, on-device models — while staying 100%
client-side.

Two upstream sources were reviewed for ideas:

- **DeepSeek `chat-demo`** — a web chat UI (TypeScript). Useful as a *UX* reference.
- **DeepSeek `deepseek-harness`** — a desktop **coding-agent framework** for
  PC/Mac (shell, filesystem, sandboxes, LSP, MCP, sub-agents, browsers). Most of
  it is infrastructure that does **not** belong on a phone chat client.

This document filters both through one question: *does this make a better iPhone
chat app, client-side?* Tiers below are recommendations, not commitments.

Legend: ✅ already in Open Pilot · 🔜 high value, build next · ➕ nice-to-have · 🚫 not applicable.

---

## Tier 1 — high value (the "better & cooler" core)

| Feature | Status | Why it matters on iPhone |
|---|---|---|
| Live tokens/sec while generating | ✅ | Transparency + cool factor; the headline differentiator. |
| Per-chat context gauge (used / model window, %) | ✅ | Shows how much context a chat costs; color tiers warn before overflow. |
| Final tok/s + ↑in ↓out per message | ✅ | Honest per-answer cost. |
| Web fetch → readable Markdown (article/main, size cap) | ✅ | Prefers article/main, strips nav/scripts, caps length; pure client-side. |
| Tap a citation → preview card | ✅ | Fast source verification without leaving the chat. |
| Live voice spectrum while recording | ✅ | Feels alive; AVAudioRecorder metering drives a bar spectrum. |
| Throttled Markdown render during streaming | ✅ | Smooth scrolling on phone CPUs; debounced ~8 fps re-parse. |

## Tier 2 — nice-to-have

| Feature | Status | Notes |
|---|---|---|
| Per-conversation drafts | ✅ | Resume half-typed messages; UserDefaults keyed by chat id. |
| Reply / quote threading | ✅ | Quote a prior message into the composer. |
| "Continue" a truncated answer | ✅ | One-tap continuation when output hits the cap. |
| Compact context now (with savings report) | ✅ | Manual fold of older turns; reports tokens saved before sending. |
| Turn outline / jump-to-message | ✅ | Menu → Outline lists user turns and scrolls to the chosen message. |
| Welcome / onboarding cards | ✅ | First-run paged cards, re-viewable in Settings (no prompt-suggestion chips). |
| Personas / response-style registry | ✅ | Named presets prepended to the system prompt; built-in + custom, in Settings. |
| Office document parsing (.docx/.xlsx) | ✅ | Client-side ZIP + Compression; docx paragraphs, xlsx shared strings. |
| Import chats from other apps | ✅ | Import chat JSON in the conversation list; export MD/JSON/PDF. |

## Tier 3 — marginal for a phone chat client

`tool-todo`, `plan-mode`, `schedule`, action cards, chain-of-thought translation.
These lean toward agent workflows; revisit only if Open Pilot grows task features.

## 🚫 Not applicable (desktop agent infrastructure)

The harness is a coding-agent framework for PC/Mac. These packages solve problems
a phone chat client does not have, or that require a desktop/server:

```
shell · fs · ssh · sandbox · subprocess · terminal · lsp · mcp · subagent · team
browser-use · computer-use · host/webserver · api/* · jobs · workspace · guard
telemetry-server · acp · sdk/server · webhook · forge/github · worktree · liveshare
```

Also out of scope by decision: any **hosted backend** (the iPhone talks to models
directly), the Safari extension, and Face ID gating.

---

## Privacy note

Source favicons are fetched from a third-party favicon service when the citations
panel is shown. This is disclosed in `privacy-policy.html`; no chat content leaves
the device except to the model provider the user configures.