# Ember

> *A patent-pending conversational UI framework for scalable personalization — across mobile, SMS, voice, spatial, and AiOT.*

---

## What Ember is

Ember is two things built on the same foundation.

**Ember Framework** — an open-source infrastructure layer for building AI-powered conversational experiences that feel genuinely personal. Context is built through conversation, stored at the edge, and persists across every surface the user interacts on. No central data store. No user profiles. No forms.

**Ember Application** — the reference implementation. A personal relationship agent that uses the framework to help people stay aligned with the people who matter most to them. Available on iOS. SMS surface in development.

The framework is licensable. The application is the proof it works.

---

## The core insight

Every AI personalization system today works the same way: collect data about users centrally, build a model, serve personalized responses from that model.

Ember inverts this.

Context is built **through conversation itself** — not data entry. It lives **at the edge** — on the user's device, not a server. It is **portable across surfaces** — the same context that informs a mobile conversation also informs an SMS reply, a voice interaction, a spatial overlay.

This is the patent-pending mechanic: **a personalization architecture that scales without central data storage**, where individual context models are constructed, maintained, and transported through the conversational interface itself.

The result: AI interactions that feel personal from the first exchange, that get more specific over time, and that work identically whether the user is typing on a phone, sending an SMS, speaking to a voice agent, or looking through a spatial display.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    EMBER FRAMEWORK                       │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Contextual │  │ Conversation │  │   Continuity  │  │
│  │   Memory    │  │    Engine    │  │    Layer      │  │
│  │  (on-device)│  │ (Claude API) │  │ (cross-surface│  │
│  └─────────────┘  └──────────────┘  └───────────────┘  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Surface Adapter Layer               │   │
│  │  Mobile │ SMS │ Voice │ Spatial │ AiOT │ Quantum │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
    ┌─────────────────┐      ┌─────────────────────┐
    │  Ember App      │      │  Licensed Apps       │
    │  (Reference     │      │  (Built on           │
    │  Implementation)│      │  Ember Framework)    │
    └─────────────────┘      └─────────────────────┘
```

### Framework layers

**Contextual Memory Engine**
Builds and maintains individual context models through conversation. No forms. No explicit data entry. Context is inferred from natural language, stored on-device, and grows more specific with every interaction. The personalization architecture that scales without central data storage.

**Conversation Engine**
The AI layer. Receives context from the Memory Engine, generates responses through the Claude API, and feeds new context back into storage. The system prompt is dynamically assembled from stored context on every call — making each response feel specific to this person, right now.

**Continuity Layer**
The cross-surface transport mechanism. Context built on mobile is available to SMS. Context from SMS informs voice. Context persists when the user switches devices, surfaces, or modalities. The individual model follows the person — not the platform.

**Surface Adapter Layer**
The interface abstraction. Each surface (mobile, SMS, voice, spatial, AiOT) implements the same adapter interface. The framework doesn't know or care which surface it's running on. Add a new surface by implementing the adapter — the memory, conversation, and continuity layers work unchanged.

---

## Surface roadmap

| Surface | Status | Description |
|---|---|---|
| **iOS Mobile** | Live | Native SwiftUI conversational interface. Full visual experience. Contacts integration. Circle management. SMS drafting. |
| **SMS** | In development | Zero-install reach. Broadest demographic access. Same context engine, text-only interface. Ideal for users who don't want an app. |
| **Voice** | Roadmap | Ambient, hands-free, eyes-free. SpeechKit integration. Same memory and continuity layer. Context persists between voice and text sessions. |
| **Spatial / XR** | Roadmap | Glasses and headsets. Contextual overlay on the physical world. Ember surfaces relevant context based on what you're looking at and who you're with. |
| **AiOT** | Roadmap | Health monitors, wearables, environmental sensors. Passive signal collection feeds the context engine. Drift detection without active input. |
| **Quantum** | Long horizon | Probabilistic personalization at scale currently impossible with classical compute. The continuity layer is designed for this transition. |

---

## The patent-pending claim

**Title:** Distributed Personalization Architecture for Conversational AI Systems

**Core claim:** A method and system for building, maintaining, and transporting individual AI context models through conversational interfaces, without requiring centralized data storage, wherein context is constructed incrementally from natural language interaction, stored locally at the point of interaction, and made available across heterogeneous interface surfaces through a portable context transport protocol.

**What makes it novel:**
All prior art in AI personalization requires central storage of user models. The novel mechanic is the elimination of central storage as a requirement — individual context models are complete and portable at the edge, assembled through the conversation itself, and do not degrade in quality at scale because they do not depend on population-level data aggregation.

**Commercial significance:**
This architecture is the only approach that can deliver genuine personalization across regulated industries (healthcare, finance, legal) where central data aggregation is restricted or prohibited. It is also the only approach that works at the individual level for any population size — personalization quality does not degrade as the user base grows because each context model is independent.

> *Note: This section describes the patent-pending claim for documentation purposes. Do not reproduce this language verbatim in public communications prior to patent grant.*

---

## Business model

### Framework licensing (B2B)

Developers and enterprises license the Ember Framework to build their own conversational AI applications with personalization built in.

| Tier | Target | Model |
|---|---|---|
| **Open Core** | Individual developers | Free. Core framework open source under MIT. |
| **Commercial License** | Startups and SMB | Annual license. Removes open-source attribution requirement. Includes support. |
| **Enterprise License** | Large organizations | Custom pricing. SLA. Private deployment. Regulated industry compliance package. |

### Application revenue (B2C)

The Ember application generates direct consumer revenue.

| Tier | Model |
|---|---|
| **Free** | Core circle, basic nudges, text conversation |
| **Premium** | Unlimited circle, full memory depth, SMS drafting, priority responses |
| **Partner integrations** | Referral and affiliate revenue when users act on partner suggestions (OpenTable, Instagram, etc.) |

**The commercial rule:** A partner appears only when it completes an action the user already wants to take. Never as advertising. Never before the user has decided to act.

---

## Developer quick start

### Requirements

| Requirement | Version |
|---|---|
| macOS | Ventura 13.0 or later |
| Xcode | 15.0 or later |
| iOS deployment target | 17.0 or later |
| Claude API key | console.anthropic.com |
| Apple ID | Free — required to run on device |

### Installation

```bash
git clone https://github.com/positivelympw/ember.git
cd ember
```

Open `Ember.xcodeproj` in Xcode.

### API key setup

1. Get a Claude API key at **console.anthropic.com**
2. In Xcode right-click the **Ember** folder → **New File from Template** → **Configuration Settings File** → name it `Config`
3. Add one line:

```
CLAUDE_API_KEY = sk-ant-your-key-here
```

4. Click the blue **Ember** project icon → **PROJECT: Ember** → **Info** tab
5. Under **Configurations → Debug → Ember** → select **Config.xcconfig**

Your key is excluded from Git via `.gitignore` and never leaves your Mac except in API calls.

### Run on your iPhone

1. Plug in your iPhone → tap **Trust** when prompted
2. In Xcode click the device name at top → select your iPhone
3. Click **Ember target → Signing & Capabilities → Team** → select your Apple ID
4. Press **⌘R**

If you see **Untrusted Developer** on your phone:
Settings → General → VPN & Device Management → tap your Apple ID → Trust → press ⌘R again.

### Run wirelessly

Window → Devices and Simulators → check **Connect via Network** → unplug the cable. Builds work over WiFi as long as Mac and iPhone are on the same network.

---

## Using the Ember application

### Adding people to your circle

Tap **+** → your iOS contacts load → search and select someone → Ember asks about your last connection → answer naturally → that answer becomes their permanent memory.

### Having a conversation

Type in the input bar or press return to send. Ember remembers everything said in the session and uses stored context from previous sessions to make responses specific.

### Drafting a message

Select someone from your circle → tap **Draft** in the context bar → Ember writes a warm, specific message using everything it knows → review the draft → tap **Send via Messages** to open it pre-filled in iMessage or SMS → edit if you want → send.

### Managing your circle

Tap the **people icon** in the header to see your circle. Tap a person to focus Ember on them. Tap **−** to remove with confirmation. The circle persists across app restarts.

---

## Privacy

Ember is built on a specific privacy architecture that is also its technical differentiator.

### What stays on your device

- Your personal circle and all member data
- All relationship memory and context
- Conversation history
- Contact details synced from iOS Contacts

### What is sent to the Claude API

Each API call sends only:
- The first name of the person being discussed
- Memory context you have provided through conversation (last connection description, shared context, current context)
- Your typed message
- The circle member list (first names only)

**No phone numbers. No message history. No photos. No raw contact data.**

### What Ember never does

- Read iMessage or SMS content
- Access the Photos library
- Store data on any external server
- Share data with third parties
- Send messages without explicit user confirmation
- Track usage, sessions, or engagement metrics

### API key security

Your Claude API key is stored in `Config.xcconfig` on your Mac only. It is in `.gitignore` and is never committed to version control. It is transmitted only in direct HTTPS calls to the Anthropic API.

### On-device architecture

The choice to store all context on-device is both a privacy decision and the core technical claim of the framework. Individual context models do not require a central server. They are complete, portable, and private by design.

---

## App Store deployment checklist

Complete these steps before submitting to App Store or TestFlight.

### Apple Developer Program

Enroll at **developer.apple.com/programs** — $99/year. Allow 24–48 hours for activation.

### Bundle identifier

Set a permanent reverse-domain identifier in Xcode → Ember target → Signing & Capabilities:

```
com.yourname.ember
```

This cannot be changed after App Store submission.

### App icon

Apple rejects submissions without a complete icon set.

| Size | Usage |
|---|---|
| 1024×1024 px | App Store listing (required) |
| 180×180 px | iPhone home screen @3x |
| 120×120 px | iPhone home screen @2x |
| 87×87 px | Spotlight @3x |
| 80×80 px | Spotlight @2x |
| 60×60 px | Notification @3x |
| 40×40 px | Notification @2x |

Add in Xcode → Assets.xcassets → AppIcon.

### Required Info.plist keys

| Key | Required value |
|---|---|
| `NSContactsUsageDescription` | To know who matters to you — so Ember focuses on them, not everyone. |
| `NSSpeechRecognitionUsageDescription` | To let you talk to Ember hands-free. |
| `NSMicrophoneUsageDescription` | For voice input when you're driving or on the go. |

### Privacy policy

Required for any app accessing Contacts. Must be hosted at a permanent URL before submission.

Your policy must cover:
- Data collected (none stored externally)
- Data sent to third parties (minimal context to Claude API — first name and conversation context only)
- User rights (delete app to delete all data — nothing is stored externally)
- Contact for privacy questions

### App Store Connect

1. **appstoreconnect.apple.com** → My Apps → **+**
2. Fill in name, bundle ID, SKU, primary language
3. Category: **Productivity** or **Social Networking**
4. Age rating: **4+**
5. Add privacy policy URL
6. Add screenshots — minimum one per supported device size

**Suggested App Store description:**

```
Ember is a conversational AI agent that makes interactions feel
genuinely personal — without storing your data centrally.

Built on a patent-pending personalization framework, Ember learns
about the people in your life through natural conversation. Not
forms. Not profiles. Just talking.

Tell Ember about someone. Ember remembers. The next time you think
about them, Ember already knows the context — and helps you say
the right thing at the right time.

When you're ready to reach out, Ember drafts a warm, specific
message. You review it. You send it. Ember never acts without you.

Your data stays on your device.
No ads. No central database. No engagement metrics.
```

### Archive and submit

1. Xcode → scheme → **Any iOS Device**
2. **Product → Archive**
3. Organizer opens → **Distribute App → App Store Connect**
4. Follow prompts → Xcode uploads

### TestFlight (recommended before App Store)

1. App Store Connect → your app → TestFlight
2. Wait for build processing (10–30 minutes)
3. Add Internal Testers (your team — instant access)
4. Add External Testers (up to 10,000 — requires brief Apple review, 1–2 days)
5. Testers receive email → install TestFlight → install Ember

### Common Apple rejection reasons

| Reason | Prevention |
|---|---|
| Missing privacy policy | Add URL to App Store Connect before submitting |
| Contacts permission not justified | Make `NSContactsUsageDescription` specific about user benefit |
| Crashes during review | Test on a real device, not just simulator |
| Incomplete metadata | All screenshots and descriptions required before review |
| Guideline 5.1.1 — data collection | Privacy policy must match actual app behavior |

---

## Roadmap

### Now — iOS application
Personal relationship agent. Circle management. Conversational memory. SMS drafting.

### Next — SMS surface
Zero-install reach. The full framework through a phone number. No app required. Broadest demographic access. Ideal for users who prefer text over apps.

### Q3 2026 — Voice surface
SpeechKit integration. Ambient, hands-free interaction. Same memory layer — context persists between voice and text. Wake word support. AirPods optimization.

### Q4 2026 — Framework SDK
Developer SDK for building applications on the Ember Framework. Documentation, sample apps, TypeScript and Swift packages. Commercial license tier launch.

### 2027 — Spatial surface
Apple Vision Pro and smart glasses integration. Contextual overlay on the physical world. Ember surfaces relevant context based on environment, location, and who you're with.

### 2027 — AiOT surface
Health monitor and wearable integration. Passive signal collection (activity, sleep, biometrics) feeds the context engine. Drift detection without active input. Partners: Apple Health, Garmin, Oura.

### Long horizon — Quantum
Probabilistic personalization at scale impossible with classical compute. The Continuity Layer is designed for this transition. Context transport protocol is quantum-ready.

---

## Contributing

Ember is open source at its core. The framework is the contribution.

Every significant decision in the codebase is documented with a `// LESSON:` comment explaining the technical pattern and a product reason for the choice. The codebase is designed to teach as it builds.

**Contribution areas:**
- Surface adapters for new interfaces
- Memory engine improvements
- Drift signal algorithms
- Localisation
- Accessibility
- Integration partners (implement the `EmberPartner` protocol)

**Before contributing:** Read `ARCHITECTURE.md` for the decision log. Every significant choice is documented with its rationale. Open an issue before a large PR.

---

## Licence

**Ember Framework** — MIT. Free to use, modify, and distribute. Attribution required for open-source use. Commercial license available — contact for terms.

**Ember Application** — Proprietary. The iOS application built on the framework is not open source.

**Patent pending.** The personalization architecture described in this repository is the subject of a pending patent application. Use of the framework under the MIT license does not grant any rights to the underlying patent claims.

---

*Built on Claude API by Anthropic. Patent pending.*
