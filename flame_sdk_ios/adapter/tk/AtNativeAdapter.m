//
//  AtNativeAdapter.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/23.
//  Modified: 2026/3/17 - Added fullscreen mode support and sizeToFit parameter
//
// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import "AtNativeAdapter.h"
#import "AtNativeSelfRenderView.h"
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
        _renderType = FlameNativeRenderTypeSelfRender;
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

    // 5. 添加 sizeToFit 参数，与 TopOn 原生用法保持一致
    [self.localExtra setObject:@(YES) forKey:kATNativeAdSizeToFitKey];
    [FlameLogger i:@"[AtNativeAdapter] Set kATNativeAdSizeToFitKey = YES"];

    // 6. load ad
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

        // 获取 offer（消耗广告缓存）
        ATNativeAdOffer *offer = [[ATAdManager sharedManager] getNativeAdOfferWithPlacementID:self.atPlacementId
                                                                                        scene:@"default_scene"];

        if (!offer) {
            [FlameLogger e:@"[AtNativeAdapter] Failed to get native offer on show"];
            if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
                [self.listener onAdError:@"NO_OFFER" desc:@"Failed to get offer when showing"];
            }
            return;
        }

        // 2. 获取容器尺寸
        CGFloat containerWidth = CGRectGetWidth(container.bounds);
        CGFloat containerHeight = CGRectGetHeight(container.bounds);
        if (containerWidth <= 0) {
            containerWidth = UIScreen.mainScreen.bounds.size.width;
        }
        if (containerHeight <= 0) {
            containerHeight = UIScreen.mainScreen.bounds.size.height;
        }

        // 3. 计算广告卡片尺寸：优先使用 load 阶段传入尺寸
        BOOL useRequestedSize = YES;
        CGFloat width = self.requestedAdSize.width;
        CGFloat height = self.requestedAdSize.height;

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

        id<ATNativeMaterialProtocol> nativeMaterial = offer.nativeAd;
        BOOL materialIsExpress = nativeMaterial.isExpressAd || nativeMaterial.nativeAdRenderType == ATNativeAdRenderExpress;
        BOOL preferExpress = self.renderType == FlameNativeRenderTypeExpress;
        BOOL isExpressAd = materialIsExpress;

        CGFloat layoutWidth = width;
        CGFloat layoutHeight = height;
        if (isExpressAd) {
            // 模板广告尽可能使用更大的渲染尺寸，让广告内容展示更充分
            CGFloat availableWidth = containerWidth > 0 ? containerWidth : width;
            CGFloat expressWidth = nativeMaterial.nativeExpressAdViewWidth;
            CGFloat expressHeight = nativeMaterial.nativeExpressAdViewHeight;
            if (expressWidth > 0 && expressHeight > 0) {
                // 等比缩放至可用宽度（包含放大），使模板广告填满容器宽度
                CGFloat scale = availableWidth / expressWidth;
                layoutWidth = floor(availableWidth);
                layoutHeight = floor(expressHeight * scale);
            } else {
                // 无平台尺寸信息时使用可用宽度和请求高度
                layoutWidth = floor(availableWidth);
                // layoutHeight 保持请求值
            }
        }

        // 仅真实自渲染素材支持全屏布局；模板素材必须按平台模板尺寸展示。
        BOOL wantsFullScreen = (height >= containerHeight * 0.8);
        BOOL isFullScreenMode = wantsFullScreen && !isExpressAd;
        BOOL usePseudoFullScreenForExpress = wantsFullScreen && isExpressAd;

        NSString *sizeSource = useRequestedSize ? @"requested(load)" : @"fallback(container/screen)";
        NSString *renderTypeLabel = preferExpress ? @"Express" : @"SelfRender";
        NSString *actualRenderTypeLabel = materialIsExpress ? @"Express" : @"SelfRender";
        NSString *layoutModeLabel = isFullScreenMode ? @"FullScreen" : (usePseudoFullScreenForExpress ? @"PseudoFullScreen" : @"Card");
        [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] show size -> requested: %.2f x %.2f, layout: %.2f x %.2f, source: %@, mode: %@, preferredRenderType: %@, actualRenderType: %@",
            width, height, layoutWidth, layoutHeight, sizeSource, layoutModeLabel, renderTypeLabel, actualRenderTypeLabel]];
        [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] material info -> isExpressAd: %@, renderType: %ld, expressSize: %.2f x %.2f, adOfferInfo: %@",
                        materialIsExpress ? @"YES" : @"NO",
                        (long)nativeMaterial.nativeAdRenderType,
                        nativeMaterial.nativeExpressAdViewWidth,
                        nativeMaterial.nativeExpressAdViewHeight,
                        offer.adOfferInfo ?: @{}]];

        if (preferExpress != materialIsExpress) {
            [FlameLogger w:[NSString stringWithFormat:@"[AtNativeAdapter] Render type mismatch. preferred=%@, actualMaterial=%@. Rendering will follow actual material type.",
                            renderTypeLabel,
                            actualRenderTypeLabel]];
        }

        if (wantsFullScreen && isExpressAd) {
            [FlameLogger w:@"[AtNativeAdapter] Express native material does not support fullscreen layout. Using pseudo fullscreen wrapper with template card size."];
        }

        // 4. 配置原生广告
        ATNativeADConfiguration *config = [[ATNativeADConfiguration alloc] init];

        if (isExpressAd && usePseudoFullScreenForExpress) {
            // 模板广告全屏模式：使用容器完整尺寸，让广告内容铺满
            config.ADFrame = CGRectMake(0, 0, containerWidth, containerHeight);
            config.sizeToFit = YES;
        } else if (isExpressAd) {
            config.ADFrame = CGRectMake(0, 0, layoutWidth, layoutHeight);
            config.sizeToFit = YES;
        } else if (isFullScreenMode) {
            // 全屏模式：使用容器的完整尺寸
            config.ADFrame = CGRectMake(0, 0, containerWidth, containerHeight);
            CGFloat mediaWidth = containerWidth - 24;
            CGFloat mediaHeight = mediaWidth * 9.0 / 16.0;
            config.mediaViewFrame = CGRectMake(0, 0, mediaWidth, mediaHeight);
            config.sizeToFit = NO;
        } else {
            // 卡片模式：使用计算的卡片尺寸
            config.ADFrame = CGRectMake(0, 0, layoutWidth, layoutHeight);
            CGFloat mediaWidth = layoutWidth - 24;
            CGFloat mediaHeight = mediaWidth * 9.0 / 16.0;
            config.mediaViewFrame = CGRectMake(0, 0, mediaWidth, mediaHeight);
            config.sizeToFit = YES;
        }

        config.delegate = self;
        config.rootViewController = self.viewController;
        config.videoPlayType = ATNativeADConfigVideoPlayAlwaysAutoPlayType;

        // 设置logo位置（精确设置）
        if (!isExpressAd) {
            CGFloat adWidth = isFullScreenMode ? containerWidth : layoutWidth;
            CGFloat adHeight = isFullScreenMode ? containerHeight : layoutHeight;
            config.logoViewFrame = CGRectMake(adWidth - 50 - 12, adHeight - 50 - 12, 50, 50);
            // 设置logo位置偏好（部分平台使用）
            [ATAPI sharedInstance].preferredAdLogoPosition = ATAdLogoPositionBottomRightCorner;
        }

        // 5. 创建原生广告视图
        ATNativeADView *nativeADView = [[ATNativeADView alloc] initWithConfiguration:config
                                                                        currentOffer:offer
                                                                         placementID:self.atPlacementId];
        nativeADView.translatesAutoresizingMaskIntoConstraints = YES;

        if (isExpressAd) {
            [offer rendererWithConfiguration:config selfRenderView:nil nativeADView:nativeADView];
        } else {
            AtNativeSelfRenderView *selfRenderView = [[AtNativeSelfRenderView alloc] initWithOffer:offer];

            UIView *mediaView = [nativeADView getMediaView];
            if (mediaView) {
                selfRenderView.mediaView = mediaView;
            }

            NSMutableArray *clickableViewArray = [NSMutableArray array];
            [clickableViewArray addObjectsFromArray:@[
                selfRenderView.iconImageView,
                selfRenderView.titleLabel,
                selfRenderView.textLabel,
                selfRenderView.ctaLabel,
                selfRenderView.mainImageView
            ]];
            [nativeADView registerClickableViewArray:clickableViewArray];

            ATNativePrepareInfo *prepareInfo = [ATNativePrepareInfo loadPrepareInfo:^(ATNativePrepareInfo *info) {
                info.textLabel = selfRenderView.textLabel;
                info.advertiserLabel = selfRenderView.advertiserLabel;
                info.titleLabel = selfRenderView.titleLabel;
                info.ratingLabel = selfRenderView.ratingLabel;
                info.iconImageView = selfRenderView.iconImageView;
                info.mainImageView = selfRenderView.mainImageView;
                info.logoImageView = selfRenderView.logoImageView;
                info.ctaLabel = selfRenderView.ctaLabel;
                info.dislikeButton = selfRenderView.dislikeButton;
                info.mediaView = selfRenderView.mediaView;
            }];
            [nativeADView prepareWithNativePrepareInfo:prepareInfo];
            [offer rendererWithConfiguration:config selfRenderView:selfRenderView nativeADView:nativeADView];
        }

        ATNativeADView *displayAdView = [nativeADView embededAdView] ?: nativeADView;
        UIView *rootDisplayView = displayAdView;

        [container.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

        if (isFullScreenMode) {
            // 全屏模式：铺满整个容器
            displayAdView.frame = CGRectMake(0, 0, containerWidth, containerHeight);
            [container addSubview:displayAdView];
            [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] FullScreen layout: frame=(0, 0, %.0f, %.0f)", containerWidth, containerHeight]];
        } else if (usePseudoFullScreenForExpress) {
            UIView *wrapperView = [self expressPseudoFullScreenWrapperForAdView:displayAdView
                                                                   nativeMaterial:nativeMaterial
                                                                   contentWidth:layoutWidth
                                                                  contentHeight:layoutHeight
                                                                 containerWidth:containerWidth
                                                                containerHeight:containerHeight];
            [container addSubview:wrapperView];
            rootDisplayView = wrapperView;
            [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] Pseudo fullscreen layout: wrapper=(0, 0, %.0f, %.0f), card=%@",
                            containerWidth,
                            containerHeight,
                            NSStringFromCGRect(displayAdView.frame)]];
        } else {
            // 模板广告和普通卡片都走卡片布局，并允许 SDK 调整真实高度。
            displayAdView.frame = CGRectMake(0, 0, layoutWidth, layoutHeight);
            if (!isExpressAd) {
                [displayAdView sizeToFit];
            }

            CGFloat renderedWidth = CGRectGetWidth(displayAdView.frame) > 0 ? CGRectGetWidth(displayAdView.frame) : layoutWidth;
            CGFloat renderedHeight = CGRectGetHeight(displayAdView.frame) > 0 ? CGRectGetHeight(displayAdView.frame) : layoutHeight;

            // 水平和垂直都居中显示
            CGFloat originX = MAX((containerWidth - renderedWidth) / 2.0, 0.0);
            CGFloat originY = MAX((containerHeight - renderedHeight) / 2.0, 0.0);

            displayAdView.frame = CGRectMake(originX, originY, renderedWidth, renderedHeight);
            [container addSubview:displayAdView];
            [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] Card layout (centered): frame=(%.0f, %.0f, %.0f, %.0f), renderType: %@",
                            originX, originY, renderedWidth, renderedHeight, renderTypeLabel]];
        }

        self.currentAdView = rootDisplayView;

        if (!isExpressAd) {
            [self syncRenderedContentViewForAdView:displayAdView];
        }
        [rootDisplayView setNeedsLayout];
        [rootDisplayView layoutIfNeeded];
        [displayAdView setNeedsLayout];
        [displayAdView layoutIfNeeded];
    });
}

