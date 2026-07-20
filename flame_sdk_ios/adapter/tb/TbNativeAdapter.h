//
//  TbNativeAdapter.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// Phase 5A.18B：TB / ToBid / WindMill 原生（Native）模板适配器
// （与 TbBannerAdapter / TbRewardAdapter / TbInterstitialAdapter / TbSplashAdapter 同目录、同模式）
//
// 范围（Phase 5A.18B）：
// - Native Template / Native Express（renderType == FlameNativeRenderTypeExpress）：完整实现
//   使用 WindMillNativeAdsManager 加载 → WindMillNativeAd(feedADMode==NativeExpress) →
//   WindMillNativeAdView.refreshData: 异步模板渲染 → renderSuccess 后 addSubview 到 container
// - Native SelfRender（renderType == FlameNativeRenderTypeSelfRender）：明确降级为"未实现"
//   返回 onAdError + 统一日志 [TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]，不调用任何 ToBid API
//   （原因不是 ToBid 不支持，而是当前 Flame SDK 的 ToBid Native SelfRender 桥接尚未接入）
//
// 关键设计（与 AtNativeAdapter 语义一致）：
// - Demo 通过 showInContainer:(UIView *)container 传入空容器，Adapter 负责创建并挂载 WindMillNativeAdView
// - 不暴露 WindMillNativeAd / WindMillNativeAdView 给上层
// - 异步模板渲染：refreshData: 后等 nativeExpressAdViewRenderSuccess:，再读 frame.size.height 动态值
// - generation + destroyed 守卫：destroy 后迟到的异步回调不再触发 listener
// - stale 守卫：manager/view 指针比对，与现有 TB Adapter 模式一致
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FlameNativeAdapterProtocol.h"
#import "FlameNativeAd.h"

// WindMill SDK 前向声明（头文件不 import 第三方 SDK，避免模块解析失败）
@class WindMillNativeAdsManager;
@class WindMillNativeAd;
@class WindMillNativeAdView;
@protocol WindMillNativeAdsManagerDelegate;
@protocol WindMillNativeAdViewDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * TB / ToBid / WindMill 原生（Native）模板适配器
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 职责：
 * - 实现 FlameNativeAdapterProtocol（内部协议）
 * - 实现 WindMillNativeAdsManagerDelegate（load 成功/失败）
 * - 实现 WindMillNativeAdViewDelegate（渲染/曝光/点击/dislike/关闭）
 * - 持有 WindMillNativeAdsManager / WindMillNativeAd / WindMillNativeAdView
 * - 将 WindMill 回调映射到 FlameNativeListener
 */
@interface TbNativeAdapter : NSObject <FlameNativeAdapterProtocol,
                                        WindMillNativeAdsManagerDelegate,
                                        WindMillNativeAdViewDelegate>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameNativeListener> listener;
@property (nonatomic, assign) FlameNativeRenderType renderType;

/**
 * 初始化原生适配器
 * @param viewController 顶层 VC（ToBid 落地页跳转需要，必须非空）
 * @param atPlacementId ToBid / WindMill 广告位 ID（已映射）
 * @param listener Flame 原生回调监听器
 */
- (instancetype)initWithViewController:(UIViewController *)viewController
                          atPlacementId:(NSString *)atPlacementId
                               listener:(id<FlameNativeListener>)listener;

@end

NS_ASSUME_NONNULL_END
