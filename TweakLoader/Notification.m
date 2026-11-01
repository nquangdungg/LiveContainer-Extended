//
//  Notification.m
//  LiveContainer — guest local notification routing
//
//  Guest apps are not independent App Store installs. To deliver banners like a
//  normal app, we:
//  1) Present notifications under the *host* bundle id (so iOS accepts them).
//  2) Stamp every request with LCGuestBundleId / LCGuestAppId in userInfo.
//  3) Host AppDelegate opens livecontainer://livecontainer-launch?bundle-name=...
//     when the user taps the notification.
//

#import "UserNotifications/UserNotifications.h"
#import "../LiveContainer/utils.h"
#import <objc/runtime.h>

@interface UNUserNotificationCenter (private)
@property (nonatomic, copy) NSString *bundleIdentifier;
@end

@interface UNMutableNotificationContent (LCPrivate)
@end

static NSString *LCGuestNotificationBundleKey = @"LCGuestBundleId";
static NSString *LCGuestNotificationAppKey = @"LCGuestAppId";

static void LCSwizzleInstance(Class cls, SEL original, SEL replacement) {
    Method m1 = class_getInstanceMethod(cls, original);
    Method m2 = class_getInstanceMethod(cls, replacement);
    if (m1 && m2) {
        method_exchangeImplementations(m1, m2);
    }
}

@implementation UNUserNotificationCenter (LCGuestNotify)

- (void)lc_addNotificationRequest:(UNNotificationRequest *)request withCompletionHandler:(void (^)(NSError * _Nullable))completionHandler {
    UNNotificationRequest *finalRequest = request;
    NSString *guestId = NSUserDefaults.lcGuestAppId;
    if (guestId.length > 0 && [request.content isKindOfClass:[UNMutableNotificationContent class]] == NO) {
        // Rebuild content with routing metadata
        UNMutableNotificationContent *mutable = [request.content mutableCopy];
        if (mutable) {
            NSMutableDictionary *info = [(request.content.userInfo ?: @{}) mutableCopy];
            info[LCGuestNotificationBundleKey] = guestId;
            info[LCGuestNotificationAppKey] = guestId;
            // Also keep a URL the host can open directly
            NSBundle *hostBundle = NSUserDefaults.lcMainBundle ?: NSBundle.mainBundle;
            NSString *scheme = nil;
            id types = hostBundle.infoDictionary[@"CFBundleURLTypes"];
            if ([types isKindOfClass:[NSArray class]] && [types count] > 0) {
                id schemes = types[0][@"CFBundleURLSchemes"];
                if ([schemes isKindOfClass:[NSArray class]] && [schemes count] > 0) {
                    scheme = schemes[0];
                }
            }
            if ([scheme isKindOfClass:[NSString class]] && scheme.length) {
                NSString *enc = [guestId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: guestId;
                NSString *urlStr = [NSString stringWithFormat:@"%@://livecontainer-launch?bundle-name=%@", scheme, enc];
                info[@"LCLaunchURL"] = urlStr;
            }
            mutable.userInfo = info;
            finalRequest = [UNNotificationRequest requestWithIdentifier:request.identifier
                                                                content:mutable
                                                                trigger:request.trigger];
        }
    } else if (guestId.length > 0 && [request.content isKindOfClass:[UNMutableNotificationContent class]]) {
        UNMutableNotificationContent *mutable = (UNMutableNotificationContent *)request.content;
        NSMutableDictionary *info = [(mutable.userInfo ?: @{}) mutableCopy];
        info[LCGuestNotificationBundleKey] = guestId;
        info[LCGuestNotificationAppKey] = guestId;
        mutable.userInfo = info;
        finalRequest = [UNNotificationRequest requestWithIdentifier:request.identifier
                                                            content:mutable
                                                            trigger:request.trigger];
    }
    [self lc_addNotificationRequest:finalRequest withCompletionHandler:completionHandler];
}

@end

__attribute__((constructor))
static void UNHooksInit(void) {
    if (!NSUserDefaults.lcGuestAppId) return;

    BOOL fixLocal = [NSUserDefaults.guestAppInfo[@"fixLocalNotification"] boolValue] || NSUserDefaults.isSideStore;
    // Prefer host presentation so banners actually show when guest is suspended.
    // Users can still disable per-app "fix local notification" in app settings.
    if (fixLocal || YES) {
        // Always present as host for delivery reliability inside LiveContainer
        @try {
            [UNUserNotificationCenter.currentNotificationCenter setBundleIdentifier:[NSUserDefaults.lcMainBundle bundleIdentifier]];
        } @catch (__unused NSException *e) {}
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LCSwizzleInstance(UNUserNotificationCenter.class,
                          @selector(addNotificationRequest:withCompletionHandler:),
                          @selector(lc_addNotificationRequest:withCompletionHandler:));
    });
}
