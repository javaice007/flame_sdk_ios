//
//  BannerVC.m
//  CJModileAdDemo
//
//  Created by CJ on 2022/3/7.
//

#import "BannerVC.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CustomShowView.h"
#import "CJMobilePublic.h"

@interface BannerVC ()<CJBannerAdDelegate>

@property (nonatomic,strong) CJBannerAd *bannerAd;

@property (nonatomic, strong) UIView *bannerView;

@end

@implementation BannerVC

@synthesize customView = _customView;
    
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)dealloc
{
    NSLog(@"the page of banner delloc");
}

- (void)setupUI {
    self.title = @"Banner";
    [self.view addSubview:self.customView];
    self.customView.frame = CGRectMake(0, 100, 200, 200);
    self.customView.center = self.view.center;
}

- (void)loadAdData {
    [self.customView canShowStatus:false errorMsg:@""];
    // 50:320 固定比例，如果测试ID出现展示不全的情况，是不适配新版本sdk的问题，正式ID不会出现哈
    self.bannerAd = [[CJBannerAd alloc] initWithResourceId:bannerId rootViewController:self rect:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width*50/320)];
    [self.bannerAd loadAdData];
    self.bannerAd.delegate = self;
}

- (void)handleEvent:(NSInteger)eve {
    if (eve == 0) {
        [self loadAdData];
        return;
    }
    CGRect frame = self.bannerView.frame;
    frame.origin.y = 88;
    self.bannerView.frame = frame;
    [self.view addSubview:self.bannerView];
}

- (CustomShowView *)customView {
    if (!_customView) {
        _customView = [[CustomShowView alloc] init];
        __weak BannerVC *weakSelf = self;
        _customView.event = ^(NSInteger eve) {
            [weakSelf handleEvent:eve];
        };
    }
    return _customView;
}

#pragma mark CJBannerAdDelegate

- (void)bannerAdDidLoad:(UIView *)bannerView resourceId:(NSString *)resourceId {
    NSLog(@"load success");
    self.bannerView = bannerView;
    [self.customView canShowStatus:true errorMsg:@""];
}

- (void)bannerAdLoadFailed:(id)bannerAd error:(NSError *)error{
    NSLog(@"load failed of error: %@", error);
    [self.customView canShowStatus:false errorMsg:error.description];
}

- (void)bannerAdOnClicked:(id)bannerAd {
    NSLog(@"click on the event");
}

- (void)bannerAdOnClosed:(id)bannerAd {
    NSLog(@"close on the event");
    [self.customView canShowStatus:false errorMsg:@""];
}

@end
