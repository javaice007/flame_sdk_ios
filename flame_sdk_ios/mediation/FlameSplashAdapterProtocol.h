//
//  FlameSplashAdapterProtocol.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * 内部开屏适配器协议
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * FlameSplashAdImpl 内部持有 id<FlameSplashAdapterProtocol>，
 * 通过此协议转发 load / show / destroy 等调用，
 * 不直接依赖具体平台适配器（AtSplashAdapter / TbSplashAdapter 等）。
 */
@protocol FlameSplashAdapterProtocol <NSObject>

@required

- (void)load;

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData;

- (BOOL)isReady;

- (BOOL)isLoading;

- (void)show:(UIWindow *)window;

- (void)destroy;

@end
