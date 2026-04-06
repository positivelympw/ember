# Ember

> *A patent-pending conversational UI framework for scalable personalization — across mobile, SMS, voice, spatial, and AiOT.*

**Current version: v0.7.0**

---

## What Ember is

Ember is two things built on the same foundation.

**Ember Framework** — an open-source infrastructure layer for building AI-powered conversational experiences that feel genuinely personal. Context is built through conversation, stored at the edge, and persists across every surface the user interacts on. No central data store. No user profiles. No forms.

**Ember Application** — the reference implementation. A group coordination platform powered by an action-oriented AI agent. Used by social groups planning events and organizations collaborating, negotiating, and managing documents. Available on iOS. SMS surface in development.

The framework is licensable. The application is the proof it works.

---

## The core insight

Every AI personalization system today works the same way: collect data about users centrally, build a model, serve personalized responses from that model.

Ember inverts this.

Context is built **through conversation itself** — not data entry. It lives **at the edge** — on the user's device, not a server. It is **portable across surfaces** — the same context that informs a mobile conversation also informs an SMS reply, a voice interaction, a spatial overlay.

This is the patent-pending mechanic: **a personalization architecture that scales without central data storage**, where individual context models are constructed, maintained, and transported through the conversational interface itself.

---

## Build log — Lego bricks

Each brick is a self-contained, working feature. Ship one. Test it. Build the next.

| Brick | Version | Status | What it built |
|---|---|---|---|
| **Brick 1** | v0.1.0 | ✅ Shipped | Project scaffolding — Xcode, SwiftUI, Hello World on device |
| **Brick 2** | v0.2.0 | ✅ Shipped | Claude API integration — live responses in the simulator |
| **Brick 3** | v0.3.0 | ✅ Shipped | Config.xcconfig — API key secure, never committed to Git |
| **Brick 4** | v0.4.0 | ✅ Shipped | Conversation memory — full history sent on every Claude call |
| **Brick 5** | v0.5.0 | ✅ Shipped | Contacts — iOS permission, real contact list, search, pull to refresh |
| **Brick 6** | v0.6.0 | ✅ Shipped | Personal circle — add/remove, UserDefaults persistence, drift levels, context memory, pill strip |
| **Brick 7** | v0.7.0 | ✅ Shipped | SMS drafting — MessageUI bridge, draft bubbles, Send via Messages |
| **Brick A** | v0.8.0 | ✅ Shipped | Document intelligence — PDF upload, PDFKit extraction, RAG context injection, document vault |
| **Brick B** | v0.9.0 | 🔨 Building | Voice input — SpeechKit, real-time transcription, mic button, listening banner |
| **Brick C** | v1.0.0 | 📋 Planned | Voice output — Ember speaks responses, AVSpeechSynthesizer |
| **Brick D** | v1.1.0 | 📋 Planned | SMS surface — Twilio integration, dedicated agent number, inbound client routing |
| **Brick E** | v1.2.0 | 📋 Planned | Group coordination — multi-member groups, social + org types, group context |
| **Brick F** | v1.3.0 | 📋 Planned | App Store submission — icon, launch screen, privacy policy, TestFlight beta |
| **Brick G** | v2.0.0 | 🗺 Roadmap | Framework SDK — developer licensing, TypeScript + Swift packages |
| **Brick H** | v2.1.0 | 🗺 Roadmap | Spatial surface — Apple Vision Pro, Meta glasses adapter |
| **Brick I** | v2.2.0 | 🗺 Roadmap | AiOT surface — health monitors, wearables, passive signal collection |
| **Brick J** | v3.0.0 | 🌅 Horizon | Quantum — probabilistic personalization at classical-impossible scale |

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
Builds and maintains individual context models through conversation. No forms. No explicit data entry. Context is inferred from natural language, stored on-device, and grows more specific with every interaction.

**Conversation Engine**
The AI layer. Receives context from the Memory Engine, generates responses through the Claude API, and feeds new context back into storage. The system prompt is dynamically assembled from stored context on every call.

