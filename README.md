# Open Pilot

**Open-source, privacy-first AI chat client.** Native, fast, and yours — no backend, no account, no telemetry. Open Pilot talks *directly* from your device to the model you choose: a local model on your network, any OpenAI-compatible cloud, or Anthropic. Everything (chats, settings, keys) stays on your device.

> iOS first (SwiftUI). More platforms — Windows, Android, desktop — are on the roadmap. The repo is structured as a monorepo (`ios/`, …) so each platform can grow independently.

## Features

- **Streaming chat** with any OpenAI-compatible endpoint (local LAN, cloud) or Anthropic.
- **Multiple providers & models** — add your own endpoint + key in Settings; switch per chat.
- **Rich markdown** — headings, bold/italic, lists, code blocks, and tables.
- **Web search with inline citations** — grounded answers with tappable source pills.
- **Generative UI cards** — native weather and currency-conversion cards rendered from public, key-free APIs (Open-Meteo, Frankfurter/BCE).
- **Image generation** for providers that support it.
- **Voice** — dictate messages with on-device speech recognition.
- **Attachments** — photos from library or camera.
- **Quality-of-life** — smart conversation titles, regenerate, response-length control, tokens/sec + token counts, tap-anywhere to dismiss the keyboard.
- **Local-first storage** via SwiftData. No server in the middle.

## Privacy

Open Pilot has **no backend**. Requests go straight from your device to the provider you configure. Your API keys and conversations are stored locally on the device and are never sent anywhere else. The app permits local-network HTTP so you can reach a self-hosted model (e.g. `http://192.168.x.x:8080/v1`).

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

- [x] iOS: streaming, markdown/tables, web citations, GenUI cards, images, voice, attachments
- [ ] Reasoning/thoughts display
- [ ] Model picker with capability presets
- [ ] Windows / Android / desktop clients

## License

[MIT](LICENSE). Contributions welcome.