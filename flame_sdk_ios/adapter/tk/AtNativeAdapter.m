//
//  AtNativeAdapter.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/23.
//
#import <Foundation/Foundation.h>
#import "AtNativeAdapter.h"
#import "FlameErrorCode.h"
#import "FlameLogger.h"


@implementation AtNativeAdapter

- (instancetype)initWithViewController:(UIViewController *)viewController
                         atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameNativeListener>)listener {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _atPlacementId = [atPlacementId copy];
        _listener = listener;
        
        _localExtra = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height {
    [self loadWithUserId:nil userCustomData:nil width:width height:height];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height {
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
    if (width <= 0 || height < 0 || isnan(width) || isnan(height) || isinf(width) || isinf(height)) {
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
    
    // 4. 填充尺寸信息 (TopOn 要求使用 NSValue 包装 CGSize)
    CGSize adSize = CGSizeMake(width, height);
    self.requestedAdSize = adSize;
    [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] load size -> width: %.2f, height: %.2f", width, height]];
    [self.localExtra setObject:[NSValue valueWithCGSize:adSize]
                        forKey:kATExtraInfoNativeAdSizeKey];
    
    // 5. load ad
    [[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId extra:self.localExtra delegate:self];
}

- (BOOL)isLoading { 
    if (self.atPlacementId.length == 0) return NO;
    ATCheckLoadModel *status = [[ATAdManager sharedManager] checkNativeLoadStatusForPlacementID:self.atPlacementId];
    return status ? status.isLoading : NO;
}

- (BOOL)isReady { 
    if (self.atPlacementId.length == 0) return NO;
    return [[ATAdManager sharedManager] nativeAdReadyForPlacementID:self.atPlacementId];
}

- (void)showInContainer:(UIView *)container {
    if (!container) return;

    // 1. 确保在主线程执行所有 UI 操作
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self isReady]) {
            [FlameLogger e:@"[AtNativeAdapter] Ad not ready"];
            return;
        }

        [self remove];
        [container layoutIfNeeded];

        // ✅ 修复问题2：在展示时才获取offer（消耗广告缓存）
        // 官方文档说明："获取后消耗一条广告缓存"
        ATNativeAdOffer *offer = [[ATAdManager sharedManager] getNativeAdOfferWithPlacementID:self.atPlacementId
                                                                                        scene:@"default_scene"];

        if (!offer) {
            [FlameLogger e:@"[AtNativeAdapter] Failed to get native offer on show"];
            if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
                [self.listener onAdError:@"NO_OFFER" desc:@"Failed to get offer when showing"];
            }
            return;
        }

        // 2. 卡片尺寸：优先使用 load 阶段传入尺寸；否则使用宽度-32和16:9
        BOOL useRequestedSize = YES;
        CGFloat width = self.requestedAdSize.width;
        CGFloat height = self.requestedAdSize.height;

        CGFloat containerWidth = CGRectGetWidth(container.bounds);
        CGFloat containerHeight = CGRectGetHeight(container.bounds);
        if (containerWidth <= 0) {
            containerWidth = UIScreen.mainScreen.bounds.size.width;
        }
        if (containerHeight <= 0) {
            containerHeight = UIScreen.mainScreen.bounds.size.height;
        }

        // 兜底：若未提供请求尺寸，则使用固定卡片比例
        if (width <= 0 || height <= 0) {
            useRequestedSize = NO;
            width = containerWidth - 32.0;
            if (width <= 0) {
                width = containerWidth;
            }
            height = width * 9.0 / 16.0;
        }

        // 最后兜底，避免非预期尺寸导致渲染失败
        if (width <= 0) {
            width = UIScreen.mainScreen.bounds.size.width - 32.0;
        }
        if (height <= 0) {
            height = width * 9.0 / 16.0;
        }

        NSString *sizeSource = useRequestedSize ? @"requested(load)" : @"fallback(container/screen)";
        [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] show size -> width: %.2f, height: %.2f, source: %@", width, height, sizeSource]];

        ATNativeADConfiguration *config = [[ATNativeADConfiguration alloc] init];
        config.ADFrame = CGRectMake(0, 0, width, height);
        config.delegate = self;
        config.rootViewController = self.viewController;
        config.sizeToFit = YES; // 允许自适应
        config.videoPlayType = ATNativeADConfigVideoPlayAlwaysAutoPlayType;

        // 3. 创建并渲染
        ATNativeADView *nativeADView = [[ATNativeADView alloc] initWithConfiguration:config
                                                                        currentOffer:offer
                                                                         placementID:self.atPlacementId];
        //禁用 autoresizing 转换约束，防止与内部约束冲突
        nativeADView.translatesAutoresizingMaskIntoConstraints = YES;

        // 关键：对于模板广告，必须调用这个方法进行渲染
        [offer rendererWithConfiguration:config selfRenderView:nil nativeADView:nativeADView];
        self.currentAdView = nativeADView;

        [container.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [container addSubview:nativeADView];

        // 3. 固定为大卡片布局：顶部留边 + 水平居中
        CGFloat topInset = 16.0;
        CGFloat originX = MAX((containerWidth - width) / 2.0, 0.0);
        CGFloat originY = MIN(topInset, MAX(containerHeight - height, 0.0));
        nativeADView.frame = CGRectMake(originX, originY, width, height);

        // ✅ 让 SDK 算出最终高度
        [nativeADView sizeToFit];

        [nativeADView setNeedsLayout];
        [nativeADView layoutIfNeeded];
    });
}

