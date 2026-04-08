# Ember

> *A patent-pending conversational context framework.*

**v1.0.0-beta — April 2026**

---

## What Ember is

**Ember Framework** — a patent-pending infrastructure layer. Context is built through conversation, stored at the edge, and persists across every surface the user touches. No central database. No profiles. No forms.

**Ember Agent** — the front-end facilitator built on the framework. Reads the context the framework holds. Acts on it. The agent is a surface. The framework is the invention.

**Ember App** — the reference iOS implementation. Proof the framework works in production.

**The one-liner:** *Instead of ads telling you where to go, let your friend's memory serve you.*

---

## The core mechanic

Every AI personalization system today stores user models centrally. Ember inverts this.

Context is built **through conversation** — not data entry. It lives **at the edge** — on the user's device. It is **portable across surfaces** — mobile, SMS, voice, spatial, AiOT.

**Patent-pending claim:** A personalization architecture that scales without central data storage, where individual context models are constructed and transported through the conversational interface itself.

---

## Brand

Three colors. Pulled directly from the WatchWeWin logo.

| Role | Hex | Source |
|---|---|---|
| Base | `#0e0d0b` | Near-black — logo background. Nav, dark sections, footer. |
| Accent | `#2ec4b6` | Teal — geometric shape. CTAs, labels, hover states. |
| Energy | `#e84d1c` | Orange-red — runner figure. Declaration section, energy moments. |

Warm earth `#F7F5F0` — breathing room on light sections only. Never competes with brand colors.

**Typography:** Playfair Display (headlines) + DM Sans (body/UI)

---

## Build log

| Brick | Version | Status | What it built |
|---|---|---|---|
| **1** | v0.1.0 | ✅ | Project scaffolding — Xcode, SwiftUI, Hello World on device |
| **2** | v0.2.0 | ✅ | Claude API integration — live responses |
| **3** | v0.3.0 | ✅ | Config.xcconfig — API key secure, never in Git |
| **4** | v0.4.0 | ✅ | Conversation memory — full history per call |
| **5** | v0.5.0 | ✅ | Contacts — iOS permission, real list, search, pull to refresh |
| **6** | v0.6.0 | ✅ | Personal circle — add/remove, UserDefaults, drift levels, context memory |
| **7** | v0.7.0 | ✅ | SMS drafting — MessageUI bridge, draft bubbles, Send via Messages |
| **A** | v0.8.0 | ✅ | Document intelligence — PDF upload, PDFKit extraction, RAG injection |
| **B** | v0.9.0 | ✅ | Voice input — SpeechKit, real-time transcription, mic button |
| **E** | v0.10.0 | ✅ | Group threads — named groups, social + org types, persistent history |
| **F** | v0.11.0 | ✅ | Cross-session memory — Claude summaries, injected on return |
| **G** | v1.0.0 | ✅ | Pro tier — StoreKit IAP, manual enterprise unlock, paywall |
| **Web** | v1.0.0 | ✅ | ember.watchwewin.com — Cloudflare proxy, lead capture, EmailJS transcripts |
| **C** | v1.1.0 | 📋 | Voice output — Ember speaks responses (AVSpeechSynthesizer) |
| **D** | v1.2.0 | 📋 | SMS surface — Twilio + Supabase Edge Functions |
| **H** | v1.3.0 | 📋 | App Store — icon, launch screen, TestFlight public beta |
| **I** | v2.0.0 | 🗺 | Framework SDK — developer licensing, Swift + TypeScript packages |
| **J** | v2.1.0 | 🗺 | Spatial — Apple Vision Pro, Meta glasses adapter |
| **K** | v2.2.0 | 🗺 | AiOT — health monitors, wearables, passive signal |
| **L** | v3.0.0 | 🌅 | Quantum — probabilistic personalization at classical-impossible scale |

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
│  │   Mobile │ SMS │ Voice │ Spatial │ AiOT │ Quantum│   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## File structure

```
Ember/
├── ContentView.swift        — Main UI. AppView enum. All surfaces.
├── CircleStore.swift        — Individual people. Drift levels. Context memory.
├── GroupStore.swift         — Named groups. Social + org. Persistent history.
├── MemoryStore.swift        — Cross-session summaries. Claude-generated. Injected on return.
├── DocumentStore.swift      — PDF text. RAG context builder. Property tagging.
├── DocumentView.swift       — Upload, tag, activate documents. Pro feature.
├── VoiceInputManager.swift  — SpeechKit. Real-time transcription. Permission handling.
├── ProManager.swift         — StoreKit IAP. Manual enterprise unlock. Feature gating.
├── ProPaywallView.swift     — Paywall UI. Feature comparison. Purchase flow.
├── MessageComposer.swift    — MessageUI bridge. Pre-filled SMS/iMessage.
└── EmberApp.swift           — App entry point.
```

---

## Current capabilities (v1.0.0-beta)

### Context framework
- Individual context models built through conversation
- Stored on-device via UserDefaults — no central server
- Cross-session memory via Claude-generated summaries
- Context injected into every API call dynamically

### Personal circle
- Add people from iOS Contacts
- Drift level tracking: connected / drifting / distant / unknown
- Context memory per person — last interaction, background, current situation
- Quick-access pill strip for instant person switching

### Group threads
- Named groups — social or organizational type
- Add CircleMembers to groups
- Persistent group conversation history
- Cross-session group memory summaries

