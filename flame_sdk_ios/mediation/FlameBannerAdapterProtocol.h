//
//  FlameBannerAdapterProtocol.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FlameBannerAd.h"
#import "FlameBannerAdMaterial.h"
#import "FlameBannerAdRenderSlots.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 内部横幅适配器协议
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * FlameBannerAdImpl 内部持有 id<FlameBannerAdapterProtocol>，
 * 通过此协议转发 load / retrieveAdView / bindMaterial / destroy 等调用，
 * 不直接依赖具体平台适配器（AtBannerAdapter / TbBannerAdapter 等）。
 */
@protocol FlameBannerAdapterProtocol <NSObject>

@required

- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height
       viewController:(UIViewController *)viewController;

- (void)loadWithUserId:(nullable NSString *)userId
        userCustomData:(nullable NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height
        viewController:(UIViewController *)viewController;

- (BOOL)isReady;

- (BOOL)isLoading;

- (nullable UIView *)retrieveAdView;

- (NSArray<FlameBannerAdMaterial *> *)retrieveMaterials;

- (void)bindMaterialAtIndex:(NSInteger)index
                      slots:(FlameBannerAdRenderSlots *)slots;

- (void)unbindMaterial;

- (void)remove;

- (void)destroy;

@end

NS_ASSUME_NONNULL_END
