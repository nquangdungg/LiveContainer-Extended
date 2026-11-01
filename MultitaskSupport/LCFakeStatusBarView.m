//
//  LCFakeStatusBarView.m
//
#import "LCFakeStatusBarView.h"

@interface LCFakeStatusBarView ()
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *batteryLabel;
@property (nonatomic, strong) UIImageView *batteryIcon;
@property (nonatomic, strong) UIImageView *signalIcon;
@property (nonatomic, strong) UIImageView *wifiIcon;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation LCFakeStatusBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;

        _timeLabel = [UILabel new];
        _timeLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _timeLabel.textColor = [UIColor labelColor];
        _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_timeLabel];

        _signalIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"cellularbars"]];
        _signalIcon.tintColor = [UIColor labelColor];
        _signalIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_signalIcon];

        _wifiIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"wifi"]];
        _wifiIcon.tintColor = [UIColor labelColor];
        _wifiIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_wifiIcon];

        _batteryIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"battery.100"]];
        _batteryIcon.tintColor = [UIColor labelColor];
        _batteryIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_batteryIcon];

        _batteryLabel = [UILabel new];
        _batteryLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _batteryLabel.textColor = [UIColor labelColor];
        _batteryLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_batteryLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_timeLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [_timeLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [_batteryLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18],
            [_batteryLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

            [_batteryIcon.trailingAnchor constraintEqualToAnchor:_batteryLabel.leadingAnchor constant:-4],
            [_batteryIcon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_batteryIcon.widthAnchor constraintEqualToConstant:22],
            [_batteryIcon.heightAnchor constraintEqualToConstant:12],

            [_wifiIcon.trailingAnchor constraintEqualToAnchor:_batteryIcon.leadingAnchor constant:-8],
            [_wifiIcon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_wifiIcon.widthAnchor constraintEqualToConstant:16],
            [_wifiIcon.heightAnchor constraintEqualToConstant:12],

            [_signalIcon.trailingAnchor constraintEqualToAnchor:_wifiIcon.leadingAnchor constant:-6],
            [_signalIcon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_signalIcon.widthAnchor constraintEqualToConstant:18],
            [_signalIcon.heightAnchor constraintEqualToConstant:12],
        ]];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        tap.numberOfTapsRequired = 1;
        [self addGestureRecognizer:tap];

        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [self refresh];
    }
    return self;
}

- (void)startUpdating {
    [self stopUpdating];
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:15.0 repeats:YES block:^(__unused NSTimer *t) {
        [weakSelf refresh];
    }];
}

- (void)stopUpdating {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)refresh {
    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateFormat = @"H:mm";
    self.timeLabel.text = [fmt stringFromDate:[NSDate date]];

    float level = [UIDevice currentDevice].batteryLevel;
    if (level < 0) level = 1.0;
    int pct = (int)roundf(level * 100.0f);
    self.batteryLabel.text = [NSString stringWithFormat:@"%d%%", pct];

    NSString *batName = @"battery.100";
    if (pct <= 15) batName = @"battery.25";
    else if (pct <= 40) batName = @"battery.50";
    else if (pct <= 70) batName = @"battery.75";
    self.batteryIcon.image = [UIImage systemImageNamed:batName];
}

- (void)handleTap {
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen prepare];
    [gen impactOccurred];
    if (self.onTapExit) {
        self.onTapExit();
    }
}

- (void)dealloc {
    [self stopUpdating];
}

@end
