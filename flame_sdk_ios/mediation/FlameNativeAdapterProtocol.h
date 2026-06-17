//
//  FlameNativeAdapterProtocol.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FlameNativeAd.h"

/**
 * 内部原生适配器协议
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * FlameNativeAdImpl 内部持有 id<FlameNativeAdapterProtocol>，
 * 通过此协议转发 load / showInContainer / setRenderType / destroy 等调用，
 * 不直接依赖具体平台适配器（AtNativeAdapter / TbNativeAdapter 等）。
 */
@protocol FlameNativeAdapterProtocol <NSObject>

@required

- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height;

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height;

- (BOOL)isLoading;

- (BOOL)isReady;

- (void)showInContainer:(UIView *)container;

- (void)setRenderType:(FlameNativeRenderType)renderType;

- (void)remove;

- (void)destroy;

@end
