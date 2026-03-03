# idle — Implementation Plan (Revised)

## Architecture Summary

**Target:** iOS 26.4+ exclusively. No backwards compatibility needed.

**Dual rendering paths:**
1. **Path A (Navigation CPWindow):** Custom drawing via `CPWindow` for sideloaded builds.
2. **Path B (AirPlay Video):** iOS 26.4 official AirPlay video to CarPlay. Future-proof, Apple-blessed.
3. Core uses `AVPlayer` — works identically for either path.

**Pluggable service architecture:** `VideoService` protocol. Plex + YouTube in V1. New services = new conformance.

**CarPlay UI:** Native templates only (CPTabBarTemplate, CPListTemplate with Card Element style, CPSearchTemplate). No WKWebView. Modeled after Apple TV CarPlay app.

**YouTube data:** YouTube Data API for browsing, YouTubeKit for stream extraction.

**Background:** CarPlay scene lifecycle (iOS 26.4+). No silent audio hack.

---

## Phase 1: Project Foundation ✅

- [x] 1.1 Create Xcode project "idle" (iOS app, SwiftUI lifecycle, deployment target iOS 26.4)
- [x] 1.2 Configure bundle IDs: `com.idle.app`, `com.idle.app.share-extension`
- [x] 1.3 Add App Groups: `group.com.idle.shared`
- [x] 1.4 Add CarPlay entitlement (navigation type)
- [x] 1.5 Add Background Modes: audio, fetch
- [x] 1.6 Register URL scheme: `idle://`
- [x] 1.7 Add CarPlay scene configuration to Info.plist
- [x] 1.8 Create folder structure (all directories created and populated)

## Phase 2: Core Models & Playback Engine ✅

- [x] 2.1 Define `VideoService` protocol
- [x] 2.2 Define models: `VideoItem`, `StreamInfo`, `ContentCategory`
- [x] 2.3 Build `PlaybackEngine` singleton (audio session, interruptions, AirPlay, time observer)
- [x] 2.4 Build `QueueManager` with SwiftData (persistent queue + history, share extension hook)

## Phase 3: Video URL Extraction Pipeline ⚠️

- [ ] 3.1 Integrate YouTubeKit via SPM ← **BLOCKED: only critical incomplete item**
- [x] 3.2 Build `ExtractionRouter` — URL → correct extractor
- [ ] 3.3 Implement `YouTubeExtractor` (stub only — returns embed URL placeholder)
- [x] 3.4 Implement `PlexExtractor` (direct API, X-Plex-Token)
- [x] 3.5 Implement `GenericExtractor` (WKWebView + JS, OEmbed/OpenGraph)

## Phase 4: Plex Service Integration ✅

- [x] 4.1 Build `PlexService` conforming to `VideoService`
- [x] 4.2 Plex auth flow — **upgraded to Link Code (PIN) flow via plex.tv/link** (v1.0.0+1)
- [x] 4.3 Fetch library sections (Movies, TV Shows, etc.) → `ContentCategory`
- [x] 4.4 Fetch items per section with thumbnails → `VideoItem`
- [x] 4.5 Stream URL construction from library metadata
- [x] 4.6 Search support via Plex API

## Phase 5: YouTube Service Integration ⚠️

- [x] 5.1 Build `YouTubeService` conforming to `VideoService`
- [x] 5.2 YouTube Data API integration (trending, search)
- [x] 5.3 API key configuration on iPhone settings
- [x] 5.4 Fetch categories (Trending, Search) → `ContentCategory`
- [x] 5.5 Fetch items with thumbnails → `VideoItem`
- [ ] 5.6 Playback via YouTubeKit stream extraction ← depends on 3.1

## Phase 6: Share Extension ❌ NOT STARTED

- [ ] 6.1 Create Share Extension target "idle Share"
- [ ] 6.2 Configure App Groups for shared container
- [ ] 6.3 Share extension receives URL → writes to shared UserDefaults
- [ ] 6.4 Darwin notification to wake main app
- [ ] 6.5 Main app reads URL → extracts → queues → auto-plays if CarPlay connected
- [ ] 6.6 Minimal share extension UI: "Sending to idle..." auto-dismiss

## Phase 7: CarPlay Integration ✅ (core complete, search pending)

- [x] 7.1 Build `CarPlaySceneDelegate` (Path A + Path B)
- [x] 7.2 Build `CarPlayVideoViewController` for CPWindow (Path A)
- [x] 7.3 Build CarPlay tab structure (Queue + dynamic service tabs)
- [ ] 7.4 Implement CPSearchTemplate for in-service search
- [x] 7.5 Transport controls: MPRemoteCommandCenter + MPNowPlayingInfoCenter (v1.0.0+2)
- [ ] 7.6 AirPlay video routing (Path B): auto-route to CarPlay when connected
- [x] 7.7 Error display: "Can't play this one" via CPAlertTemplate

## Phase 8: Idle/Parked Detection ✅ (core + CarPlay gating done)

- [x] 8.1 Build `IdleDetector` (CMMotionActivityManager + accelerometer fallback)
- [x] 8.2 Block video on motion, show "Video available when stopped" (v1.0.0+2)
- [ ] 8.3 Integrate with iOS 26.4 system detection where available