**Continuity Layer**
The cross-surface transport mechanism. Context built on mobile is available to SMS. Context from SMS informs voice. Context persists when the user switches devices, surfaces, or modalities.

**Surface Adapter Layer**
The interface abstraction. Each surface implements the same adapter interface. Add a new surface by implementing the adapter — memory, conversation, and continuity layers work unchanged.

---

## Agent persona

Ember's agent is an **organization leader**: empathetic and action-oriented. Always resolves a situation. Never leaves a thread open.

This persona serves both use cases:
- **Social groups** — friends coordinating events, reservations, plans. Warmer tone. Still moves to resolution.
- **Organizations** — teams collaborating, negotiating, managing documents. More precise. Same resolve.

The persona lives in the system prompt and can be adapted per deployment.

---

## Current capabilities (v0.8.0)

### Group coordination
- Personal circle of people to coordinate between
- Drift level tracking per person (connected / drifting / distant / unknown)
- Context memory built through conversation — last interaction, shared background, current situation
- Quick-access pill strip for instant person switching
- Circle persists across app restarts

### Document intelligence (Enterprise)
- PDF upload from Files, iCloud, Dropbox, or any iOS document provider
- PDFKit text extraction on a background thread
- Document tagged to property address or topic
- RAG (Retrieval-Augmented Generation) — extracted text injected into Claude's context window
- Active document banner in conversation
- Document vault with search

### SMS drafting
- Ember drafts a specific, warm message based on stored context
- Draft appears as a bubble with dashed border
- Send via Messages opens native iMessage / SMS pre-filled
- User reviews and sends — Ember never sends without confirmation

### Voice input (v0.9.0 — in progress)
- Tap mic button to speak
- SpeechKit transcribes in real time
- Words appear in the text field as you speak
- Tap stop or send to complete
- Listening banner signals active recording

### Coming next
- Voice output — Ember speaks responses (Brick C)
- SMS surface via Twilio (Brick D)
- Group types — social and organizational (Brick E)

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
open Ember.xcodeproj
```

### API key setup

1. Get a Claude API key at **console.anthropic.com**
2. Right-click the **Ember** folder in Xcode → **New File from Template** → **Configuration Settings File** → name it `Config`
3. Add one line:

```
CLAUDE_API_KEY = sk-ant-your-key-here
```

4. Click the blue **Ember** project icon → **PROJECT: Ember** → **Info** tab
5. Under **Configurations → Debug → Ember** → select **Config.xcconfig**

Your key is excluded from Git via `.gitignore` and never transmitted except in direct HTTPS calls to the Anthropic API.

### Run on your iPhone

1. Plug in your iPhone → tap **Trust** when prompted
2. In Xcode click the device name at top → select your iPhone
3. Click **Ember target → Signing & Capabilities → Team** → select your Apple ID
4. Press **⌘R**

**Wireless builds:** Window → Devices and Simulators → check **Connect via Network** → unplug cable. Works over WiFi on the same network.

**Untrusted Developer:** Settings → General → VPN & Device Management → tap your Apple ID → Trust → press ⌘R again.

### Required Info.plist keys

| Key | Value |
|---|---|
| `NSContactsUsageDescription` | To coordinate between the people in your group. |
| `NSMicrophoneUsageDescription` | For voice input when your hands are busy. |
| `NSSpeechRecognitionUsageDescription` | To let you talk to Ember instead of typing. |

---

## File structure

```
Ember/
├── ContentView.swift        # Main UI — conversation, circle, input bar
├── CircleStore.swift        # People persistence — ObservableObject + UserDefaults
├── DocumentStore.swift      # Document persistence — PDF text, RAG context builder
├── DocumentView.swift       # Document management UI — upload, tag, activate
├── VoiceInputManager.swift  # SpeechKit — mic, transcription, permission
├── MessageComposer.swift    # MessageUI bridge — SMS/iMessage pre-fill
├── EmberApp.swift           # App entry point
├── Info.plist               # Permissions and API key reference
└── Assets.xcassets          # Icons and colors
```

---

## Privacy

### What stays on your device
- Your coordination group and all member data
- All relationship memory and context
- Conversation history within sessions
- Contact details synced from iOS Contacts

### What is sent to the Claude API
Each API call sends only:
- First names of people being discussed
- Memory context provided through conversation
- Your typed or spoken message
- Active document text (when a document is activated)

**No phone numbers. No full message history. No photos. No raw contact data.**

### What Ember never does
- Read iMessage or SMS content
- Access the Photos library
- Store data on any external server
- Share data with third parties
- Send messages without explicit user confirmation
- Track usage, sessions, or engagement metrics

---

## App Store deployment checklist

### Apple Developer Program
Enroll at **developer.apple.com/programs** — $99/year. Allow 24–48 hours for activation.

### Bundle identifier
```
com.yourname.ember
```
Set in Xcode → Ember target → Signing & Capabilities. Permanent after App Store submission.

### App icon sizes required
| Size | Usage |
|---|---|
| 1024×1024 | App Store listing |
| 180×180 | iPhone home screen @3x |
| 120×120 | iPhone home screen @2x |
| 87×87 | Spotlight @3x |
| 80×80 | Spotlight @2x |

### Privacy policy
Required for Contacts access. Must be hosted at a permanent URL before submission. Must cover: data collected (none externally), data sent to Claude API (minimal context only), user rights (delete app = delete all data).

### App Store description
```
Ember is a group coordination platform powered by an AI agent
that reads situations and resolves them.

