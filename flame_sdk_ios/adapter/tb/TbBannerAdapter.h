//
//  TbBannerAdapter.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// Phase 5A.16C：TB / ToBid / WindMill 横幅（Banner）适配器
// （与 TbRewardAdapter / TbInterstitialAdapter / TbSplashAdapter 同目录、同模式）
//
// 关键差异（与 Reward/Interstitial/Splash 不同，与 TK AtBannerAdapter 的 Express 模式一致）：
// - Banner 是长生命周期 UIView（WindMillBannerView : WindMillAdView : UIView）
// - 通过 retrieveAdView 返回 strong 持有的 WindMillBannerView，由上层（Demo BannerAdManager）addSubview
// - 自动刷新由 ToBid SDK/后台负责，Adapter 不新增 Timer（红线 #26/#27）
// - 首次 load 失败不内部重试（与 TK AtBannerAdapter 一致；Demo BannerAdManager.RetryScheduler 负责）
//
// 本阶段只实现 Express 模式（renderType == FlameBannerRenderTypeExpress）。
// SelfRender 模式（retrieveMaterials / bindMaterialAtIndex / unbindMaterial）返回空 / no-op + log，
// 不实现 ToBid 自渲染逻辑（Phase 5A.16C 范围外，红线 #11）。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FlameBannerAdapterProtocol.h"
#import "FlameBannerAd.h"

// WindMill SDK 前向声明（头文件不 import 第三方 SDK，避免模块解析失败）
@class WindMillBannerView;
@protocol WindMillBannerViewDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * TB / ToBid / WindMill 横幅适配器
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 职责：
 * - 实现 FlameBannerAdapterProtocol（内部协议）
 * - 实现 WindMillBannerViewDelegate（ToBid SDK delegate）
 * - 持有 WindMillBannerView 实例（长生命周期，auto-refresh 依赖该实例）
 * - 将 WindMill 回调映射到 FlameBannerListener
 */
@interface TbBannerAdapter : NSObject <FlameBannerAdapterProtocol, WindMillBannerViewDelegate>

@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameBannerListener> listener;
@property (nonatomic, assign, readonly) FlameBannerRenderType renderType;
@property (nonatomic, assign) CGSize adSize;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, strong, nullable) WindMillBannerView *bannerView;

/**
 * 初始化横幅适配器
 * @param placementId ToBid / WindMill 广告位 ID（已映射）
 * @param renderType 渲染模式（Express / SelfRender；本阶段只实现 Express）
 * @param listener Flame 横幅回调监听器
 */
- (instancetype)initWithPlacementId:(NSString *)placementId
                         renderType:(FlameBannerRenderType)renderType
                           listener:(id<FlameBannerListener>)listener;

@end

NS_ASSUME_NONNULL_END
