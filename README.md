# Open Pilot

**Open-source, privacy-first AI chat client.** Native, fast, and yours — no backend, no account, no telemetry. Open Pilot talks *directly* from your device to the model you choose: a local model on your network, any OpenAI-compatible cloud, or Anthropic. Everything (chats, settings, keys) stays on your device.

> iOS first (SwiftUI). More platforms — Windows, Android, desktop — are on the roadmap. The repo is structured as a monorepo (`ios/`, …) so each platform can grow independently.

## Features

- **Streaming chat** with any OpenAI-compatible endpoint (local LAN, cloud) or Anthropic, with a live typing cursor.
- **Multiple providers & models** — add your own endpoint + key in Settings; switch per chat. A **model picker** offers capability presets (vision, reasoning) per provider, plus manual entry and model discovery.
- **Rich markdown** — headings, bold/italic, nested lists, blockquotes, tables, and fenced code blocks with on-device syntax highlighting.
- **Math (LaTeX)** — inline `$…$` and display `$$…$$` formulas (fractions, roots, integrals, Greek) typeset natively on-device — no webview, no server.
- **Visible reasoning** — collapsible "thinking" trace for models that emit it.
- **Web search with inline citations** — grounded answers with tappable source pills.
- **Generative UI cards** — native weather and currency-conversion cards rendered from public, key-free APIs (Open-Meteo, Frankfurter/BCE).
- **Image generation** for providers that support it.
- **Voice** — dictate messages with on-device speech recognition, read replies aloud, and a **live voice mode** for continuous hands-free conversation (listen → reply → listen).
- **Attachments** — photos from library or camera, plus **files** (PDF, documents, code) extracted into the model's context.
- **Canvas** — a side editor for code or text you can revise by hand or ask the model to change, with navigable versions. A **Code / Preview** toggle renders HTML & JavaScript in an on-device WebView and draws **Mermaid** diagrams fully offline (bundled mermaid.js).
- **Edit & resend with versions** — editing a message keeps the original and lets you flip between branches (`< 1/2 >`); **rename** and search chats (by title or content).
- **Export & import** — export any chat as **Markdown**, **PDF**, or a faithful **JSON** backup (full version tree, reasoning, attachments); import a JSON backup to restore it. Everything stays on-device.
- **Custom instructions** — persistent "about you" and response preferences injected into every chat.
- **Projects & automatic memory** — group chats into projects with their own instructions; the app remembers facts about you across chats (editable in Settings).
- **Prompt library & slash commands** — save reusable prompts and insert them by typing `/` in the composer (filtered live as you type). Manage them in Settings or the + menu.
- **Code interpreter** — run JavaScript in an on-device sandbox (no network or file access) straight from a code block, and render `csv` blocks as bar charts. Nothing leaves the device.
- **Context management** — a live token estimate above the composer, plus automatic compaction that condenses older messages into a summary when a chat grows past your chosen budget (recent messages stay verbatim).
- **Model comparison** — send one prompt to several models at once and read their streaming answers side by side, each column re-pointable at any configured provider/model.
- **Temporary chat** — a private mode that uses no memory and is never saved to history.
- **Organize** — pin and archive conversations; the sidebar groups by date.
- **Quality-of-life** — smart titles, regenerate, 👍/👎 feedback on replies, search within a conversation, response-length control, tokens/sec + token counts, tap-anywhere to dismiss the keyboard.
- **English / Español** — follows the device language, with a manual override.
- **Appearance** — Automatic / Light / Dark.
- **Local-first storage** via SwiftData; **API keys in the device Keychain**. No server in the middle.
- **Tested** — an XCTest suite covers the version tree, model catalog, custom instructions, file parsing, citations, Canvas helpers, projects, memory, feedback, temporary chat, in-conversation search, LaTeX parsing, export/import round-trips, prompt slash matching, JavaScript sandbox execution, CSV parsing, context compaction, Canvas preview document building, and model-comparison column logic.

## Privacy

Open Pilot has **no backend**. Requests go straight from your device to the provider you configure. Conversations are stored locally on the device (SwiftData) and API keys are kept in the device **Keychain** — never in plaintext, never sent anywhere else. The app permits local-network HTTP so you can reach a self-hosted model (e.g. `http://192.168.x.x:8080/v1`).

## Build (iOS)

Requirements: macOS with **Xcode 16+** (iOS 18 SDK) and **[XcodeGen](https://github.com/yonaskolb/XcodeGen)**.

```bash
brew install xcodegen          # if you don't have it
cd ios
xcodegen generate              # creates OpenPilot.xcodeproj from project.yml
open OpenPilot.xcodeproj
```

Then select your signing team and run on a simulator or device. On first launch, open **Settings → Providers**, add an endpoint (e.g. your local model or a cloud API) and paste your key. That's it.

> The Xcode project is generated from `ios/project.yml`; it is intentionally not committed.

## Repository layout

```
ios/            Native iOS app (SwiftUI + SwiftData)
  project.yml   XcodeGen spec (source of truth for the Xcode project)
  OpenPilot/    App source
```

## Roadmap

- [x] iOS: streaming, markdown/tables + syntax highlighting, LaTeX math, web citations, GenUI cards, images, voice, attachments
- [x] Reasoning/thoughts display
- [x] Edit & resend with version branches, export (Markdown/PDF/JSON) & import, rename, conversation search
- [x] i18n (EN/ES), Light/Dark appearance, Keychain-backed keys
- [x] Model picker with capability presets
- [x] Custom instructions, pin/archive, file attachments (PDF/docs/code)
- [x] Canvas (model-assisted editor with versions)
- [x] Canvas live preview (HTML/JS WebView) + offline Mermaid diagrams
- [x] Side-by-side multi-model comparison
- [x] Live voice mode (hands-free)
- [x] Automated XCTest suite
- [x] Projects + automatic memory, 👍/👎 feedback, temporary chat, in-conversation search
- [x] Prompt library with `/` slash commands
- [x] On-device code interpreter (sandboxed JavaScript) + CSV → charts
- [x] Context token indicator + automatic compaction
- [ ] On-device models (MLX / llama.cpp)
- [ ] Windows / Android / desktop clients

## License

[MIT](LICENSE). Contributions welcome.