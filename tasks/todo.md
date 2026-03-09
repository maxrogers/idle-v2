# idle — Task Tracker

## Completed Phases

### Phase 1: Project Scaffolding ✅
- Updated AccentColor to amber (#FFB300 / RGB 1.0, 0.702, 0.0)
- Copied AppIcon.png into Assets.xcassets
- Created `App/Theme.swift` — amber constants, dark theme ViewModifiers
- Created `App/AppDelegate.swift` — multi-scene app delegate, shared singletons
- Created `Views/MainView.swift` — hero screen + TabView (Services, Queue, Settings)
- Updated `idleApp.swift` — UIApplicationDelegateAdaptor, environment injection, onOpenURL
- Updated `Info.plist` — CarPlay scene config, audio background mode, idle:// URL scheme
- Updated `idle.entitlements` — carplay-audio, App Group group.com.steverogers.idle

### Phase 2: Core Plugin Architecture & Data Models ✅
- Created `Services/VideoServicePlugin.swift` — @MainActor protocol
- Created `Services/ServiceRegistry.swift` — @Observable, UserDefaults persistence
- Created `Queue/QueueItem.swift` — SwiftData @Model
- Created `Queue/QueueManager.swift` — @Observable queue + history CRUD

### Phase 3: iPhone UI Shell ✅
- Created `Views/ServicesView.swift` — service list, toggles, drag reorder
- Created `Views/QueueView.swift` — URL paste, queue list, history section
- Created `Views/SettingsView.swift` — app info, GDM toggle, service links
- Updated `Views/MainView.swift` — wired real screens into TabView

### Phase 4: Plex Authentication ✅
- Created `Networking/PlexAPI.swift` — actor, PIN auth, home users, server discovery, library
- Created `Networking/KeychainHelper.swift` — Keychain CRUD wrapper
- Created `Views/Plex/PlexAuthView.swift` — PIN display + polling
- Created `Views/Plex/PlexUserPickerView.swift` — multi-user picker + passcode
- Created `Services/PlexService.swift` — VideoServicePlugin conformance

### Phase 5: Plex Library Browsing (iPhone) ✅
- Extended `PlexAPI.swift` — sections, on deck, recently added, seasons, episodes, thumbnails
- Created `Views/Plex/PlexLibraryView.swift` — NavigationStack with horizontal rows
- Created `Views/Plex/PlexMediaRow.swift` — horizontal AsyncImage scroll
- Created `Views/Plex/PlexDetailView.swift` — detail + play button + children drill-down

### Phase 6: CarPlay Scene Setup ✅
- Created `CarPlay/CarPlaySceneDelegate.swift` — CPTemplateApplicationSceneDelegate
- Created `CarPlay/CarPlayTabManager.swift` — CPTabBarTemplate from enabled services
- Created `CarPlay/CarPlaySettingsTemplate.swift` — CPListTemplate settings screen

### Phase 7: CarPlay Plex Browsing ✅
- Created `CarPlay/PlexCarPlayTemplateBuilder.swift` — CPListTemplate drill-down builder
- Created `CarPlay/CarPlayImageLoader.swift` — async thumbnail loading + NSCache

### Phase 8: Playback Engine ✅
- Created `Playback/PlaybackEngine.swift` — @Observable AVPlayer, external playback, audio session
- Created `Playback/NowPlayingManager.swift` — MPNowPlayingInfoCenter + MPRemoteCommandCenter
- Created `Extraction/ExtractionRouter.swift` — URL → strategy router
- Created `Extraction/GenericExtractor.swift` — direct URL pass-through
- Created `Extraction/YouTubeExtractor.swift` — YouTube URL pattern matching

### Phase 9: WKWebView YouTube Fallback ✅
- Created `Playback/WebViewPlayer.swift` — UIViewRepresentable WKWebView + JS injection
- Created `Views/PlayerView.swift` — unified player view (AVPlayer or WKWebView)

### Phase 10: Share Sheet Extension ✅ (files created; manual Xcode target required)
- Created `idleShare/ShareViewController.swift` — URL extraction + App Group handoff
- Created `idleShare/Info.plist` — NSExtensionActivationSupportsWebURLWithMaxCount: 1
- Created `App/URLSchemeHandler.swift` — handles idle://queue/add?url=...

### Phase 11: Queue & History Persistence ✅
- Wired full CRUD in `QueueManager.swift` with sort order management
- Updated `Views/QueueView.swift` — drag reorder, delete, tap-to-replay
- Updated `CarPlay/CarPlayTabManager.swift` — queue tab visibility logic

### Phase 12: Plex GDM Advertising ✅
- Created `Networking/PlexGDM.swift` — UDP multicast listener, M-SEARCH responder
- Created `Networking/PlexCompanionServer.swift` — HTTP server for cast commands
- Created `Detection/IdleDetector.swift` — stub for future CoreLocation parked detection

---

## Pending Items

### Manual Xcode Steps Required
- [x] **Share Extension target**: File > New > Target > Share Extension named "idleShare" ✅

### Info.plist Additions Required
- [ ] `NSLocalNetworkUsageDescription` — Required for Plex GDM UDP multicast (iOS 14+)
  - Suggested text: "idle needs local network access to discover Plex clients and advertise as a cast target."
- [ ] `NSLocationWhenInUseUsageDescription` — Required for future parked detection
  - Suggested text: "idle uses your location to detect when you're parked and unlock full video playback."

### Future Features (deferred per SPEC)
- [ ] Parked/idle detection via CoreLocation speed (IdleDetector.swift stub ready)
- [ ] Additional service plugins (YouTube direct, Jellyfin, Emby)
- [ ] Full-screen video lock when parked
- [ ] Apply for CarPlay audio entitlement: https://developer.apple.com/contact/carplay

### Testing
- [ ] Test Plex PIN auth + library browse on real device or simulator
- [ ] Test CarPlay flow in Xcode CarPlay Simulator (side-by-side iPhone + CarPlay)
- [ ] Test share sheet from Safari → appears in queue
- [ ] Test YouTube WKWebView playback + theater mode JS injection
- [ ] Test external display routing (AVPlayer → CarPlay screen)

---

## Build Status

**Last build: SUCCEEDED — 0 errors, 1 acceptable Swift 6 migration warning**

Remaining warning (acceptable, not an error):
```
Conformance of 'PlexService' to protocol 'VideoServicePlugin' crosses into
main actor-isolated code and can cause data races; this is an error in the
Swift 6 language mode
```
Both the protocol and class are @MainActor, so it's safe at runtime. This is a known Swift 6 migration diagnostic.
