# SPEC.md: idle Project

## Overview

**Project Name:** idle  
**Target:** iOS 26.4+ / CarPlay (exclusively targeting iOS 26.4 and later)  
**Goal:** A dead-simple app called idle that gives users full, beautiful access to their Plex library (and future services) directly on the CarPlay screen — exactly like the new Apple TV CarPlay app that Apple ships in iOS 26.4. Services are implemented as true plugins that users can enable/disable at will on the iPhone. The first plugin is Plex: users link their Plex account once on the iPhone (via official Plex PIN login + home-user selection), add/enable the Plex service, and then browse their entire Plex library from a dedicated Plex tab on CarPlay. Tapping any movie, show, or video instantly plays it full-screen on the CarPlay display using the brand-new iOS 26.4 AirPlay video functionality (AVPlayer + system routing to the CarPlay display). Future services (YouTube, Netflix, etc.) plug in the same way and get their own prime tabs. The app also explores advertising itself as a Plex GDM player so the native Plex iOS app can cast directly to idle while browsing on the phone. Share-sheet support for any web video remains as a quick-play option. The whole experience feels magically native and frictionless.

---

## Branding & Naming

- **Name:** "idle" — automotive-native word every driver instantly understands (engines idle). Implies "only active when stopped" without ever saying the word "parked." Minimalist, Apple-restrained: one lowercase word.
- **Icon:** `AppIcon.png` is provided at the repo root. Use it as the app icon (wire into Assets.xcassets) and as the logo/hero image on the main iPhone app screen.
- **Accent color:** Amber — warm engine-idle glow for all highlights, buttons, selection states, and interactive elements.
- **Theme:** Dark theme by default throughout (deep blacks/grays for both CarPlay and iPhone views). Reduces glare, matches automotive environments.

---

## Entitlement Strategy

The CarPlay video entitlement is MFi-gated. We do **not** currently have this entitlement. Build-first strategy: develop and test fully via Xcode simulator (CarPlay + iPhone side-by-side), distribute via TestFlight, and apply for the entitlement when Apple opens it to the broader developer community. All architecture must be entitlement-ready so that flipping it on requires zero structural changes.

---

## Playback Architecture

### AirPlay Video Routing (iOS 26.4)
The target experience: the CarPlay screen becomes a **dedicated AirPlay video receiver** that AVPlayer routes to **automatically** — no user-facing AirPlay picker, no extra taps. The experience must feel as seamless and stock as possible. Leverage every new iOS 26.4 AirPlay video hook to achieve automatic routing to the CarPlay display. Explore whether any system APIs (AVRouteDetector, AVAudioSession routing, CarPlay scene activation, or undocumented behaviors) allow third-party apps to force the CarPlay video destination without user intervention.

### YouTube URLs via Share Sheet (WKWebView fallback)
For any `youtube.com` or `youtu.be` URL received via Share Sheet:
- Fall back to a clean full-screen **WKWebView** loading the official YouTube web player.
- Automatically trigger play + theater mode via lightweight JavaScript injection.
- Overlay standard CarPlay transport controls (play/pause, scrubber) on top.
- No stream extraction. No ToS violations. Best UX, zero legal gray area.

### Protected Content
Let the system's media stack handle DRM. Do not attempt to strip or work around protection.

---

## Plex Integration

### Authentication Flow (iPhone)
1. User opens idle → Services → Add Plex.
2. Official **Plex PIN login** flow (no username/password stored).
3. After authentication, idle fetches available Plex home users from the Plex API.
4. If more than one home user exists, the idle user is **prompted to select a user**.
5. If the selected user has a passcode, they must enter it to confirm selection.
6. After selection, idle loads that user's library (Plex handles all access restrictions, content filtering, and permissions per user — idle does not need to implement any of this logic).
7. The user can later change the selected Plex user under **Settings → Services → Plex → Switch User**.

### User Switching Mid-Session
- If the user switches Plex home users while CarPlay playback is active, playback **stops immediately** with a clear message explaining that the user was switched.

