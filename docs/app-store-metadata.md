# App Store Connect / TestFlight metadata — Open Pilot

Ready-to-paste fields. English (primary locale). No reference to any reverse-engineered
product. Bundle id: `com.openpilot.app` · Team: `X4F3CGCVYH` · Version 0.1.0 (build 1).

## App information
- **Name:** Open Pilot
  - If rejected for name collision (e.g. comma.ai "openpilot"), fall back to
    "Open Pilot AI" or "OpenPilot Chat". The bundle id does not change.
- **Subtitle:** Private AI chat, your models
- **Bundle ID:** com.openpilot.app
- **SKU:** openpilot-ios-001
- **Primary language:** English (U.S.)
- **Privacy Policy URL:** https://elpilotpr.github.io/open-pilot/privacy-policy.html

## Category
- Primary: Productivity
- Secondary: Utilities

## Age rating
- 4+ (no objectionable content; user-generated prompts depend on the connected model).
  Answer the questionnaire "None" for all content descriptors.

## Description (TestFlight "What to Test" / beta description)
Open Pilot is a private, open-source AI chat client. There is no backend and no account:
your conversations, settings, and API keys stay on your iPhone (keys in the Keychain).
Connect any OpenAI-compatible or Anthropic model — a server on your own network, or a
cloud API — and chat directly from your device.

Features:
- Streaming replies with live reasoning, tokens/sec, and token counts.
- Web browse with inline citations.
- Native weather and currency cards.
- Image understanding and generation (provider-dependent).
- Attach files and photos; PDF and text extraction.
- Voice dictation, read-aloud, and a live voice mode.
- Edit messages with version history; regenerate; rename, share, pin, archive.
- Projects with their own instructions; automatic, editable memory.
- Custom instructions, response style, light/dark appearance, EN/ES.
- Canvas for code and documents with versioning.

This is a beta. Please report issues at github.com/ELPilotPR/open-pilot.

## Keywords (100 chars max)
ai,chat,llm,assistant,private,open source,offline,models,voice,canvas

## Promotional text (170 chars max)
Private AI chat with no backend. Bring your own model — local or cloud — and keep every
conversation and key on your device.

## Beta App Review notes
- No login required. On first launch a local-network demo provider is seeded; the app is
  fully usable by adding a provider in Settings (base URL + model + optional API key).
- The app uses arbitrary network loads (ATS) because it must reach user-configured
  servers on local networks over HTTP (e.g. http://192.168.x.x:8080/v1). All cloud
  providers use HTTPS.
- Microphone / Speech: voice dictation (on-device). Camera / Photos: attach images.
- Encryption: ITSAppUsesNonExemptEncryption = false (only standard Apple OS HTTPS/Keychain).
- No data collected; see privacy policy URL.

## Export compliance
- ITSAppUsesNonExemptEncryption = NO (exempt: standard OS encryption only).

## Screenshots (capture from simulator/device)
- 6.7" / 6.9" iPhone: chat streaming, browse citations, weather card, projects sidebar,
  memory screen, live voice overlay. (Generate with the -demo* launch args.)
