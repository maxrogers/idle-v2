# Lessons Learned

(Claude will automatically add self-improvement rules here after any correction)

---

## Swift Concurrency & Actor Isolation

### SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor breaks Codable in actors
**Problem:** When the project has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in build settings,
all struct/class Codable conformances become MainActor-isolated. This causes compile errors when
trying to decode them inside an `actor` (which runs on its own executor, not MainActor).

**Fix:** Move Codable model structs into a dedicated file (e.g., `PlexModels.swift`) and annotate
each with `nonisolated`:
```swift
nonisolated struct PlexMediaItem: Codable, Identifiable, Sendable { ... }
```
`nonisolated` opts the struct out of the default MainActor isolation, making Codable conformances
work without actor context restrictions.

**What doesn't work:**
- `@preconcurrency import Foundation` — only suppresses warnings on pre-existing APIs, not struct conformances
- Adding `Sendable` constraints on generic container types — cascades into more Sendable errors

---

### VideoServicePlugin Sendable conformance warning
**Problem:** `PlexService: VideoServicePlugin` conformance emits a Swift 6 warning:
"Conformance of 'PlexService' to protocol 'VideoServicePlugin' crosses into main actor-isolated code"

**Fix:** Mark the class `@unchecked Sendable` and add `@preconcurrency import CarPlay`:
```swift
final class PlexService: VideoServicePlugin, @unchecked Sendable { ... }
```
Both the protocol and class are `@MainActor`, so this is safe at runtime.

---

### UIKit APIs inside actors require workarounds
**Problem:** Calling `UIDevice.current.model` or `UIDevice.current.name` inside an `actor` body
fails in Swift 6 because UIDevice is MainActor-isolated and actors run on their own executor.

**Fix:** Use static strings or move the call to a `@MainActor` method:
```swift
// Instead of UIDevice.current.model:
let deviceModel = "iPhone"
let deviceName = "idle"
```
If you need the actual device name, capture it before entering the actor context.

---

### KVO observer Task captures
**Problem:** Using `[self]` capture in a Task inside a KVO observer causes:
"mutation of captured var 'self' in concurrently-executing code"

**Fix:** Extract the value before the Task and use `[weak self]`:
```swift
let isExternal = change?[.newKey] as? Bool ?? false
Task { [weak self] in
    await MainActor.run { self?.isExternalPlaybackActive = isExternal }
}
```

---

## CarPlay APIs

### CPTemplateApplicationSceneDelegate disconnect method signature
**Wrong:**
```swift
func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                               didDisconnect interfaceController: CPInterfaceController) { }
```
**Correct:**
```swift
func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                               didDisconnectInterfaceController interfaceController: CPInterfaceController) { }
```
The parameter label is `didDisconnectInterfaceController:`, not `didDisconnect:`.
Xcode will not warn you about the wrong label — it just silently never calls the method.

---

### No CarPlay video entitlement exists
There is no `com.apple.developer.carplay-video` entitlement. The correct approach for a video
app on CarPlay is:
1. Use `com.apple.developer.carplay-audio` entitlement
2. Use CPTabBarTemplate + CPListTemplate for browsing UI
3. Use `AVPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true` for video routing

This automatically routes AVPlayer video output to the CarPlay display when connected.

---

### CPTabBarTemplate tab limit
CarPlay tab bars are limited to 5 tabs maximum. Design tab allocation carefully:
- Reserve lowest-priority tab for Settings (first to be dropped if over limit)
- Show Queue tab only when queue is non-empty
- Service plugins provide their own tab, so plan for 4 max (1 settings + 3 services or queue)

---

## SwiftUI

### Array.move(fromOffsets:toOffset:) requires SwiftUI import
`move(fromOffsets:toOffset:)` on `Array` is a SwiftUI extension, not a Foundation method.
Files that use it (including non-View files like managers/services) must `import SwiftUI`.

This is easy to miss in service/manager files that don't seem SwiftUI-related.

---

### preferredColorScheme is a View modifier, not Scene modifier
**Wrong:**
```swift
WindowGroup { ... }
    .preferredColorScheme(.dark)  // ❌ not valid on Scene
```
**Correct:**
```swift
WindowGroup {
    MainView()
        .preferredColorScheme(.dark)  // ✅ on View
}
```

---

## Xcode Project Structure

### PBXFileSystemSynchronizedRootGroup (Xcode 16+)
Projects using `PBXFileSystemSynchronizedRootGroup` automatically include any `.swift` file
placed under the source directory in the build. No need to edit `.pbxproj` to add source files.

Just create the file at the correct path and it's in the build. This dramatically simplifies
multi-file code generation sessions.

---

### Share Extension targets cannot be created programmatically
File > New > Target > Share Extension must be done manually in Xcode's UI. There is no
programmatic way to add a new target to a project.

**Workflow:** Create all extension source files first (ShareViewController.swift, Info.plist),
then instruct user to create the target manually and point it at the existing files.

---

## Plex API

### Plex PIN authentication flow
1. POST `https://plex.tv/api/v2/pins` → get `{ id, code }`
2. Display `code` to user (format as "XXXX XXXX" for readability)
3. Poll GET `https://plex.tv/api/v2/pins/{id}` every 2s until `authToken` is non-nil
4. Use `authToken` for all subsequent API calls as `X-Plex-Token` header

PIN expires after 5 minutes (~150 polls at 2s interval).

---

### Plex thumbnail URL construction
Thumbnails use a transcoder endpoint, not a direct path:
```
{serverURL}/photo/:/transcode?url={encodedThumbPath}&X-Plex-Token={token}&width=300&height=450
```
The `thumbPath` from the API (e.g., `/library/metadata/123/thumb/...`) must be URL-encoded.
Mark this method `nonisolated` if building it inside a PlexAPI actor — it's pure URL construction.

---

### Plex server connection selection
`getServers()` returns multiple connections per server (local, remote, relay).
Best practice: prefer local connections that are non-relay for lowest latency:
```swift
server.connections.first(where: { !$0.relay }) ?? server.connections.first
```

---

## App Architecture

### Multi-scene shared state via AppDelegate
Both iPhone WindowGroup scene and CarPlay CPTemplateApplicationScene need shared state
(ServiceRegistry, QueueManager, PlaybackEngine).

Best pattern: hold all shared state as properties on `AppDelegate` (created once, lives for the
app's entire lifetime):
```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    let serviceRegistry = ServiceRegistry()
    let queueManager = QueueManager()
    let playbackEngine = PlaybackEngine()
}
```
Access from any scene: `(UIApplication.shared.delegate as? AppDelegate)?.serviceRegistry`

---

### Share Extension → Main App IPC
Two-part handoff:
1. **App Groups shared UserDefaults**: Write URL to `UserDefaults(suiteName: "group.com.steverogers.idle")`
2. **URL scheme**: Open `idle://queue/add?url=...` to activate main app and trigger processing

The main app reads from shared UserDefaults on `onOpenURL` and on `sceneWillEnterForeground`.
