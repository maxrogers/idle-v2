# Todo List

## Completed

- [x] Phase 1: Project Scaffolding — Theme, icon, Info.plist, entitlements, MainView
- [x] Phase 2: Core Plugin Architecture & Data Models (VideoServicePlugin, ServiceRegistry, QueueItem, QueueManager)
- [x] Phase 3: iPhone UI Shell — Services, Queue, Settings screens (dark/amber)
- [x] Phase 4: Plex Authentication — PIN login, home user picker, Keychain storage
- [x] Phase 5: Plex Library Browsing (iPhone) — sections, on deck, recently added, drill-down
- [x] Phase 6: CarPlay Scene Setup — CPTemplateApplicationSceneDelegate, CPTabBarTemplate
- [x] Phase 7: CarPlay Plex Browsing — CPListTemplate sections, drill-down, thumbnails
- [x] Phase 8: Playback Engine — AVPlayer, external display routing, MPNowPlayingInfoCenter
- [x] Phase 9: WKWebView YouTube Fallback — auto-play + theater mode JS injection
- [x] Phase 10: Share Sheet Extension — ShareViewController + Info.plist created (manual Xcode target wiring needed)
- [x] Phase 11: Queue & History Persistence — SwiftData QueueItem, QueueManager CRUD
- [x] Phase 12: Plex GDM Advertising — UDP multicast + Companion HTTP server

## Pending / Next Steps

- [ ] Manually add Share Extension target in Xcode (File > New > Target > Share Extension "idleShare")
  - Add group.com.steverogers.idle App Group entitlement to the extension target
  - Set ShareViewController.swift as the principal class
- [ ] Add NSLocalNetworkUsageDescription to Info.plist (required for GDM multicast)
- [ ] Add NSLocationWhenInUseUsageDescription to Info.plist (for future parked detection)
- [ ] Implement parked/idle detection using IdleDetector (CoreLocation speed)
- [ ] Test full Plex auth + CarPlay flow in simulator
- [ ] Apply for CarPlay audio entitlement at https://developer.apple.com/contact/carplay

## Review Section

### Session 1 — Initial Build (2026-03-08)

Built all 12 phases in a single session. Core architecture established:
- Pluggable VideoServicePlugin protocol with PlexService as first implementation
- CarPlay scene delegate with CPTabBarTemplate (audio entitlement path)
- AVPlayer with `usesExternalPlaybackWhileExternalScreenIsActive = true` for automatic CarPlay routing
- WKWebView fallback for YouTube with JS theater mode injection
- SwiftData queue/history persistence
- Plex PIN auth, home user picker, full library browsing
- CarPlay Plex tab with CPListTemplate drill-down and thumbnail loading
- PlexGDM UDP multicast + PlexCompanionServer HTTP cast receiver
- Share extension files created (manual target wiring needed)
- Clean build with 0 errors, 1 acceptable Swift 6 migration warning
