//
//  FlameBannerAdImpl.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/21.
//
#import <Foundation/Foundation.h>
#import "FlameBannerAdImpl.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"

@implementation FlameBannerAdImpl

@synthesize placementId = _placementId;
@synthesize listener = _listener;
@synthesize adapter = _adapter; // 如果头文件里改了名，这里也需同步

- (nonnull instancetype)initWithPlacementId:(nonnull NSString *)placementId
                                   listener:(nonnull id<FlameBannerListener>)listener {
    
    self = [super init];
    if (self) {
        _placementId = [placementId copy];
        _listener = listener;
        // 调用 AdapterManager 创建横幅适配器
        _adapter = [FlameAdapterManager createBannerAdapter:placementId
                                                   listener:listener];
    }
    return self;
}

/**
 * 加载广告
 * @param width 宽度
 * @param height 高度
 */
- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height{
    [self loadWithUserId:nil userCustomData:nil width:width height:height];
}

/**
 * 加载广告（带用户信息）
 * @param userId 用户 ID
 * @param userCustomData 用户自定义数据
 * @param width 宽度
 * @param height 高度
 */
- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height{
    [FlameAdapterManager checkInitialization];

    if ([self.adapter isLoading]) {
        [FlameLogger i:@"Ad is loading, please do not request again."];
        return;
    }
    
    [FlameLogger i:@"Start loading banner Ad"];

    [self.adapter loadWithUserId:userId userCustomData:userCustomData width:width height:height];
}

- (BOOL)isLoading {
    [FlameAdapterManager checkInitialization];
    return [self.adapter isLoading];
}

- (BOOL)isReady { 
    [FlameAdapterManager checkInitialization];
    return [self.adapter isReady];
}

- (UIView *)retrieveAdView {
    // 1. 检查是否准备好
    if ([self isReady]) {
        [FlameLogger i:@"Show Banner Ad"];
        // 2. 获取真正的广告 View
        // 注意：这里应该是调用 TopOn SDK 的方法，或者是调用底层具体的适配器实例
        UIView *adView = [self.adapter retrieveAdView];
        
        if (adView) {
            return adView; // 成功获取，直接返回，不再执行后面的代码
        } else {
            [FlameLogger i:@"Banner Ad is ready but retrieved a nil view."];
        }
    }
    
    // 3. 只有 Ready 失败或获取失败才会走到这里
    [FlameLogger i:@"Banner Ad is not ready or failed to load."];
    return nil;
}

- (void) remove {
    [FlameAdapterManager checkInitialization];
    return [self.adapter remove];
}

- (void)destroy {
    [FlameAdapterManager checkInitialization];
    [self.adapter destroy];
}

@end
