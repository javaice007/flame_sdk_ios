//
//  AtDrawAdapter.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/25.
//

#import "AtDrawAdapter.h"
#import "FlameErrorCode.h"
#import "FlameLogger.h"

@implementation AtDrawAdapter

- (instancetype)initWithViewController:(UIViewController *)viewController
                         atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameDrawListener>)listener{
    self = [super init];
    if (self) {
        // 1. 保存必要参数
        _atPlacementId = [atPlacementId copy];
        _listener = listener;
        _viewController = viewController; // weak 引用防止循环引用
        
        // 2. 初始化配置字典
        _localExtra = [NSMutableDictionary dictionary];
        
        // 3. 预先创建视频容器视图
        // 注意：这里先创建对象，具体的 Frame 在 loadWithWidth 中由外部指定
        _videoView = [[UIView alloc] initWithFrame:CGRectZero];
        _videoView.backgroundColor = [UIColor blackColor];
    }
    return self;
}

- (BOOL)isLoading {
    //TODO
    return NO;
}

- (BOOL)isReady { 
    if (self.atPlacementId.length == 0) return NO;
    return [[ATAdManager sharedManager] adReadyForPlacementID:self.atPlacementId];
}

- (void)loadWithWidth:(CGFloat)width height:(CGFloat)height { 
    [self loadWithUserId:nil userCustomData:nil width:width height:height];
}

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
                height:(CGFloat)height{
    // 1. 基础校验：广告位 ID
    if (self.atPlacementId == nil || self.atPlacementId.length == 0) {
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                                desc:@"Invalid mapping for placementId"];
        }
        return;
    }
    
    // 2. 校验宽度和高度
    // isnan() 检查是否为非数字，isinf() 检查是否为无穷大
    if (width <= 0 || height <= 0 || isnan(width) || isnan(height) || isinf(width) || isinf(height)) {
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            NSString *errorDesc = [NSString stringWithFormat:@"Invalid ad size: %.2f x %.2f", width, height];
            [self.listener onAdError:ERROR_CODE_INVALID_PARAM
                                desc:errorDesc];
        }
        return;
    }
    
    // 3. 填充用户信息
    if (userId.length > 0) {
        self.localExtra[kATAdLoadingExtraUserIDKey] = userId;
    }
    if (userCustomData.length > 0) {
        self.localExtra[kATAdLoadingExtraUserDataKeywordKey] = userCustomData;
    }
    
    self.videoView.frame = CGRectMake(0, 0, width, height);
    //内部浏览器打开
    [self.localExtra setValue:self forKey:kATAdMediaVideoExtraKeyInternalBrowserViewController];
    //隐藏倒计时
    [self.localExtra setValue:@NO forKey:kATAdMediaVideoExtraKeyHideCountDown];
    //加载视频广告超时时间
    [self.localExtra setValue:@8 forKey:kATAdMediaVideoExtraKeyLoadVideoTimeout];
    //广告要不要自动播放，对VMAP才有效
    [self.localExtra setValue:@NO forKey:kATAdMediaVideoExtraKeyAutoPlayAdBreaks];
    //关闭当前播放信息
    [self.localExtra setValue:@YES forKey:kATAdMediaVideoExtraKeyDisableNowPlayingInfo];
    
//    [[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId extra:self.localExtra controlDataParam:@{@"description_url":@"description_url"} delegate:self mediaVideoContainerView:self.videoView viewController:self.viewController];
    // 确保在主线程发起加载，以防渲染上下文初始化失败
    dispatch_async(dispatch_get_main_queue(), ^{
        [[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId
                                                    extra:self.localExtra
                                         controlDataParam:@{@"description_url":@"description_url"}
                                                 delegate:self
                                   mediaVideoContainerView:self.videoView
                                           viewController:self.viewController];
    });
}

- (void)showInContainer:(UIView *)container contentPlayhead:(id)playhead {
    if (!container) return;

    // 1. 确保在主线程执行 UI 操作
    dispatch_async(dispatch_get_main_queue(), ^{
        // 2. 准备容器层级
        [self.videoView removeFromSuperview];
        self.videoView.frame = container.bounds;
        self.videoView.backgroundColor = [UIColor blackColor]; // 必须黑色，防止闪红
        self.videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [container addSubview:self.videoView];
        [container bringSubviewToFront:self.videoView];

        // 3. 稍微延迟，确保 SwiftUI 的容器 window 已经挂载好
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            ATShowConfig *config = [[ATShowConfig alloc] initWithScene:@"default_scene" showCustomExt:nil];
            self.offer = [[ATAdManager sharedManager] mediaVideoObjectWithPlacementID:self.atPlacementId
                                                                           showConfig:config
                                                                             delegate:self];
            
            if (self.offer) {
                [FlameLogger i:[NSString stringWithFormat:@"[FlameSDK] Offer Type: %ld. Rendering...", (long)self.offer.type]];

                // --- 关键修复：模板广告视图提取 ---
                
                // A. 建立 loadView 绑定（针对自渲染视频）
                self.offer.loadView = self.videoView;

                // B. 尝试寻找隐藏的“模板视图” (针对穿山甲 Express)
                // 即使头文件没有，很多适配器内部会将真正的 View 存在这些 Key 里
                UIView *expressView = nil;
                NSArray *keys = @[@"adView", @"expressAdView", @"videoView"];
                for (NSString *key in keys) {
                    @try {
                        id val = [self.offer valueForKey:key];
                        if (val && [val isKindOfClass:[UIView class]]) {
                            expressView = (UIView *)val;
                            [FlameLogger i:[NSString stringWithFormat:@"[FlameSDK] Found Internal Express View via: %@", key]];
                            break;
                        }
                    } @catch (NSException *e) {}
                }

                if (expressView && expressView != self.videoView) {
                    expressView.frame = self.videoView.bounds;
                    expressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    [self.videoView addSubview:expressView];
                }

                // 4. 执行播放逻辑
                UIViewController *rootVC = self.viewController ?: container.window.rootViewController;
                
                if (self.offer.type == ATMediaVideoOfferTypeVAST) {
                    [self.offer startWithViewController:rootVC];
                } else {
                    if (playhead) {
                        [self.offer contentPlayhead:playhead];
                    }
                    // 模板广告有时需要调用 start 才会触发渲染
                    [self.offer start];
                }

                // 5. 强制布局刷新
                [self.videoView setNeedsLayout];
                [self.videoView layoutIfNeeded];

                if (self.listener) [self.listener onAdShow];

            } else {
                [FlameLogger e:@"[FlameSDK] Failed to get Offer object."];
            }
        });
    });
}

