//
//  FlameRewardAdapterProtocol.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * 内部激励视频适配器协议
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * FlameRewardAdImpl 内部持有 id<FlameRewardAdapterProtocol>，
 * 通过此协议转发 load / show / destroy 等调用，
 * 不直接依赖具体平台适配器（AtRewardAdapter / TbRewardAdapter 等）。
 *
 * 各平台适配器（AtRewardAdapter 等）实现此协议，
 * 不直接实现对外 FlameRewardAd 协议。
 */
@protocol FlameRewardAdapterProtocol <NSObject>

@required

/**
 * 加载广告（无用户信息）
 */
- (void)load;

/**
 * 加载广告（带用户信息）
 * @param userId 用户 ID
 * @param userCustomData 用户自定义数据
 */
- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData;

/**
 * 广告是否准备就绪
 */
- (BOOL)isReady;

/**
 * 广告是否在加载中
 */
- (BOOL)isLoading;

/**
 * 展示广告
 */
- (void)show;

/**
 * 销毁广告，释放资源
 */
- (void)destroy;

@end