### Document intelligence (Pro)
- PDF upload from Files, iCloud, Dropbox
- PDFKit text extraction on background thread
- Tagged to property address or topic
- RAG injection — document text in Claude context window
- Active document banner in conversation

### Voice input
- Tap mic to speak
- SpeechKit real-time transcription
- Words appear in text field as you speak
- Listening banner with animated bars

### SMS drafting
- Claude drafts a specific message from stored context
- Draft bubble with dashed border
- Tap to open pre-filled in iMessage
- User reviews and confirms — Ember never sends alone

### Pro tier
- StoreKit 2 IAP — `com.watchwewin.ember.pro`
- Manual enterprise unlock (5x logo tap)
- Feature gating on document intelligence
- Lock badge on gated features

### Web demo
- Live at **ember.watchwewin.com**
- Cloudflare Worker proxy — API key never in browser
- Beta waitlist capture after 3 messages
- EmailJS transcript to explore@watchwewin.com

---

## Developer setup

### Requirements

| Requirement | Version |
|---|---|
| macOS | Ventura 13.0+ |
| Xcode | 15.0+ |
| iOS target | 17.0+ |
| Claude API key | console.anthropic.com |
| Apple ID | Free — required for device |

### Installation

```bash
git clone https://github.com/positivelympw/ember.git
cd ember
open Ember.xcodeproj
```

### API key

1. Get key at **console.anthropic.com**
2. Xcode → right-click Ember folder → New File → Configuration Settings File → name `Config`
3. Add: `CLAUDE_API_KEY = sk-ant-your-key-here`
4. Ember project → Info tab → Configurations → Debug → Ember → select **Config.xcconfig**

### Run on device

Plug in iPhone → Trust → select in Xcode → Signing & Capabilities → set Team → **⌘R**

**Wireless:** Window → Devices → Connect via Network

**Dev Pro unlock:** Tap the Ember logo 5x quickly

### Required Info.plist keys

```
NSContactsUsageDescription
→ To build context about the people in your life.

NSMicrophoneUsageDescription
→ For voice input — speak to Ember instead of typing.

NSSpeechRecognitionUsageDescription
→ To transcribe your voice into text in real time.
```

---

## App Store — v1 beta checklist

### Before submission

- [ ] Apple Developer Program ($99/year — developer.apple.com/programs)
- [ ] Bundle ID: `com.watchwewin.ember`
- [ ] App icon — 1024×1024 + all sizes in Assets.xcassets
- [ ] Launch screen configured
- [ ] Privacy policy at permanent URL
- [ ] StoreKit product `com.watchwewin.ember.pro` created in App Store Connect

### App Store description

```
Ember is a conversational context framework with a front-end
agent that facilitates.

The framework builds context through conversation — no forms,
no profiles. It lives on your device. It persists across every
session. The agent reads that context and acts on it.

Add the people and situations that matter. Ember remembers
everything, builds a picture over time, and helps you act
with specificity when the moment comes.

Upload a document. Clients ask questions via text.
Ember answers from the actual file.

Voice input. SMS drafting. Group threads.
Patent-pending personalization architecture.
No central database. No ads. No engagement metrics.

Your context stays yours.
```

### TestFlight

1. Product → Archive → Distribute App → App Store Connect
2. TestFlight → wait for build processing (~30 min)
3. Add External Testers → enter emails → Apple review (1-2 days)

### Common rejection reasons

| Reason | Fix |
|---|---|
| Missing privacy policy | Add URL before submitting |
| Contacts permission vague | State user benefit specifically |
| IAP not configured | Create product in App Store Connect before archiving |
| Crashes during review | Test on real device before submitting |

---

## Distribution roadmap (Brick D)

Three surfaces. Two storage layers. Freemium pricing.

**Surfaces:** SMS (Twilio) + Email (Gmail API) + iOS app

**Storage:** Gmail for consumers (user owns it) / Supabase for enterprise

**Pricing:**

| Tier | Price | Included |
|---|---|---|
| Free | $0 | 50 messages/month, circle, memory, SMS drafting |
| Pro | $9.99/mo | Unlimited messages, documents, voice, groups |
| Enterprise | $49+/mo | Dedicated Twilio number, Supabase storage, admin dashboard |

**Economics per user/month:**
- Free user: ~$0.40–0.60 cost
- Pro user: ~$2–4 cost → $9.99 price → ~$6–8 margin
- Enterprise: ~$49+ almost pure margin

---

## Business model

**Framework (B2B):** Open Core (MIT, free) → Commercial license → Enterprise (custom)

**Application (B2C):** Free → Pro → Partner integrations (referral revenue)

---

## Patent

The personalization architecture described in this repository is the subject of a pending patent application.

**Core claim:** A method and system for building, maintaining, and transporting individual AI context models through conversational interfaces, without requiring centralized data storage, wherein context is constructed incrementally from natural language interaction and made available across heterogeneous interface surfaces through a portable context transport protocol.

Use under MIT license does not grant rights to underlying patent claims.

---

## Privacy

**On device:** Circle, groups, memory summaries, conversation history, contacts, documents.

**Sent to Claude API per call:** First names, memory summaries, your message, active document text. No phone numbers. No raw history. No photos.

**Never:** iMessage content, Photos, external server storage, third-party sharing, autonomous sending.

---

## Licence

**Ember Framework** — MIT. Attribution required.
**Ember Application** — Proprietary.
**Patent pending.**

---

*ember — conversational context framework — patent pending*
*built by WatchWeWin — v1.0.0-beta — April 2026*
