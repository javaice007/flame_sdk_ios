//
//  FlameNativeAdImpl.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/23.
//
#import <Foundation/Foundation.h>
#import "FlameNativeAdImpl.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"


@implementation FlameNativeAdImpl

@synthesize placementId = _placementId;
@synthesize listener = _listener;
@synthesize adapter = _adapter; // 如果头文件里改了名，这里也需同步

- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameNativeListener>)listener
                              adapter:(id<FlameNativeAdapterProtocol>)adapter{
    self = [super init];
    if (self) {
        _viewController = viewController;
        _placementId = [placementId copy];
        _listener = listener;
        _adapter = adapter;
        _renderType = FlameNativeRenderTypeSelfRender;
        [_adapter setRenderType:_renderType];
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
    if (![FlameAdapterManager checkInitialization]) return;

    [FlameLogger i:@"Start loading native Ad"];

    [self.adapter loadWithUserId:userId userCustomData:userCustomData width:width height:height];
}

- (BOOL)isLoading {
    if (![FlameAdapterManager checkInitialization]) return NO;
    return [self.adapter isLoading];
}

- (BOOL)isReady {
    if (![FlameAdapterManager checkInitialization]) return NO;
    return [self.adapter isReady];
}

- (void)showInContainer:(id)container {
    if ([self isReady]) {
        [FlameLogger i:@"Show Native Ad"];
        [self.adapter showInContainer:container];
    } else {
        [FlameLogger i:@"Native Ad is not ready to show"];
    }
}

- (void)setRenderType:(FlameNativeRenderType)renderType {
    _renderType = renderType;
    [self.adapter setRenderType:renderType];
    [FlameLogger i:[NSString stringWithFormat:@"Set Native Ad render type: %@",
                    renderType == FlameNativeRenderTypeExpress ? @"Express" : @"SelfRender"]];
}

- (void)destroy {
    if (![FlameAdapterManager checkInitialization]) return;
    [self.adapter destroy];
}

- (void)remove {
    if (![FlameAdapterManager checkInitialization]) return;
    return [self.adapter remove];
}

@end
