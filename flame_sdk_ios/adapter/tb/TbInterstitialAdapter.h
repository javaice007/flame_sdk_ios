//
//  TbInterstitialAdapter.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// Phase 5A.14：TB / ToBid / WindMill 插屏适配器（与 TbRewardAdapter 同目录、同模式）
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FlameInterstitialAdapterProtocol.h"
#import "FlameInterstitialAd.h"

// WindMill SDK 前向声明（头文件不 import 第三方 SDK，避免模块解析失败）
// 注意：ToBid SDK 类名带历史拼写错误（Inter-s-i-titial，单 i），必须按此拼写。
@class WindMillIntersititialAd;
@protocol WindMillIntersititialAdDelegate;

/**
 * TB / ToBid / WindMill 插屏适配器
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 职责：
 * - 实现 FlameInterstitialAdapterProtocol（内部协议）
 * - 实现 WindMillIntersititialAdDelegate（ToBid SDK delegate）
 * - 持有 WindMillIntersititialAd 实例
 * - 将 WindMill 回调映射到 FlameInterstitialListener
 *
 * 不直接实现对外 FlameInterstitialAd 协议，不暴露给接入方。
 */
@interface TbInterstitialAdapter : NSObject <FlameInterstitialAdapterProtocol, WindMillIntersititialAdDelegate>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameInterstitialListener> listener;
@property (nonatomic, strong) WindMillIntersititialAd *intersititialAd;

/**
 * 初始化插屏适配器
 * @param viewController 展示广告的视图控制器（仅用于诊断/回退，show 时会动态重新获取顶层 VC）
 * @param placementId ToBid / WindMill 广告位 ID（已映射）
 * @param listener Flame 插屏回调监听器
 */
- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                               listener:(id<FlameInterstitialListener>)listener;

@end
