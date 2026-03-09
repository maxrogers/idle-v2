#import "CarPlaySceneDelegate.h"
#import "idle-Swift.h"

@implementation CarPlaySceneDelegate

// MARK: - CPTemplateApplicationSceneDelegate

// iOS 14+ non-navigation variant (no window)
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
   didConnectInterfaceController:(CPInterfaceController *)interfaceController {
    self.interfaceController = interfaceController;
    interfaceController.delegate = self;
    [CarPlayBridge didConnectWithInterfaceController:interfaceController delegate:self];
}

// iOS 13+ navigation variant (with window) — implemented so iOS 26 runtime
// finds a matching selector regardless of which variant it checks first.
- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
   didConnectInterfaceController:(CPInterfaceController *)interfaceController
                        toWindow:(CPWindow *)window {
    self.interfaceController = interfaceController;
    interfaceController.delegate = self;
    [CarPlayBridge didConnectWithInterfaceController:interfaceController delegate:self];
}

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
didDisconnectInterfaceController:(CPInterfaceController *)interfaceController {
    [CarPlayBridge didDisconnect];
    self.interfaceController = nil;
}

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
didDisconnectInterfaceController:(CPInterfaceController *)interfaceController
                      fromWindow:(CPWindow *)window {
    [CarPlayBridge didDisconnect];
    self.interfaceController = nil;
}

// MARK: - CPInterfaceControllerDelegate

- (void)templateWillAppear:(CPTemplate *)aTemplate animated:(BOOL)animated {}
- (void)templateDidAppear:(CPTemplate *)aTemplate animated:(BOOL)animated {}
- (void)templateWillDisappear:(CPTemplate *)aTemplate animated:(BOOL)animated {}
- (void)templateDidDisappear:(CPTemplate *)aTemplate animated:(BOOL)animated {}

@end
