#import "CarPlaySceneDelegate.h"
#import "idle-Swift.h"

@implementation CarPlaySceneDelegate

// MARK: - CPTemplateApplicationSceneDelegate

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
       didConnectInterfaceController:(CPInterfaceController *)interfaceController {
    self.interfaceController = interfaceController;
    interfaceController.delegate = self;
    [CarPlayBridge didConnectWithInterfaceController:interfaceController delegate:self];
}

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
didDisconnectInterfaceController:(CPInterfaceController *)interfaceController {
    [CarPlayBridge didDisconnect];
    self.interfaceController = nil;
}

// MARK: - CPInterfaceControllerDelegate

- (void)templateWillAppear:(CPTemplate *)aTemplate animated:(BOOL)animated {}
- (void)templateDidAppear:(CPTemplate *)aTemplate animated:(BOOL)animated {}
- (void)templateWillDisappear:(CPTemplate *)aTemplate animated:(BOOL)animated {}
- (void)templateDidDisappear:(CPTemplate *)aTemplate animated:(BOOL)animated {}

@end
