//
//  FlameRewardAd.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * Flame 激励视频广告回调协议
 */
@protocol FlameRewardListener <NSObject>

@optional

/**
 * 广告加载成功回调
 */
- (void)onAdLoaded;

/**
 * 广告展示回调
 */
- (void)onAdShow;

/**
 * 广告点击回调
 */
- (void)onAdClicked;


/**
 * 广告奖励发放回调
 * @param userId 用户 ID
 * @param userCustomData 用户自定义数据
 * @param trandId 业务ID
 */
- (void)onAdReward:(NSString *)userId
    userCustomData:(NSString *)userCustomData
           transId:(NSString *)transId
;


/**
 * 广告关闭回调
 */
- (void)onAdClosed;

/**
 * 广告异常/错误回调
 * @param code 错误码
 * @param desc 错误描述
 */
- (void)onAdError:(NSString *)code
             desc:(NSString *)desc;

/**
 * 广告播放完成回调
 */
- (void)onAdPlayComplete;

@end

@protocol FlameRewardAd <NSObject>
/**
 * 加载广告
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
 * 销毁广告
 */
- (void)destroy;

@end