## Phase 9: iPhone App UI ✅

- [x] 9.1 Main screen: queue with status indicators, service icons
- [x] 9.2 Services screen: list of available services, login/configure buttons
- [x] 9.3 Plex settings: Link Code auth, server picker, connection status
- [x] 9.4 YouTube settings: API key, validation
- [x] 9.5 General settings: aspect ratio, queue auto-clear
- [x] 9.6 Now Playing surface: mini bar + full sheet with scrubber & controls (v1.0.0+2)
- [x] 9.7 Empty state: share sheet usage instructions
- [x] 9.8 Design: dark theme, amber accent

## Phase 10: App Intents & URL Scheme ✅

- [x] 10.1 Register `idle://play?url=...` handler
- [x] 10.2 Build `PlayOnCarPlayIntent` App Intent
- [x] 10.3 Expose to Shortcuts for Siri integration
- [ ] 10.4 Document example Shortcut

## Phase 11: Testing & Polish ❌ NOT STARTED

- [ ] 11.1 Test: Safari share → YouTube extraction → CarPlay playback
- [ ] 11.2 Test: Plex browse on CarPlay → select → play
- [ ] 11.3 Test: YouTube browse on CarPlay → search → play
- [ ] 11.4 Test: generic video URL (.mp4, .m3u8)
- [ ] 11.5 Test: queue persistence across CarPlay disconnect/reconnect
- [ ] 11.6 Test: idle detection (block during motion, allow when stationary)
- [ ] 11.7 Test: audio interruption handling
- [ ] 11.8 Test: CarPlay simulator + iPhone simulator side by side
- [ ] 11.9 Verify TestFlight + sideload builds

## Phase 12: Deliverables ❌ NOT STARTED

- [ ] 12.1 README.md with architecture explanation
- [ ] 12.2 CarPlay entitlement request text
- [ ] 12.3 Video demo script
- [ ] 12.4 Creative hacks documentation
- [ ] 12.5 Final clean build, no warnings

---

## Version History

| Version | Commit | Description |
|---------|--------|-------------|
| 1.0.0+0 | 822f850 | Initial Commit — full project scaffold |
| 1.0.0+1 | 08a75a1 | Plex Link Code auth & player registration |
| 1.0.0+2 | 8a43700 | Transport controls, now playing UI, idle gating |
| 1.0.0+3 | 7438fa3 | Fix onOpenURL handler, simulator testing pass |

---

## Review Section

### Planning Phase (Complete)
- Revised to iOS 26.4+ exclusive target
- Service logins (Plex, YouTube) moved to V1
- Native CarPlay templates for service browsing (no WKWebView)
- YouTube Data API + YouTubeKit dual approach
- Dropped silent audio hack, using CarPlay scene lifecycle
- Pluggable VideoService protocol for future service expansion
- Design modeled after Apple TV CarPlay app + Denim/Lumy aesthetic

### v1.0.0+1 Review
- Replaced manual Plex server URL/token entry with Link Code (PIN) flow
- Added PlexPINAuth, PlexServerDiscovery, PlexHeaders
- Registered idle as a Plex player device via X-Plex-Provides headers
- Updated PlexSettingsView with full PIN flow UI

### v1.0.0+2 Review
- Added MPRemoteCommandCenter for lock screen / Control Center transport controls
- Added MPNowPlayingInfoCenter integration (title, source, progress, media type)
- Built NowPlayingBar (mini player) and NowPlayingSheet (full controls with scrubber)
- Integrated IdleDetector with CarPlay playback — blocks video when vehicle is moving
- Note: CPNowPlayingTemplate requires audio entitlement; we have navigation. Remote
  commands still work via MPRemoteCommandCenter for lock screen and accessories.

### v1.0.0+3 Review
- Fixed bug: `onOpenURL` handler missing in idleApp.swift — URLs never reached URLSchemeHandler
- Simulator testing on iPhone 17 Pro Max (iOS 26.4):
  - App launches, dark theme, amber accent, Queue empty state ✅
  - URL scheme `idle://play?url=...` triggers system dialog and processes correctly ✅
  - `simctl openurl` sends URLs to app successfully ✅
- ExecuteSnippet functional tests all passed:
  - URLSchemeHandler: valid/invalid URLs, title parsing, queue insertion ✅
  - VideoItem: creation, sources, extraction status ✅
  - YouTubeExtractor: 4 URL format patterns parsed correctly ✅
  - ExtractionRouter: YouTube, direct, Plex, generic routing ✅
  - PlexHeaders: all 9 headers including X-Plex-Provides: player ✅
  - PlexConfig/PlexPIN/PlexResource: encode/decode roundtrips ✅
  - PlaybackEngine: singleton, state management ✅
  - IdleDetector: defaults to idle (stationary) in simulator ✅
  - ServiceRegistry: Plex + YouTube registered, lookup works ✅
  - PlayOnCarPlayIntent: AppIntent structure valid ✅
  - Theme: Color/Font extensions load correctly ✅
  - CarPlaySceneDelegate: static isConnected state ✅
- Clean build with zero warnings
