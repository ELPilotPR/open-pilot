# Open Pilot

**Open-source, privacy-first AI chat client.** Native, fast, and yours — no backend, no account, no telemetry. Open Pilot talks *directly* from your device to the model you choose: a local model on your network, any OpenAI-compatible cloud, or Anthropic. Everything (chats, settings, keys) stays on your device.

> iOS first (SwiftUI). More platforms — Windows, Android, desktop — are on the roadmap. The repo is structured as a monorepo (`ios/`, …) so each platform can grow independently.

## Features

- **Streaming chat** with any OpenAI-compatible endpoint (local LAN, cloud) or Anthropic, with a live typing cursor.
- **Multiple providers & models** — add your own endpoint + key in Settings; switch per chat. A **model picker** offers capability presets (vision, reasoning) per provider, plus manual entry and model discovery.
- **Rich markdown** — headings, bold/italic, nested lists, blockquotes, tables, and fenced code blocks with on-device syntax highlighting.
- **Visible reasoning** — collapsible "thinking" trace for models that emit it.
- **Web search with inline citations** — grounded answers with tappable source pills.
- **Generative UI cards** — native weather and currency-conversion cards rendered from public, key-free APIs (Open-Meteo, Frankfurter/BCE).
- **Image generation** for providers that support it.
- **Voice** — dictate messages with on-device speech recognition, read replies aloud, and a **live voice mode** for continuous hands-free conversation (listen → reply → listen).
- **Attachments** — photos from library or camera, plus **files** (PDF, documents, code) extracted into the model's context.
- **Canvas** — a side editor for code or text you can revise by hand or ask the model to change, with navigable versions.
- **Edit & resend with versions** — editing a message keeps the original and lets you flip between branches (`< 1/2 >`); **share** a conversation as text; **rename** and search chats (by title or content).
- **Custom instructions** — persistent "about you" and response preferences injected into every chat.
- **Organize** — pin and archive conversations; the sidebar groups by date.
- **Quality-of-life** — smart titles, regenerate, response-length control, tokens/sec + token counts, tap-anywhere to dismiss the keyboard.
- **English / Español** — follows the device language, with a manual override.
- **Appearance** — Automatic / Light / Dark.
- **Local-first storage** via SwiftData; **API keys in the device Keychain**. No server in the middle.
- **Tested** — an XCTest suite covers the version tree, model catalog, custom instructions, file parsing, citations, and Canvas helpers.

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

- [x] iOS: streaming, markdown/tables + syntax highlighting, web citations, GenUI cards, images, voice, attachments
- [x] Reasoning/thoughts display
- [x] Edit & resend with version branches, share/export, rename, conversation search
- [x] i18n (EN/ES), Light/Dark appearance, Keychain-backed keys
- [x] Model picker with capability presets
- [x] Custom instructions, pin/archive, file attachments (PDF/docs/code)
- [x] Canvas (model-assisted editor with versions)
- [x] Live voice mode (hands-free)
- [x] Automated XCTest suite
- [ ] On-device models (MLX / llama.cpp)
- [ ] Windows / Android / desktop clients

## License

[MIT](LICENSE). Contributions welcome.