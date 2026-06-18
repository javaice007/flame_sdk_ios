//
//  FlameInterstitialAdapterProtocol.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * 内部插屏适配器协议
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * FlameInterstitialAdImpl 内部持有 id<FlameInterstitialAdapterProtocol>，
 * 通过此协议转发 load / show / destroy 等调用，
 * 不直接依赖具体平台适配器（AtInterstitialAdapter / TbInterstitialAdapter 等）。
 */
@protocol FlameInterstitialAdapterProtocol <NSObject>

@required

- (void)load;

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData;

- (BOOL)isReady;

- (BOOL)isLoading;

- (void)show;

- (void)destroy;

@end
