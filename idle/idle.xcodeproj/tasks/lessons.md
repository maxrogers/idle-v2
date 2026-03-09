# Lessons Learned

## Swift 6 / Concurrency

### SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor + Codable structs in actors
**Problem:** When the build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set,
Codable conformances on structs become MainActor-isolated. This causes errors when
those structs are used as generic type parameters requiring `Sendable` in actor contexts.

**Rule:** Move all Codable model types to a dedicated file (e.g., `PlexModels.swift`)
and annotate each struct with `nonisolated` to explicitly opt out of the default isolation.
Do NOT use `@preconcurrency import Foundation` alone — it's not sufficient for struct conformances.

### VideoServicePlugin + Sendable
**Problem:** A `@MainActor` protocol cannot easily satisfy `Sendable` requirements because
adding `Sendable` to the protocol triggers Identifiable conformance issues.

**Rule:** Keep `VideoServicePlugin` without `Sendable`. Mark conforming classes as
`@unchecked Sendable` when needed. The `@MainActor` boundary provides safety.

### actor methods referencing MainActor UI types
**Problem:** `UIDevice.current.model` and `UIDevice.current.name` are `@MainActor`-isolated
and cannot be accessed from within a non-isolated `actor`.

**Rule:** Use static strings or capture device info before entering the actor context.
Avoid accessing UIKit APIs from within `actor` bodies.

## CarPlay

### CPTemplateApplicationSceneDelegate disconnect method
**Problem:** The disconnect delegate method signature is:
`templateApplicationScene(_:didDisconnectInterfaceController:)` NOT `didDisconnect:`.
Using the wrong label causes a "nearly matches optional requirement" warning.

**Rule:** Always verify exact CarPlay delegate method signatures against documentation.
The connect method uses `didConnect:`, disconnect uses `didDisconnectInterfaceController:`.

### CPTabBarTemplate
**Rule:** `CPTabBarTemplate` must be set as root template via `setRootTemplate`, not pushed.
Max tabs ~4-5 depending on screen. Settings tab always last in priority order.

## Architecture

### PBXFileSystemSynchronizedRootGroup
**Rule:** This project uses Xcode 26.4's file system sync. Swift files placed anywhere
under `/idle/idle/` are automatically included in the build. No pbxproj editing needed.
Exception: new targets (like Share Extension) still require manual Xcode UI steps.

### Share Extension target
**Rule:** Share Extension targets cannot be created programmatically via file writes alone.
Must use Xcode UI: File > New > Target > Share Extension.
The source files (ShareViewController.swift, Info.plist) can be pre-created and then
added to the target manually in Xcode.

### .move(fromOffsets:toOffset:) on Array
**Problem:** `Array.move(fromOffsets:toOffset:)` is defined in SwiftUI, not Foundation.
**Rule:** Files using array reordering must `import SwiftUI` even if they have no UI code.
