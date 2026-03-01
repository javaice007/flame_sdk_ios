//
//  FlameNativeAd.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/21.
//

#ifndef FlameNativeAd_h
#define FlameNativeAd_h

#import <UIKit/UIKit.h>

@protocol FlameNativeListener <NSObject>
/**
 * 广告加载成功回调
 */
- (void)onAdLoaded;

/**
 * 广告展示失败回调
 * @param code 错误码
 * @param desc 错误描述
 */
- (void)onAdError:(NSString *)code
             desc:(NSString *)desc;
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

@protocol FlameNativeAd <NSObject>

/**
 * 加载广告
 * @param width 宽度
 * @param height 高度
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
 * 是否正在加载中
 */
- (BOOL)isLoading;

/**
 * 广告是否准备好展示
 */
- (BOOL)isReady;

/**
 * 展示广告
 * @param container 承载广告的父视图 (对应 Android 的 FrameLayout)
 */
- (void)showInContainer:(UIView *)container;

/**
 * 移除广告视图
 */
- (void)remove;

/**
 * 销毁广告实例，释放资源
 */
- (void)destroy;

@end


#endif /* FlameNativeAd_h */
