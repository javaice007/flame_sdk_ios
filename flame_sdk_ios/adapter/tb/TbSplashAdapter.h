//
//  TbSplashAdapter.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// Phase 5A.15：TB / ToBid / WindMill 开屏适配器（与 TbRewardAdapter / TbInterstitialAdapter 同目录、同模式）
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FlameSplashAdapterProtocol.h"
#import "FlameSplashAd.h"

// WindMill SDK 前向声明（头文件不 import 第三方 SDK，避免模块解析失败）
@class WindMillSplashAd;
@protocol WindMillSplashAdDelegate;

/**
 * TB / ToBid / WindMill 开屏适配器
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 职责：
 * - 实现 FlameSplashAdapterProtocol（内部协议）
 * - 实现 WindMillSplashAdDelegate（ToBid SDK delegate）
 * - 持有 WindMillSplashAd 实例
 * - 将 WindMill 回调映射到 FlameSplashListener
 *
 * 与 Reward/Interstitial 的关键差异：
 * - 加载方法名是 `loadAd`（非 `loadAdData`）
 * - 展示方法是 `showAdInWindow:withBottomView:`（取 UIWindow*，非 showAdFromRootViewController:）
 * - ToBid 的 `onSplashAdSkiped:` / `onSplashAdClosed:` 都坍缩到 Flame 的 `onAdClosed`，
 *   用 `finishOnce` 标记保证幂等（skip + close 即使连续到达也只通知业务一次）
 *
 * 不直接实现对外 FlameSplashAd 协议，不暴露给接入方。
 */
@interface TbSplashAdapter : NSObject <FlameSplashAdapterProtocol, WindMillSplashAdDelegate>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameSplashListener> listener;
@property (nonatomic, strong) WindMillSplashAd *splashAd;

/**
 * 初始化开屏适配器
 * @param viewController 展示广告的 host 视图控制器（仅作 host VC，show 时 SDK 直接用传入的 window）
 * @param placementId ToBid / WindMill 广告位 ID（已映射）
 * @param listener Flame 开屏回调监听器
 */
- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                               listener:(id<FlameSplashListener>)listener;

@end
