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

## Phase 1: Project Foundation

- [ ] 1.1 Create Xcode project "idle" (iOS app, SwiftUI lifecycle, deployment target iOS 26.4)
- [ ] 1.2 Configure bundle IDs: `com.idle.app`, `com.idle.app.share-extension`
- [ ] 1.3 Add App Groups: `group.com.idle.shared`
- [ ] 1.4 Add CarPlay entitlement (navigation type)
- [ ] 1.5 Add Background Modes: audio, fetch
- [ ] 1.6 Register URL scheme: `idle://`
- [ ] 1.7 Add CarPlay scene configuration to Info.plist
- [ ] 1.8 Create folder structure:
  - `idle/App/` — Entry point, scene delegates
  - `idle/CarPlay/` — CarPlay scene delegate, templates, video renderer
  - `idle/Services/` — VideoService protocol, Plex service, YouTube service
  - `idle/Extraction/` — URL extraction pipeline (YouTubeKit, generic)
  - `idle/Playback/` — AVPlayer manager, audio session, AirPlay config
  - `idle/Queue/` — SwiftData persistent queue + history
  - `idle/Detection/` — Motion/idle detection
  - `idle/Intents/` — App Intents for Siri/Shortcuts
  - `idle/Views/` — SwiftUI iPhone views
  - `idle/ShareExtension/` — Share extension target

## Phase 2: Core Models & Playback Engine

- [ ] 2.1 Define `VideoService` protocol
- [ ] 2.2 Define models: `VideoItem`, `StreamInfo`, `ContentCategory`, `ServiceCredential`
- [ ] 2.3 Build `PlaybackEngine` singleton
  - AVAudioSession `.playback` category
  - Interruption handling (pause/resume)
  - AirPlay: `allowsAirPlayVideo = true`
  - Observe playback state for CarPlay UI updates
- [ ] 2.4 Build `QueueManager` with SwiftData
  - Persistent queue + history
  - Add from share extension, URL scheme, or service browse
  - Surface "ready to play" on CarPlay connect

## Phase 3: Video URL Extraction Pipeline

- [ ] 3.1 Integrate YouTubeKit via SPM
- [ ] 3.2 Build `ExtractionRouter` — URL → correct extractor
- [ ] 3.3 Implement `YouTubeExtractor` (YouTubeKit, local-only)
- [ ] 3.4 Implement `PlexExtractor` (direct API, X-Plex-Token)
- [ ] 3.5 Implement `GenericExtractor` (WKWebView + JS, OEmbed/OpenGraph)

## Phase 4: Plex Service Integration

- [ ] 4.1 Build `PlexService` conforming to `VideoService`
- [ ] 4.2 Plex auth flow on iPhone (server URL + token, stored in Keychain)
- [ ] 4.3 Fetch library sections (Movies, TV Shows, etc.) → `ContentCategory`
- [ ] 4.4 Fetch items per section with thumbnails → `VideoItem`
- [ ] 4.5 Stream URL construction from library metadata
- [ ] 4.6 Search support via Plex API

## Phase 5: YouTube Service Integration

- [ ] 5.1 Build `YouTubeService` conforming to `VideoService`
- [ ] 5.2 YouTube Data API integration (trending, search, playlists)
- [ ] 5.3 API key configuration on iPhone settings
- [ ] 5.4 Fetch categories (Trending, Subscriptions placeholder, Search results) → `ContentCategory`
- [ ] 5.5 Fetch items with thumbnails → `VideoItem`
- [ ] 5.6 Playback via YouTubeKit stream extraction

## Phase 6: Share Extension

- [ ] 6.1 Create Share Extension target "idle Share"
- [ ] 6.2 Configure App Groups for shared container
- [ ] 6.3 Share extension receives URL → writes to shared UserDefaults
- [ ] 6.4 Darwin notification to wake main app
- [ ] 6.5 Main app reads URL → extracts → queues → auto-plays if CarPlay connected
- [ ] 6.6 Minimal share extension UI: "Sending to idle..." auto-dismiss

## Phase 7: CarPlay Integration

- [ ] 7.1 Build `CarPlaySceneDelegate` (CPTemplateApplicationSceneDelegate)
  - `templateApplicationScene(_:didConnect:to:)` for Path A (CPWindow)
  - `templateApplicationScene(_:didConnect:)` for Path B (templates only)
- [ ] 7.2 Build `CarPlayVideoViewController` for CPWindow (Path A)
  - AVPlayerLayer, aspect ratio handling (fill default, user preference)
  - Adapt to screen size
- [ ] 7.3 Build CarPlay tab structure:
  - `CPTabBarTemplate` root with tabs:
    - "Queue" — CPListTemplate (pending + history)
    - "Plex" — CPListTemplate Card Element style (appears when authenticated)
    - "YouTube" — CPListTemplate Card Element style (appears when configured)
  - Each service tab: categories → items → tap to play
- [ ] 7.4 Implement CPSearchTemplate for in-service search
- [ ] 7.5 Transport controls: play/pause, scrub, back (via CPNowPlayingTemplate + navigation bar buttons)
- [ ] 7.6 AirPlay video routing (Path B): auto-route to CarPlay when connected
- [ ] 7.7 Error display: "Can't play this one" via CPAlertTemplate

## Phase 8: Idle/Parked Detection

- [ ] 8.1 Build `IdleDetector` (CMMotionActivityManager)
  - Stationary detection, N-second confirmation
  - Accelerometer fallback
- [ ] 8.2 Block video on motion, show "Video available when stopped"
- [ ] 8.3 Integrate with iOS 26.4 system detection where available

## Phase 9: iPhone App UI

- [ ] 9.1 Main screen: queue with status indicators, service icons
- [ ] 9.2 Services screen: list of available services, login/configure buttons
- [ ] 9.3 Plex settings: server URL, token, connection test
- [ ] 9.4 YouTube settings: API key, preferences
- [ ] 9.5 General settings: aspect ratio, queue auto-clear
- [ ] 9.6 Now Playing surface: play/pause, scrub, "Playing on CarPlay" indicator
- [ ] 9.7 Empty state: share sheet usage instructions
- [ ] 9.8 Design: dark theme, amber accent, San Francisco, glassmorphism touches

## Phase 10: App Intents & URL Scheme

- [ ] 10.1 Register `idle://play?url=...` handler
- [ ] 10.2 Build `PlayOnCarPlayIntent` App Intent
- [ ] 10.3 Expose to Shortcuts for Siri integration
- [ ] 10.4 Document example Shortcut

## Phase 11: Testing & Polish

- [ ] 11.1 Test: Safari share → YouTube extraction → CarPlay playback
- [ ] 11.2 Test: Plex browse on CarPlay → select → play
- [ ] 11.3 Test: YouTube browse on CarPlay → search → play
- [ ] 11.4 Test: generic video URL (.mp4, .m3u8)
- [ ] 11.5 Test: queue persistence across CarPlay disconnect/reconnect
- [ ] 11.6 Test: idle detection (block during motion, allow when stationary)
- [ ] 11.7 Test: audio interruption handling
- [ ] 11.8 Test: CarPlay simulator + iPhone simulator side by side
- [ ] 11.9 Verify TestFlight + sideload builds

## Phase 12: Deliverables

- [ ] 12.1 README.md with architecture explanation
- [ ] 12.2 CarPlay entitlement request text
- [ ] 12.3 Video demo script
- [ ] 12.4 Creative hacks documentation
- [ ] 12.5 Final clean build, no warnings

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