- (UIView *)expressPseudoFullScreenWrapperForAdView:(UIView *)adView
                                     nativeMaterial:(id<ATNativeMaterialProtocol>)nativeMaterial
                                       contentWidth:(CGFloat)contentWidth
                                      contentHeight:(CGFloat)contentHeight
                                     containerWidth:(CGFloat)containerWidth
                                    containerHeight:(CGFloat)containerHeight {
    // 模板广告全屏包装：优先填充，无法填充时居中显示
    UIView *wrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, containerWidth, containerHeight)];
    wrapperView.backgroundColor = [UIColor clearColor]; // 透明背景，由调用端容器控制
    wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // 计算广告最终尺寸和位置
    CGFloat finalWidth = contentWidth;
    CGFloat finalHeight = contentHeight;
    CGFloat originX = 0;
    CGFloat originY = 0;

    // 优先填充容器，当广告尺寸小于容器时才居中
    if (contentWidth >= containerWidth && contentHeight >= containerHeight) {
        // 广告能完全填充容器：铺满
        finalWidth = containerWidth;
        finalHeight = containerHeight;
        originX = 0;
        originY = 0;
        adView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [FlameLogger i:@"[AtNativeAdapter] Express pseudo fullscreen: fill mode (ad >= container)"];
    } else {
        // 广告无法完全填充：居中显示，上下左右间距均分
        originX = MAX((containerWidth - contentWidth) / 2.0, 0.0);
        originY = MAX((containerHeight - contentHeight) / 2.0, 0.0);
        adView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                   UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] Express pseudo fullscreen: center mode, gaps -> left/right: %.0f, top/bottom: %.0f",
                        originX, originY]];
    }

    adView.frame = CGRectMake(originX, originY, finalWidth, finalHeight);
    [wrapperView addSubview:adView];

    [FlameLogger i:[NSString stringWithFormat:@"[AtNativeAdapter] Express pseudo fullscreen layout: adView frame=(%.0f, %.0f, %.0f, %.0f)",
                    originX, originY, finalWidth, finalHeight]];

    return wrapperView;
}