### CarPlay Plex Tab
Model exactly after Apple's TV CarPlay app:
- Continue Watching
- Libraries
- Recently Added
- Native `CPGridTemplate` / `CPListTemplate` with card-style thumbnails
- Filters, search, seasons/episodes drill-down (go beyond Apple's minimalism where useful)
- Tap any video → instant full-screen playback on CarPlay display

### Plex GDM Casting (Bonus Flow)
idle advertises itself as a Plex GDM player via UDP multicast so the native Plex iOS app sees idle as a cast target. Implement UDP multicast advertising + Companion protocol where feasible. Explore creative background execution strategies (the primary limitation is iOS killing background UDP listeners — document the best achievable behavior: "works great when app is foregrounded" vs. "works when phone is locked" and implement the best realistic option). Include clear in-app instructions modeled after Plex's official guidance explaining how to cast from the native Plex iOS app to idle.

---

## Pluggable Services Architecture

### Protocol
All services implement a `VideoServicePlugin` protocol. Core app has zero service-specific logic. Adding a new service requires only a new plugin module.

### Plugin Capabilities (metaphorical support)
Some future services (Netflix, etc.) may not be technically feasible due to DRM or API restrictions. The architecture must be structured to *attempt* any service as a plugin. Feasibility is explored per-service — the plugin system never assumes what's possible.

### iPhone Services Screen
- Users enable/disable plugins.
- Users drag-and-drop to set service order (this order determines CarPlay tab order).
- A clear note explains: "Drag to reorder. Tab order on CarPlay follows this list. CarPlay supports a limited number of tabs."

---

## CarPlay UI

### Tab Architecture
- Service tabs appear in the order set by the user in iPhone Settings → Services.
- **Settings tab:** Always the last to appear, first to be removed when space is tight. Never bumps a service.
- **Now Playing:** Uses the **system-provided Now Playing button** (top-right navigation bar, standard CarPlay waveform/music-note icon). Lean on system behavior — no custom implementation. Tapping returns user to an active or paused video.
- **Queue tab:** Visible only when the queue is non-empty. Appears after all service tabs (before Settings if Settings is present).
- CarPlay tab bar hard limit: respect the platform maximum (~4–5 tabs). Settings is always sacrificed first.

### Queue Tab (CarPlay)
- Shows current queue (shared URLs / pasted links only — not Plex or service content).
- Shows **history** of recently played queue items; tap to replay.
- Plex and other services do **not** use the queue — they play on tap from their own browsing UI.

### Parked/Idle Detection (implement later)
- Strategy: use **CoreLocation speed** (the most built-in Apple method) as the source of truth.
- Behavior: fully pause and lock video playback above a speed threshold (option C).
- This feature is to be implemented after all other features are confirmed working. Architecture should leave a clean hook for it.

---

## iPhone App

### Main Screen
- Display `AppIcon.png` as the hero logo.
- Dark theme, amber accents.
- Primary navigation: Services, Queue, Settings.

### Queue Screen (dedicated)
- User can **paste a URL** to add a video to the top of the queue.
- If connected to CarPlay at the moment of adding, playback begins immediately on the CarPlay screen.
- If not connected to CarPlay, the URL is saved to the queue (watch later fallback).
- Shared URLs from the Share Sheet also land here.
- Shows queue + history.

### Services Screen
- Add / remove / enable / disable plugins.
- Drag-and-drop reorder (sets CarPlay tab order).
- Per-service settings (e.g., Plex → Switch User).

---

## Share Sheet Extension

- Day-one feature.
- Receives video URLs from any app (Safari, YouTube, etc.).
- Runs in a separate process; hands off to the main idle app immediately.
- If CarPlay is connected: video plays immediately on CarPlay screen and is added to queue/history.
- If CarPlay is not connected: saved to queue as watch-later.
- YouTube URLs → WKWebView fallback player (see Playback Architecture above).
- Direct video URLs → AVPlayer.

---

## Queue & History

- Queue is **global** (not per-service). Only populated by: Share Sheet, pasted URLs.
- New items added to the **top** of the queue.
- History persists across drives/sessions.
- Queue persists across drives/sessions.

---

## Core Philosophy for Claude

Be ruthlessly diligent and think far outside the box. Build everything from scratch so the final code looks and feels completely original. Apple's rules are strict around CarPlay and video, but iOS 26.4 finally gives us powerful new AirPlay video hooks. Search the web and Apple's latest CarPlay + AVFoundation documentation for any undocumented behaviors or system integrations that let third-party apps ride the new AirPlay video routing. If the obvious path hits a wall (especially car-manufacturer MFi gating), invent better hacks, unconventional system integrations, or clever workarounds (App Intents, Shortcuts deep links, background scene activation, custom AVPlayer routing, voice intents, UDP multicast for GDM, or anything smarter we haven't considered). Do not get attached to any previous ideas. The entire product must feel like the app Apple would have shipped if they could — especially the Plex tab mirroring the official Apple TV CarPlay experience, with a fully pluggable service architecture for future expansion.

---

## Design Principles

- **Dark theme** everywhere. Deep blacks and grays. Amber accents.
- **CarPlay:** Minimal UI, large tappable areas, calm animations. Native `CPGridTemplate` / `CPListTemplate`. Match Apple TV CarPlay app structure for Plex tab, but go further with filters, search, and drill-down navigation.
- **iPhone:** Clean, native SwiftUI. AppIcon.png as hero on main screen. Feels like a premium first-party app.
- **Safety:** No interaction required while driving beyond tapping large targets. Parked detection (future) adds a hard lock.

---

## Deliverables

1. Complete, ready-to-build Xcode project named idle.
2. Clean README explaining architecture (iOS 26.4 AirPlay video, plugin system, GDM feature) and why it's the best outside-the-box solution.
3. Exact copy-paste text for the CarPlay entitlement request.
4. Short video-demo script covering: Plex tab flow, share-sheet flow, GDM cast demo.
5. List of creative hacks / new techniques used and why they work better than conventional approaches.

---

## Open Questions / Deferred

- **Speed threshold for parked detection:** TBD when implementing the feature. Use CoreLocation speed; implement after all other features confirmed working.
- **GDM background execution ceiling:** Document and implement the best achievable behavior given iOS background restrictions.
- **Future service feasibility:** YouTube (WKWebView confirmed), Netflix and others TBD per-plugin.