Add the people you coordinate with. Describe what's happening.
Ember remembers everything, keeps track of where things stand,
and helps you move every situation forward.

When you need to send a message, Ember drafts it — specific,
warm, and ready to go. You review it. You send it.

Upload documents and your group can ask questions about them
in plain language. Ember answers from the actual content.

Your data stays on your device. No ads. No central database.
```

### TestFlight beta setup
1. App Store Connect → your app → TestFlight
2. Wait for build processing (~30 minutes)
3. Add External Testers → enter email addresses (up to 10,000)
4. Testers install TestFlight → install Ember
5. Apple review for external testers: 1–2 days first submission

### Common rejection reasons
| Reason | Fix |
|---|---|
| Missing privacy policy URL | Add before submitting |
| Contacts permission not justified | Make `NSContactsUsageDescription` specific |
| Crashes during review | Test on real device before submitting |
| Microphone permission not justified | Make `NSMicrophoneUsageDescription` specific |

---

## Business model

### Framework licensing (B2B)
| Tier | Target | Model |
|---|---|---|
| **Open Core** | Individual developers | Free. MIT license. Attribution required. |
| **Commercial** | Startups | Annual license. No attribution requirement. Support included. |
| **Enterprise** | Large organizations | Custom pricing. SLA. Private deployment. Regulated industry package. |

### Application revenue (B2C)
| Tier | What's included |
|---|---|
| **Free** | Core coordination, basic memory, text conversation |
| **Pro** | Document intelligence, voice input/output, unlimited circle |
| **Partner integrations** | Referral revenue when users act on partner suggestions (OpenTable, etc.) |

---

## Patent

The personalization architecture described in this repository is the subject of a pending patent application.

**Core claim:** A method and system for building, maintaining, and transporting individual AI context models through conversational interfaces, without requiring centralized data storage, wherein context is constructed incrementally from natural language interaction, stored locally at the point of interaction, and made available across heterogeneous interface surfaces through a portable context transport protocol.

Use of the framework under the MIT license does not grant any rights to the underlying patent claims.

---

## Contributing

Every significant decision in the codebase is documented with a `// LESSON:` comment connecting the technical pattern to a product reason.

Good first contributions: new surface adapters, memory engine improvements, drift signal algorithms, localisation, accessibility, integration partners.

Open an issue before a large PR. Read the existing `// LESSON:` comments first — they document the decisions already made.

---

## Licence

**Ember Framework** — MIT. Attribution required for open-source use.
**Ember Application** — Proprietary.
**Patent pending.**

---

*Built on Claude API by Anthropic. Patent pending. v0.8.0*
