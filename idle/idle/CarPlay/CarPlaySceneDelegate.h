@import UIKit;
@import CarPlay;

NS_ASSUME_NONNULL_BEGIN

/// Objective-C scene delegate for CarPlay.
///
/// This class exists in Objective-C because SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor causes
/// Swift to wrap every Obj-C protocol IMP in an actor-executor check, making the CarPlay
/// runtime's selector lookup fail with "Application does not implement CarPlay template
/// application lifecycle methods in its scene delegate."
///
/// By implementing the protocol in plain Obj-C, we register bare IMPs with no Swift
/// concurrency wrapper. The delegate then calls back into Swift (CarPlayBridge) for logic.
@interface CarPlaySceneDelegate : UIResponder <CPTemplateApplicationSceneDelegate, CPInterfaceControllerDelegate>

@property (nonatomic, strong, nullable) CPInterfaceController *interfaceController;

// Explicitly declare both connect/disconnect variants so the CarPlay runtime's
// respondsToSelector: check succeeds regardless of which variant it checks.
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
   didConnectInterfaceController:(CPInterfaceController *)interfaceController;

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
   didConnectInterfaceController:(CPInterfaceController *)interfaceController
                        toWindow:(CPWindow *)window;

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
didDisconnectInterfaceController:(CPInterfaceController *)interfaceController;

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
didDisconnectInterfaceController:(CPInterfaceController *)interfaceController
                      fromWindow:(CPWindow *)window;

@end

NS_ASSUME_NONNULL_END