- (void)syncRenderedContentViewForAdView:(UIView *)displayAdView {
    if (!displayAdView || CGRectIsEmpty(displayAdView.bounds)) {
        return;
    }

    UIView *contentView = [self primaryRenderedSubviewInView:displayAdView];
    if (!contentView) {
        return;
    }

    CGRect targetBounds = displayAdView.bounds;
    if (![self shouldResizeRenderedSubview:contentView parentBounds:targetBounds]) {
        return;
    }

    [self resizeRenderedSubview:contentView toBounds:targetBounds logPrefix:@"[AtNativeAdapter] Synced primary rendered view"];

    UIView *currentView = contentView;
    NSInteger depth = 0;
    while (currentView.subviews.count == 1 && depth < 4) {
        UIView *childView = currentView.subviews.firstObject;
        if (!childView || CGRectIsEmpty(currentView.bounds)) {
            break;
        }

        if (![self shouldResizeRenderedSubview:childView parentBounds:currentView.bounds]) {
            currentView = childView;
            depth += 1;
            continue;
        }

        NSString *logPrefix = [NSString stringWithFormat:@"[AtNativeAdapter] Synced nested rendered view depth=%ld", (long)(depth + 1)];
        [self resizeRenderedSubview:childView toBounds:currentView.bounds logPrefix:logPrefix];
        currentView = childView;
        depth += 1;
    }
}

