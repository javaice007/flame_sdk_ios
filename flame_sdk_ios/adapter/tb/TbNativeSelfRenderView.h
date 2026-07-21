//
//  TbNativeSelfRenderView.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// Phase 5A.18D-C：TB / ToBid / WindMill 原生（Native）自渲染 View（对齐官方 ToBid demo）
//
// 关键设计变更（5A.18D-C）：
// - 主图 / 视频 / logo / dislike 全部复用 WindMillNativeAdView 提供的公开 readonly 属性
//   （mainImageView / mediaView / imageViewList / logoView / dislikeButton）
//   不再自建 mainImageView 也不再用 NSURLSession 下载主图（WindMill 内部已加载）
// - 自建仅保留：iconImageView（iconUrl NSURLSession 下载）/ titleLabel / descLabel / ctaButton / ratingLabel
// - icon 仍走 NSURLSession（WindMill 不提供 icon view，官方 demo 用 sm_setImage 也是自建）
//
// 范围（Phase 5A.18D-C）：
// - 用于 feedADMode 非 NativeExpress 的物料（SmallImage/LargeImage/GroupImage/PortraitImage/Video*）
// - GroupImage 三图横排通过 imageViewList 实现（WindMill 提供的 3 个 UIImageView）
//
// 布局策略（manual frame，不引第三方库）：
// - padding=12，顶部 icon(50×50) + (title/rating/dislike 右上)
// - descLabel、主图区、ctaButton 右下、logoView 左下
// - layoutSubviews 末尾通过 onLayoutChanged block 把真实高度回调给 Adapter，
//   Adapter 据此回写 nativeAdView.frame.size.height（避免卡片下方大片空白）
//
// 与 WindMillNativeAdView 的关系：
// - WindMillNativeAdView 是 ToBid 的容器（refreshData / setClickableViews / unregisterDataObject）
// - TbNativeSelfRenderView 作为 WindMillNativeAdView 的子 view，承载自渲染 UI
// - WindMill 提供的 mainImageView/mediaView/logoView/dislikeButton reparent 到本 view 下做布局
//   （这些 view 归属权仍属 nativeAdView，cleanup 时不主动 nil，由 nativeAdView 释放）
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WindMillNativeAd;
@class WindMillNativeAdView;

/**
 * TB / ToBid 原生（Native）自渲染 View（SDK 内部）
 *
 * 职责：
 * - 创建自渲染子控件（icon/title/desc/cta/rating）
 * - 复用 WindMillNativeAdView 提供的 mainImageView/mediaView/imageViewList/logoView/dislikeButton
 * - 从 WindMillNativeAd 读取物料
 * - 根据 feedADMode 布局（LargeImage / SmallImage / GroupImage / PortraitImage / Video）
 * - 提供给 Adapter 注册点击的 clickableViews
 * - 异步下载 icon（不引入第三方库）
 * - 通过 onLayoutChanged 把真实高度回调给 Adapter（用于回写 nativeAdView 高度）
 * - 提供 cleanup 供 destroy 时调用
 *
 * 不负责：
 * - 曝光上报（由 Adapter 经 WindMillNativeAdView 触发）
 * - 点击上报（由 Adapter 经 nativeAdViewDidClick: 回调）
 * - 关闭处理（由 Adapter 经 dislikeWithReason: 回调）
 */
@interface TbNativeSelfRenderView : UIView

/**
 * 用 WindMillNativeAd 物料 + WindMillNativeAdView 初始化并布局。
 * @param nativeAd ToBid 原生物料（feedADMode 必须非 NativeExpress）
 * @param nativeAdView WindMillNativeAdView（必须先 refreshData: 过，mainImageView/mediaView 等才就绪）
 * @param containerSize 容器尺寸（用于布局宽度）
 */
- (instancetype)initWithNativeAd:(WindMillNativeAd *)nativeAd
                    nativeAdView:(WindMillNativeAdView *)nativeAdView
                    containerSize:(CGSize)containerSize;

/**
 * 返回需要注册点击的可见子控件数组（供 Adapter 调 setClickableViews:）。
 * 包含：自建 icon/title/desc/cta + WindMill 的 mainImageView/mediaView/dislikeButton（如存在）。
 */
- (NSArray<UIView *> *)clickableViews;

/**
 * 布局完成后的高度回调。Adapter 设置此 block，收到后回写 nativeAdView.frame.size.height。
 * @param height 本次 layoutSubviews 计算出的真实高度
 */
@property (nonatomic, copy, nullable) void (^onLayoutChanged)(CGFloat height);

/**
 * 清理：取消进行中的图片下载、移除自建子控件。
 * 在 Adapter destroy 或重新布局前调用。
 * 注意：不释放 WindMill 提供的 mainImageView/mediaView/logoView/dislikeButton（归 nativeAdView）。
 */
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
