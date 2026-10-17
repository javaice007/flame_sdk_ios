//
//  FullscreenVC.m
//  CJModileAdDemo
//
//  Created by CJ on 2022/3/7.
//

#import "FullscreenVC.h"
#import "CustomShowView.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CJMobilePublic.h"

@interface FullscreenVC ()<CJFullscreenVideoAdDelegate>

@property (nonatomic, strong) CJFullscreenVideoAd *fullscreenAd;

@end

@implementation FullscreenVC

@synthesize customView = _customView;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)dealloc
{
    NSLog(@"the page of fullscreenVideo delloc");
}

- (void)loadAdData {
    [self.customView canShowStatus:false errorMsg:@""];
    self.fullscreenAd = [[CJFullscreenVideoAd alloc] initWithResourceId:fullscreenVideoId];
    self.fullscreenAd.delegate = self;
    [self.fullscreenAd loadAdData];
}

- (void)setupUI {
    self.title = @"FullscreenVideoAd";
    [self.view addSubview:self.customView];
    self.customView.frame = CGRectMake(0, 100, 200, 200);
    self.customView.center = self.view.center;
}

- (void)handleEvent:(NSInteger)eve {
    if (eve == 0) {
        [self loadAdData];
        return;
    }
    [self.fullscreenAd showFromRootViewController:self];
}

- (CustomShowView *)customView {
    if (!_customView) {
        _customView = [[CustomShowView alloc] init];
        __weak FullscreenVC *weakSelf = self;
        _customView.event = ^(NSInteger eve) {
            [weakSelf handleEvent:eve];
        };
    }
    return _customView;
}

#pragma mark CJFullscreenVideoAdDelegate
- (void)fullscreenVideoAdDidLoad:(CJFullscreenVideoAd *)fullscreenAd resourceId:(NSString *)resourceId {
    NSLog(@"load success");
    [self.customView canShowStatus:true errorMsg:@""];
}

- (void)fullscreenVideoAdLoadFailed:(CJFullscreenVideoAd *)fullscreenAd error:(NSError *)error {
    NSLog(@"load failed of error: %@", error);
    [self.customView canShowStatus:false errorMsg:error.description];
}

- (void)fullscreenVideoAdOnClicked:(CJFullscreenVideoAd *)fullscreenAd {
    NSLog(@"click on the event");
}

- (void)fullscreenVideoAdOnClosed:(CJFullscreenVideoAd *)fullscreenAd {
    NSLog(@"close on the event");
    [self.customView canShowStatus:false errorMsg:@""];
}

@end
