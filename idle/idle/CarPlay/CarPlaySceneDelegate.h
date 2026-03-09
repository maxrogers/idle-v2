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

@end

NS_ASSUME_NONNULL_END
