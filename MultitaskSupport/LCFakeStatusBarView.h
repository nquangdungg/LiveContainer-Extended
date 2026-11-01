//
//  LCFakeStatusBarView.h
//  LiveContainer — decorative status bar; tap-to-exit for guest apps
//
#import <UIKit/UIKit.h>

@interface LCFakeStatusBarView : UIView
@property (nonatomic, copy, nullable) void (^onTapExit)(void);
- (void)startUpdating;
- (void)stopUpdating;
@end
