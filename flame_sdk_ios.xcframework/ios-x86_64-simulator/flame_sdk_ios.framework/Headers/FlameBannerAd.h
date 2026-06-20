//
//  FlameBannerAd.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FlameBannerAdMaterial;
@class FlameBannerAdRenderSlots;

/**
 * Banner 广告渲染模式
 *   - Express: 模板渲染（SDK 返回预渲染视图）
 *   - SelfRender: 自渲染（开发者消费素材并绑定合规插槽）
 */
typedef NS_ENUM(NSInteger, FlameBannerRenderType) {
    FlameBannerRenderTypeExpress = 1,
    FlameBannerRenderTypeSelfRender = 2,
};

/**
 * Flame 横幅广告回调协议
 */
@protocol FlameBannerListener <NSObject>

@optional

- (void)onAdLoaded;

- (void)onAdError:(NSString *)code desc:(NSString *)desc;

- (void)onAdShow;

- (void)onAdClicked;

- (void)onAdClosed;

- (void)onAdMaterialReady:(NSArray<FlameBannerAdMaterial *> *)materials;

@end

@protocol FlameBannerAd <NSObject>

- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height
       viewController:(UIViewController *)viewController;

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
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
