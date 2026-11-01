#import <AudioToolbox/AudioToolbox.h>
//
//  LCStatusBarManager.m
//  LiveContainer — ONE tap status bar / fake bar exit
//

#import "LCStatusBarManager.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "VirtualWindowsHostView.h"
#import "DecoratedAppSceneViewController.h"

@interface UIView (LCStatusBarPrivate)
- (UIViewController *)_viewDelegate;
@end

static BOOL LCExitOnStatusBarTapEnabled(void) {
    Class sharedUtilsClass = NSClassFromString(@"LCSharedUtils");
    NSString *appGroupId = nil;
    if ([sharedUtilsClass respondsToSelector:@selector(appGroupID)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        appGroupId = [sharedUtilsClass performSelector:@selector(appGroupID)];
#pragma clang diagnostic pop
    }
    NSUserDefaults *defaults = appGroupId
        ? [[NSUserDefaults alloc] initWithSuiteName:appGroupId]
        : [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"LCDoubleTapStatusBarToExit"] != nil) {
        return [defaults boolForKey:@"LCDoubleTapStatusBarToExit"];
    }
    return YES;
}

static void LCHapticTap(void) {
    AudioServicesPlaySystemSound(1519);
    AudioServicesPlaySystemSound(1520);
    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [gen prepare];
    [gen impactOccurred];
}

@implementation LCStatusBarManager

- (void)handleTapAction:(UIAction *)action {
    if (!LCExitOnStatusBarTapEnabled()) {
        [self lc_forwardSingleTap:action];
        return;
    }
    // Exactly one tap → haptic → exit. No debounce, no second-tap window.
    LCHapticTap();
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf lc_exitGuest];
    });
}

- (void)lc_forwardSingleTap:(UIAction *)action {
    if (self.nativeWindowViewController) {
        [self.nativeWindowViewController handleStatusBarTapAction:action];
        return;
    }
    BOOL handledByVirtualWindow = [MultitaskDockManager.shared.windowHostingView handleStatusBarTapAction:action];
    if (!handledByVirtualWindow) {
        [super handleTapAction:action];
    }
}

- (void)lc_exitGuest {
    if (self.nativeWindowViewController) {
        [self.nativeWindowViewController terminate];
        return;
    }

    VirtualWindowsHostView *host = MultitaskDockManager.shared.windowHostingView;
    if (host) {
        for (UIView *sub in [host.subviews reverseObjectEnumerator]) {
            if (sub.hidden || sub.alpha < 0.05) continue;
            id decorated = [sub _viewDelegate];
            if (decorated && [decorated respondsToSelector:@selector(closeWindow)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [decorated performSelector:@selector(closeWindow)];
#pragma clang diagnostic pop
                return;
            }
            if ([decorated isKindOfClass:[DecoratedAppSceneViewController class]]) {
                AppSceneViewController *sceneVC = [(DecoratedAppSceneViewController *)decorated appSceneVC];
                if (sceneVC) {
                    [sceneVC terminate];
                    return;
                }
            }
        }
    }

    Class sharedUtils = NSClassFromString(@"LCSharedUtils");
    if ([sharedUtils respondsToSelector:@selector(launchToGuestAppWithClassicMode:)]) {
        [sharedUtils launchToGuestAppWithClassicMode:0];
    }
}

@end

@implementation UIApplication (LiveContainer)
+ (Class)_statusBarManagerClass {
    if (@available(iOS 16.0, *)) {
        return [LCStatusBarManager class];
    } else {
        return [UIStatusBarManager class];
    }
}
@end
