//
//  FlameDrawAdImpl.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/27.
//
#import <Foundation/Foundation.h>
#import "FlameDrawAdImpl.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"

@implementation FlameDrawAdImpl

@synthesize viewController = _viewController;
@synthesize placementId = _placementId;
@synthesize listener = _listener;
@synthesize adapter = _adapter; // 如果头文件里改了名，这里也需同步

- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameDrawListener>)listener {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _placementId = [placementId copy];
        _listener = listener;
        // 调用 AdapterManager 适配器
        _adapter = [FlameAdapterManager createDrawAdapter:viewController
                                            atPlacementId:placementId
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

//    if ([self.adapter isLoading]) {
//        [FlameLogger i:@"Ad is loading, please do not request again."];
//        return;
//    }
    
    NSString *logMsg = [NSString stringWithFormat:@"Start loading draw Ad for PlacementId: %@", self.placementId];
    [FlameLogger i:logMsg];

    [self.adapter loadWithUserId:userId userCustomData:userCustomData width:width height:height];
}

- (BOOL)isReady {
    [FlameAdapterManager checkInitialization];
    return [self.adapter isReady];
}

- (BOOL)isLoading {
    [FlameAdapterManager checkInitialization];
    return [self.adapter isLoading];
}


- (void)showInContainer:(UIView *)container
        contentPlayhead:(id)playhead {
    if ([self isReady]) {
        [FlameLogger i:[NSString stringWithFormat:@"Show Draw Ad for PlacementId: %@", self.placementId]];
        [self.adapter showInContainer:container contentPlayhead:playhead];
    } else {
        NSString *logMsg = [NSString stringWithFormat:@"Draw Ad is not ready to show for PlacementId: %@", self.placementId];
        [FlameLogger i:logMsg];
    }
}

- (void)destroy {
    [FlameAdapterManager checkInitialization];
    [self.adapter destroy];
}

/**
 * 移除广告
 */
- (void)remove {
    [FlameAdapterManager checkInitialization];
    [self.adapter remove];
}

@end
