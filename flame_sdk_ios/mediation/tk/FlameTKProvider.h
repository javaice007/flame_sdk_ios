//
//  FlameTKProvider.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import <Foundation/Foundation.h>
#import "FlameMediationProvider.h"

/**
 * TK / TopOn / AnyThink 聚合平台 Provider
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 职责：
 * - 返回 platformCode = @"tk"
 * - 复用 FlameAdapterManager 初始化 TopOn / AnyThink
 * - 不直接修改 adapter/tk/At*Adapter
 * - 不处理广告创建（Phase 3 才解耦）
 * - 不接入 ToBid
 */
@interface FlameTKProvider : NSObject <FlameMediationProvider>

@end

#endif // FLAME_BUILD_TK / 默认 TK