- (UIView *)primaryRenderedSubviewInView:(UIView *)view {
    UIView *candidate = nil;
    CGFloat maxArea = 0.0;

    for (UIView *subview in view.subviews) {
        if (subview.hidden || subview.alpha <= 0.01) {
            continue;
        }

        CGFloat area = CGRectGetWidth(subview.frame) * CGRectGetHeight(subview.frame);
        if (area > maxArea) {
            maxArea = area;
            candidate = subview;
        }
    }

    return candidate;
}

- (BOOL)shouldResizeRenderedSubview:(UIView *)subview parentBounds:(CGRect)parentBounds {
    if (!subview) {
        return NO;
    }

    CGFloat widthDelta = fabs(CGRectGetWidth(parentBounds) - CGRectGetWidth(subview.frame));
    CGFloat heightDelta = fabs(CGRectGetHeight(parentBounds) - CGRectGetHeight(subview.frame));
    return widthDelta > 1.0 || heightDelta > 1.0;
}

- (void)resizeRenderedSubview:(UIView *)subview toBounds:(CGRect)bounds logPrefix:(NSString *)logPrefix {
    subview.translatesAutoresizingMaskIntoConstraints = YES;
    subview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    subview.frame = bounds;
    [subview setNeedsLayout];
    [subview layoutIfNeeded];

    [FlameLogger i:[NSString stringWithFormat:@"%@: class=%@ frame=%@",
                    logPrefix,
                    NSStringFromClass([subview class]),
                    NSStringFromCGRect(subview.frame)]];
}

- (void)setRenderType:(FlameNativeRenderType)renderType {
    _renderType = renderType;
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

- (void)didEndPlayingVideoInAdView:(ATNativeADView *)adView placementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
    [self remove];
}

- (void)didCloseDetailInAdView:(ATNativeADView *)adView
                   placementID:(NSString *)placementID
                         extra:(NSDictionary *)extra{
    [FlameLogger i:@"[AtNativeAdapter] Detail page closed"];

    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }

    [self remove];
}

#pragma mark - 正确绑定关闭按钮回调

/// 原生广告点击了关闭按钮（真正的广告关闭事件）
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

#endif // FLAME_BUILD_TK / 默认 TK
