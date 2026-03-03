# SPEC.md: idle Project

**Project Name:** idle
**Target:** iOS 26.4+ / CarPlay (exclusively targeting iOS 26.4 and later)
**Goal:** A dead-simple app called **idle** that lets any user share a webpage or video link from Safari (or anywhere) on their iPhone and have it instantly play full-screen on the CarPlay display — zero extra taps, zero friction. The CarPlay side becomes a clean, automotive-native experience that feels like it was always meant to be there.

## Branding & Naming Direction (use exactly)

- "idle" — automotive-native word every driver instantly understands (engines idle).
- Implies "only active when stopped" without ever saying the word "parked."
- Minimalist, Apple-restrained: one lowercase word, clean icon (think subtle tachometer needle at zero or a soft glowing "idle" badge).
- Subtle irony: the app only wakes up when the car is idle. Icon and UI must feel calm, quiet, and perfectly at home in a car.

## Core Philosophy for Claude

Be ruthlessly diligent and think **far outside the box**. Reference the TDS-CarPlay repo **only** for high-level inspiration on what is possible — do **not** copy, adapt, or resemble any of its code, structure, or patterns. Build everything from scratch so the final code looks and feels completely original. Apple's rules are strict, especially around CarPlay and video. Search the web for inspiration from other projects that may have clues to implement this project successfully. If the obvious path hits a wall, invent better hacks, unconventional system integrations, or clever workarounds (Shortcuts deep links, App Intents, background scene activation, new iOS 26.4 CarPlay video capabilities, custom share extensions, voice intents, or anything smarter we haven't considered). Do **not** get attached to any previous ideas (WKWebView lists, App Groups, ReplayKit, etc.). Explore fresh solutions that might be simpler, more reliable, or more future-proof. The entire product must feel magically frictionless: Share → video plays on CarPlay screen immediately.

## Primary User Flow (must feel instant)

1. User is on any webpage/video in Safari (or any app).
2. Tap Share → "idle".
3. Video (or the key video on the page) immediately begins playing full-screen on the CarPlay display.
   That's it. No opening an app on CarPlay, no extra buttons.

## Additional Smart Behaviors to Consider (only as starting points — invent better ones)

- If the shared page contains multiple videos, show an ultra-clean tappable list on CarPlay with preview thumbnails (or auto-play the most prominent one).
- Alternative mode: render a beautifully stripped-down version of the shared webpage on CarPlay that only surfaces tappable video elements (and handles login prompts cleanly if needed).
- Leverage every new CarPlay video / AirPlay improvement that arrived in iOS 26.4 beta — explore whether any of those system hooks can be used creatively for third-party apps.
- Zero-friction sharing via App Intents, system share sheet extensions, Siri, or any undocumented activation path that feels native.
- Think of entirely new delivery mechanisms we haven't discussed yet that could make the experience even smoother.
- Another idea to think about is perhaps the iOS app could log into services like YouTube, Plex, or similar and then present video options on the CarPlay screen/app from those logged in accounts.

## Technical Requirements for Claude

- Build the entire project from scratch under the name **idle** (targets, bundles, classes, files — everything uses "idle" naming).
- Use Xcode's built-in CarPlay simulator and iPhone simulator together. Visually examine both devices side-by-side, tap through the full flow repeatedly, and verify instant playback during testing.
- Make the CarPlay experience feel native and safe (minimal UI, large tappable areas, calm animations).
- Handle protected content (YouTube, Netflix, etc.) seamlessly — whatever method you choose must let the system's media stack do the heavy lifting where possible.
- Include parked/idle detection as a safety layer (invent the smartest possible implementation).
- Prepare the project so it can ship via TestFlight or sideloading without issues.

## Deliverables Claude Must Produce

1. Complete, ready-to-open Xcode project named **idle**.
2. Clean README explaining the chosen architecture and why it's the best outside-the-box solution.
3. Exact copy-paste text for the CarPlay entitlement request.
4. Short video-demo script showing the real Share → instant CarPlay playback flow.
5. List of any creative hacks or new techniques used and why they work better than conventional approaches.

## Implementation Decisions (from interview)

### Distribution & Entitlements
- **Distribution:** Both TestFlight and Xcode sideload. Architecture must degrade gracefully depending on what entitlements are available.
- **CarPlay category:** Register as "navigation" type to gain access to CPTemplateApplicationScene custom drawing surface for video rendering.
- **Entitlement strategy:** Build now, wait for Apple to open up video entitlements. TestFlight for sharing with others, sideload for personal use.