- (void)remove {
    // 1. 停止视频播放 (如果有 offer 对象)
    if (self.offer) {
        // 部分版本的 AnyThink SDK 建议在移除时调用 stop
        // 如果 offer 响应 stop 方法，建议执行
        if ([self.offer respondsToSelector:@selector(stop)]) {
            [self.offer performSelector:@selector(stop)];
        }
    }

    // 2. 将视频视图从父容器中移除
    if (self.videoView) {
        [self.videoView removeFromSuperview];
    }
}

- (void)destroy {
    // 1. 先执行移除操作
    [self remove];
    
    // 2. 断开所有委托引用，防止循环引用或野指针回调
    self.listener = nil;
    
    // 3. 释放 AnyThink 相关资源
    if (self.offer) {
        _offer = nil;
    }
    
    if (self.videoView) {
        _videoView = nil;
    }
    
    // 4. 清理配置数据
    if (self.localExtra) {
        [self.localExtra removeAllObjects];
        _localExtra = nil;
    }
    
    // 5. 将 ViewController 置为空
    self.viewController = nil;
}

- (void)didFinishLoadingADWithPlacementID:(NSString *)placementID {
    [FlameLogger i:[NSString stringWithFormat:@"Draw didFinishLoadingADWithPlacementID ==> %@", placementID]];
    
    if (self.listener == nil) {
        [FlameLogger i:@"Listener is nil"];
    } else if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    } else {
        [FlameLogger i:@"Listener does not respond to onAdLoaded selector!"];
    }
}

- (void)didFailToLoadADWithPlacementID:(NSString *)placementID error:(NSError *)error {
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:[NSString stringWithFormat:@"%ld", (long)error.code]
                            desc:error.localizedDescription];
    }
}

/// 获得展示收益
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)didRevenueForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    [FlameLogger i:[NSString stringWithFormat:@"didRevenueForPlacementID:%@ with extra: %@", placementID, extra]];
}

/// ad play starts
- (void)mediaVideoDidStartPlayingForPlacementID:(NSString *)placementID
                                          extra:(NSDictionary *)extra {
    [FlameLogger i:[NSString stringWithFormat:@"mediaVideoDidStartPlayingForPlacementID:%@ extra:%@", placementID, extra]];
}

/// ad play ends
- (void)mediaVideoDidEndPlayingForPlacementID:(NSString *)placementID
                                        extra:(NSDictionary *)extra {
    [FlameLogger i:[NSString stringWithFormat:@"mediaVideoDidEndPlayingForPlacementID:%@ extra:%@", placementID, extra]];
}

- (void)mediaVideoDidFailToPlayForPlacementID:(NSString *)placementID
                                        error:(NSError *)error
                                        extra:(NSDictionary *)extra {
    [FlameLogger i:[NSString stringWithFormat:@"mediaVideoDidFailToPlayForPlacementID:%@ error:%@ extra:%@", placementID, error, extra]];
}

- (void)mediaVideoAdResumeForPlacementID:(NSString *)placementID
                                   extra:(NSDictionary *)extra {
    [FlameLogger i:[NSString stringWithFormat:@"mediaVideoAdResumeForPlacementID:%@ extra:%@", placementID, extra]];
}

/// ad play fail
- (void)rewardedVideoDidFailToPlayForPlacementID:(NSString *)placementID
                                           error:(NSError *)error
                                           extra:(NSDictionary *)extra {
    [FlameLogger i:[NSString stringWithFormat:@"rewardedVideoDidFailToPlayForPlacementID:%@ error:%@ extra:%@", placementID, error, extra]];
}

/// ad clicks
- (void)mediaVideoDidClickForPlacementID:(NSString *)placementID
                                   extra:(NSDictionary *)extra {
    [FlameLogger i:[NSString stringWithFormat:@"mediaVideoDidClickForPlacementID:%@ extra:%@", placementID, extra]];
}

@end
