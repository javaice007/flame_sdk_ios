//
//  TbNativeSelfRenderView.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// Phase 5A.18D-B：TB / ToBid / WindMill 原生（Native）自渲染 View
// （镜像 TK AtNativeSelfRenderView 的角色，从 WindMillNativeAd 物料自建 UI）
//
// 范围（Phase 5A.18D-B）：
// - 用于 feedADMode 非 NativeExpress 的物料（SmallImage/LargeImage/GroupImage/PortraitImage）
// - 视频/媒体模式优先挂载 ToBid 官方 mediaView（不自研播放器），本阶段视频真实填充留后续
//
// 关键设计（与 TK AtNativeSelfRenderView 同构）：
// - 从 WindMillNativeAd 读 title/desc/iconUrl/callToAction/imageUrlList/rating 等字段
// - Manual Frame 布局（参考 TK AtNativeSelfRenderView.m:107-155）
// - 异步下载图片（icon + main image），用 NSURLSession（不引入第三方库）
// - 提供 clickableViews 给 Adapter 调用 WindMillNativeAdView.setClickableViews:
// - 不自行上报曝光和点击（由 Adapter 经 WindMillNativeAdView 触发）
// - cleanup 取消图片请求 + 移除子 view（destroy 时调用）
//
// 与 WindMillNativeAdView 的关系：
// - WindMillNativeAdView 是 ToBid 的容器（refreshData / setClickableViews / unregisterDataObject）
// - TbNativeSelfRenderView 作为 WindMillNativeAdView 的子 view，承载自渲染的 UI 控件
// - 由 Adapter 创建并挂载，不暴露给上层
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WindMillNativeAd;

/**
 * TB / ToBid 原生（Native）自渲染 View（SDK 内部）
 *
 * 职责：
 * - 创建自渲染子控件（icon/title/desc/main image/CTA/ad logo/dislike）
 * - 从 WindMillNativeAd 读取物料
 * - 根据 feedADMode 布局（LargeImage / SmallImage / GroupImage / PortraitImage）
 * - 提供给 Adapter 注册点击的 clickableViews
 * - 异步下载图片（不引入第三方库）
 * - 提供 cleanup 供 destroy 时调用
 *
 * 不负责：
 * - 曝光上报（由 Adapter 经 WindMillNativeAdView 触发）
 * - 点击上报（由 Adapter 经 nativeAdViewDidClick: 回调）
 * - 关闭处理（由 Adapter 经 dislikeWithReason: 回调）
 */
@interface TbNativeSelfRenderView : UIView

/**
 * 用 WindMillNativeAd 物料初始化并布局。
 * @param nativeAd ToBid 原生物料（feedADMode 必须非 NativeExpress）
 * @param containerSize 容器尺寸（用于布局宽度）
 */
- (instancetype)initWithNativeAd:(WindMillNativeAd *)nativeAd
                    containerSize:(CGSize)containerSize;

/**
 * 返回需要注册点击的可见子控件数组（供 Adapter 调 setClickableViews:）。
 * 只包含实际可见、非 nil 的控件。
 */
- (NSArray<UIView *> *)clickableViews;

/**
 * 清理：取消进行中的图片下载、移除子控件、置 nil 引用。
 * 在 Adapter destroy 或重新布局前调用。
 */
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
