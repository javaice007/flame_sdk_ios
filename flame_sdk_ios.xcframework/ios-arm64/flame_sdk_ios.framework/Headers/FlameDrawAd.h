//
//  FlameDrawAd.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/25.
//

#ifndef FlameDrawAd_h
#define FlameDrawAd_h

#import <UIKit/UIKit.h>

@protocol FlameDrawListener <NSObject>

/**
 * 广告加载成功回调
 */
- (void)onAdLoaded;

/**
 * 广告异常/错误回调
 * @param code 错误码
 * @param desc 错误描述
 */
- (void)onAdError:(NSString *)code desc:(NSString *)desc;

/**
 * 广告展示回调
 */
- (void)onAdShow;

/**
 * 广告点击回调
 */
- (void)onAdClicked;

/**
 * 广告关闭回调
 */
- (void)onAdClosed;

@end

@protocol FlameDrawAd <NSObject>

/**
 * 加载广告
 */
- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height;

/**
 * 加载广告（带用户信息）
 * @param userId 用户 ID
 * @param userCustomData 用户自定义数据
 * @param width 宽度
 * @param height 高度
 */
- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height;
/**
 * 是否正在加载
 */
- (BOOL)isLoading;

/**
 * 广告是否准备好
 */
- (BOOL)isReady;

/**
 * 展示 Draw 广告
 * @param container 容器视图
 * @param playhead 播放进度追踪对象
 */
- (void)showInContainer:(UIView *)container
        contentPlayhead:(id)playhead;
/**
 * 移除广告
 */
- (void)remove;

/**
 * 销毁广告
 */
- (void)destroy;

@end
#endif /* FlameDrawAd_h */