- (void)destroy {
    // 1. 移除 UI
    [self remove];
    
    // 2. 断开所有引用
    _listener = nil;
    
    if (self.localExtra) {
        [self.localExtra removeAllObjects];
        _localExtra = nil;
    }

    _requestedAdSize = CGSizeZero;
    
    // 3. 注意：TopOn 内部通常由 AdManager 管理，
    // 如果有特定的 Release 接口可在此调用，通常置空引用即可。
    _atPlacementId = nil;

}

- (void)remove {
    if (self.currentAdView) {
        [self.currentAdView removeFromSuperview];
        _currentAdView = nil;
    }
}

- (void)didFailToLoadADWithPlacementID:(NSString *)placementID error:(NSError *)error { 
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:[NSString stringWithFormat:@"%ld", (long)error.code]
                                 desc:error.localizedDescription];
    }
}

- (void)didFinishLoadingADWithPlacementID:(NSString *)placementID {
    // ✅ 修复问题2：不在load回调中获取offer
    // offer会在showInContainer时才获取，避免不展示时浪费广告缓存

    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

- (void)didClickNativeAdInAdView:(nonnull ATNativeADView *)adView placementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra { 
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

- (void)didShowNativeAdInAdView:(nonnull ATNativeADView *)adView placementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra { 
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

- (void)didCloseDetailInAdView:(ATNativeADView *)adView
                   placementID:(NSString *)placementID
                         extra:(NSDictionary *)extra{
    // ℹ️ 这个回调表示"退出详情页面"，不是真正的广告关闭
    // 广告关闭应该使用 didTapCloseButtonInAdView
    [FlameLogger i:@"[AtNativeAdapter] Detail page closed"];
}

#pragma mark - ✅ 修复问题3：正确绑定关闭按钮回调

/// 原生广告点击了关闭按钮（真正的广告关闭事件）
/// 根据官方文档示例（塔库原生广告对接说明.md 第91-101行）
- (void)didTapCloseButtonInAdView:(ATNativeADView *)adView
                       placementID:(NSString *)placementID
                             extra:(NSDictionary *)extra {
    [FlameLogger i:@"[AtNativeAdapter] Close button tapped"];

    // 触发关闭回调
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }

    // 自动移除广告视图
    [self remove];
}

@end