### Video Rendering on CarPlay
- **Approach:** Custom drawing via CPTemplateApplicationScene (navigation entitlement).
- **Aspect ratio:** Default to fill-screen (crop). User setting available to switch to letterbox/pillarbox or smart mode.
- **Resolution handling:** Adapt to varying CarPlay screen sizes (800×480 to 2560×720 ultrawide).

### Video Extraction
- **No cloud component.** All extraction happens on-device.
- **Bundled Swift extractor** for YouTube (80% case) plus existing open-source libraries where available.
- **Plex:** Use Plex API directly with user's token. Assume remote access / relay is configured.
- **Extraction priority order by quality:** Direct stream URL → on-device extraction → graceful failure message.

### Share Extension Flow
- **Invisible handoff preferred.** Share extension receives URL, passes to main app via App Groups/URL scheme. Main app does heavy lifting. Avoid flashing the main app if at all possible.

### Playback & Controls
- **CarPlay controls:** Standard transport — play/pause, scrub bar, back button.
- **Audio routing:** Pause on interruption (Maps, Phone), resume when interruption ends (music app behavior).
- **Background execution:** Silent audio track hack to keep process alive while CarPlay display is active.

### Failure UX
- **Transparent:** Brief message on CarPlay like "Can't play this one" with a suggestion. Keep within Apple's CarPlay text/button limits.

### Multiple Videos
- **Show first N most prominent** videos with a "more" button via CPListTemplate.

### URL Scheme & Automation
- **Register `idle://play?url=...`** custom URL scheme for Shortcuts, Siri, and other automation tools.
- **App Intents** support for "Hey Siri, play this on CarPlay" workflows.

### Queue & History
- **Persistent queue.** Users can share links before getting in the car. When CarPlay connects, show "ready to play" items.
- **History persists** for quick replay of previously shared content.

### Service Logins (V1 — moved from V2)
- **V1 includes Plex and YouTube login.** Users add credentials on iPhone app. CarPlay shows service icons as browsable tabs.
- **Plex:** Login on iPhone → CarPlay shows Plex tab with library browsable via native CPListTemplate/CPGridTemplate (card-style thumbnails, categories). Tap to play.
- **YouTube:** YouTube Data API (free tier, 10K units/day) for browsing/search on CarPlay. YouTubeKit for stream extraction on playback.
- **Pluggable architecture:** `VideoService` protocol. Adding new services (Netflix, Disney+, Crunchyroll, etc.) = adding a new protocol conformance. CarPlay tabs and iPhone service list are driven by registered/authenticated services.
- **Session inheritance** from Safari to be researched but not V1 blocker.

### Pluggable Service Protocol
```swift
protocol VideoService {
    var name: String { get }
    var icon: UIImage { get }
    var isAuthenticated: Bool { get }
    func authenticate() async throws
    func fetchCategories() async throws -> [ContentCategory]
    func fetchItems(for category: ContentCategory) async throws -> [VideoItem]
    func extractStream(for item: VideoItem) async throws -> StreamInfo
}
```

### CarPlay UI Approach
- **Native CarPlay templates only** — no WKWebView on CarPlay. Matches Apple TV CarPlay app pattern.
- CPTabBarTemplate with tabs: Queue, Plex, YouTube (service tabs appear only when authenticated).
- CPListTemplate with iOS 26 "Card Element" presentation style (portrait cards, full-bleed thumbnails) for browsing.
- CPSearchTemplate for searching within services.
- Large tap targets, minimal text, automotive-safe interaction.

### YouTube Data Source
- **YouTube Data API** for browsing/searching content listings on CarPlay (trending, search, playlists).
- **YouTubeKit** for extracting actual playable stream URLs on playback.
- Clean separation: API for discovery, YouTubeKit for playback.

### Background Execution (Revised)
- **Drop silent audio hack.** Rely on CarPlay scene lifecycle to keep app alive (iOS 26.4+).
- CarPlay apps stay active while scene is connected. If insufficient, add hack back later.

### Design Direction
- **Model after:** Apple TV CarPlay app (iOS 26.4) for CarPlay UI. Denim + Lumy (2025 ADA winners) for iPhone aesthetic.
- **Dark by default** — matches automotive environments, reduces glare.
- **Color palette:** Dark grays, single warm accent color (amber/gold — like an idling engine indicator light).
- **Typography:** San Francisco throughout, large type weights.
- **CarPlay:** Card Element presentation style for browsing. Clean, calm, native feel.
- **iPhone:** SwiftUI with subtle animations, glassmorphism touches.

---

Start building **idle** now. Prioritize simplicity and magic above everything. Surprise us with solutions we haven't thought of. This should feel like the app Apple would have shipped if they could. Go.
