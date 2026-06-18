//
//  TbRewardAdapter.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TB 平台源码宏隔离：TK 构建变体下整个文件置空，避免编译期 import WindMill/ToBid
#if defined(FLAME_BUILD_TB)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FlameRewardAdapterProtocol.h"
#import "FlameRewardAd.h"

// WindMill SDK 前向声明（头文件不 import 第三方 SDK，避免模块解析失败）
@class WindMillRewardVideoAd, WindMillRewardInfo;
@protocol WindMillRewardVideoAdDelegate;

/**
 * TB / ToBid / WindMill 激励视频适配器
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 职责：
 * - 实现 FlameRewardAdapterProtocol（内部协议）
 * - 实现 WindMillRewardVideoAdDelegate（ToBid SDK delegate）
 * - 持有 WindMillRewardVideoAd 实例
 * - 将 WindMill 回调映射到 FlameRewardListener
 *
 * 不直接实现对外 FlameRewardAd 协议，不暴露给接入方。
 */
@interface TbRewardAdapter : NSObject <FlameRewardAdapterProtocol, WindMillRewardVideoAdDelegate>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameRewardListener> listener;
@property (nonatomic, strong) WindMillRewardVideoAd *rewardVideoAd;

/**
 * 初始化激励视频适配器
 * @param viewController 展示广告的视图控制器
 * @param placementId ToBid / WindMill 广告位 ID（已映射）
 * @param listener Flame 激励视频回调监听器
 */
- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                               listener:(id<FlameRewardListener>)listener;

@end

#endif // FLAME_BUILD_TB
