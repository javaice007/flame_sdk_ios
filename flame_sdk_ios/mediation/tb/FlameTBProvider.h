//
//  FlameTBProvider.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TB 平台源码宏隔离：TK 构建变体下整个文件置空，避免编译期 import WindMill/ToBid
#if defined(FLAME_BUILD_TB)

#import <Foundation/Foundation.h>
#import "FlameMediationProvider.h"

/**
 * TB / ToBid / WindMill 聚合平台 Provider
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 职责：
 * - 返回 platformCode = @"tb"
 * - 初始化 ToBid / WindMill SDK
 * - 创建 TbRewardAdapter（Phase 5A 先只做 Reward）
 * - 其他广告类型 Phase 6 补齐
 */
@interface FlameTBProvider : NSObject <FlameMediationProvider>

@end

#endif // FLAME_BUILD_TB
