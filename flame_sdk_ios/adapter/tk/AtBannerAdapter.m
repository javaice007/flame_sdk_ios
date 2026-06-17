//
//  AtBannerAdapter.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/21.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import "AtBannerAdapter.h"
#import "FlameBannerAdMaterial.h"
#import "FlameBannerAdRenderSlots.h"
#import "FlameErrorCode.h"
#import "FlameLogger.h"

@implementation AtBannerAdapter

- (instancetype)initWithPlacementId:(NSString *)atPlacementId
                         renderType:(FlameBannerRenderType)renderType
                           listener:(id<FlameBannerListener>)listener {
    self = [super init];
    if (self) {
        _atPlacementId = [atPlacementId copy];
        _listener = listener;
        _localExtra = [[NSMutableDictionary alloc] init];
        _renderType = renderType;
        _materials = @[];
        _managedAssetViews = @[];
        _hasShownPreparedBanner = NO;
        _boundMaterialIndex = NSNotFound;
    }
    return self;
}

#pragma mark - FlameBannerAd

- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height
       viewController:(UIViewController *)viewController {
    [self loadWithUserId:nil
          userCustomData:nil
                   width:width
                  height:height
          viewController:viewController];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height
        viewController:(UIViewController *)viewController {
    if (self.atPlacementId == nil || self.atPlacementId.length == 0) {
        [self notifyError:ERROR_CODE_INVALID_AD_PLACEMENT desc:@"Invalid mapping for placementId"];
        return;
    }

    if (viewController == nil) {
        [self notifyError:ERROR_CODE_INVALID_PARAM desc:@"viewController is required"];
        return;
    }

    if (width <= 0 || height <= 0 || isnan(width) || isnan(height) || isinf(width) || isinf(height)) {
        [self notifyError:ERROR_CODE_INVALID_PARAM
                     desc:[NSString stringWithFormat:@"Invalid ad size: %.2f x %.2f", width, height]];
        return;
    }

    self.viewController = viewController;
    self.adSize = CGSizeMake(width, height);
    self.materials = @[];

    [self.localExtra removeAllObjects];
    if (userId.length > 0) {
        self.localExtra[kATAdLoadingExtraUserIDKey] = userId;
    }
    if (userCustomData.length > 0) {
        self.localExtra[kATAdLoadingExtraUserDataKeywordKey] = userCustomData;
    }
    [self.localExtra setObject:[NSValue valueWithCGSize:self.adSize]
                        forKey:kATAdLoadingExtraBannerAdSizeKey];

    if (self.renderType == FlameBannerRenderTypeSelfRender) {
        [self cleanupPreparedBannerViews];
    }

    [[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId
                                                 extra:self.localExtra
                                        viewController:viewController
                                              delegate:self];
}

- (BOOL)isLoading {
    if (self.atPlacementId.length == 0) {
        return NO;
    }
    ATCheckLoadModel *status = [[ATAdManager sharedManager] checkBannerLoadStatusForPlacementID:self.atPlacementId];
    return status ? status.isLoading : NO;
}

- (BOOL)isReady {
    if (self.atPlacementId.length == 0) {
        return NO;
    }
    if (self.viewController) {
        return [[ATAdManager sharedManager] bannerAdReadyForPlacementID:self.atPlacementId
                                                     showViewController:self.viewController];
    }
    return [[ATAdManager sharedManager] bannerAdReadyForPlacementID:self.atPlacementId];
}

- (UIView *)retrieveAdView {
    if (self.renderType == FlameBannerRenderTypeSelfRender) {
        [FlameLogger i:@"[AtBannerAdapter] SelfRender mode: use retrieveMaterials + bindMaterialAtIndex:slots: instead of retrieveAdView"];
        return nil;
    }

    if (![self isReady]) {
        [FlameLogger i:@"Banner Ad is not ready in SDK."];
        return nil;
    }

    ATShowConfig *config = [[ATShowConfig alloc] initWithScene:@"" showCustomExt:@""];
    config.showViewController = self.viewController;

    ATBannerView *bannerView = [[ATAdManager sharedManager] retrieveBannerViewForPlacementID:self.atPlacementId
                                                                                       config:config];
    if (bannerView) {
        bannerView.delegate = self;
        bannerView.presentingViewController = self.viewController;
        if (!CGSizeEqualToSize(self.adSize, CGSizeZero)) {
            bannerView.frame = CGRectMake(0, 0, self.adSize.width, self.adSize.height);
            [bannerView setNeedsLayout];
            [bannerView layoutIfNeeded];
        }
    }
    return bannerView;
}

- (NSArray<FlameBannerAdMaterial *> *)retrieveMaterials {
    return self.materials ?: @[];
}

- (void)bindMaterialAtIndex:(NSInteger)index
                      slots:(FlameBannerAdRenderSlots *)slots {
    if (self.renderType != FlameBannerRenderTypeSelfRender) {
        [FlameLogger e:@"[AtBannerAdapter] bindMaterialAtIndex is only available in self-render mode."];
        return;
    }

    if (index < 0 || index >= self.materials.count) {
        [FlameLogger e:@"[AtBannerAdapter] bindMaterialAtIndex failed: invalid index."];
        return;
    }

    if (slots.containerView == nil) {
        [FlameLogger e:@"[AtBannerAdapter] bindMaterialAtIndex failed: containerView is required."];
        return;
    }

    if (self.bannerView == nil || self.nativeBannerView == nil) {
        [FlameLogger e:@"[AtBannerAdapter] bindMaterialAtIndex failed: self-render banner is not prepared."];
        return;
    }

    [self unbindMaterial];

    UIView *containerView = slots.containerView;
    NSMutableArray<UIView *> *managedViews = [NSMutableArray array];
    [self mountManagedView:[self resolvedMediaAssetView] intoSlot:slots.mediaSlotView managedViews:managedViews];
    [self mountManagedView:[self resolvedLogoView] intoSlot:slots.logoSlotView managedViews:managedViews];
    [self mountManagedView:self.nativeBannerView.ADLabel intoSlot:slots.adMarkSlotView managedViews:managedViews];
    [self mountManagedView:self.nativeBannerView.dislikeButton intoSlot:slots.closeSlotView managedViews:managedViews];
    self.managedAssetViews = managedViews;

    NSArray<UIView *> *clickableViews = [self resolvedClickableViewsForSlots:slots containerView:containerView];
    [self.nativeBannerView registerClickableViewArray:clickableViews];

    self.boundMaterialIndex = index;
    if (!self.hasShownPreparedBanner) {
        [self.nativeBannerView showAd];
        self.hasShownPreparedBanner = YES;
    }

    [FlameLogger i:@"[AtBannerAdapter] Self-render material bound successfully."];
}

- (void)unbindMaterial {
    for (UIView *view in self.managedAssetViews) {
        [view removeFromSuperview];
    }
    self.managedAssetViews = @[];
    self.boundMaterialIndex = NSNotFound;
}

- (void)remove {
    if (self.renderType == FlameBannerRenderTypeSelfRender) {
        [self unbindMaterial];
        [FlameLogger i:@"[AtBannerAdapter] SelfRender mode: unbound current material."];
        return;
    }

    [FlameLogger i:@"Note: View is managed by upper layer, please set your view reference to nil."];
}

- (void)destroy {
    [self cleanupPreparedBannerViews];

    _listener = nil;
    [self.localExtra removeAllObjects];
    _localExtra = nil;
    _adSize = CGSizeZero;
    _atPlacementId = nil;
    _viewController = nil;
    _materials = nil;
    _managedAssetViews = nil;
}

#pragma mark - ATAdLoadingDelegate

- (void)didFailToLoadADWithPlacementID:(NSString *)placementID error:(NSError *)error {
    [self notifyError:[NSString stringWithFormat:@"%ld", (long)error.code]
                 desc:error.localizedDescription ?: @"Load banner ad failed"];
}

- (void)didFinishLoadingADWithPlacementID:(NSString *)placementID {
    if (self.renderType == FlameBannerRenderTypeSelfRender) {
        [self prepareSelfRenderBanner];
        return;
    }

    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

#pragma mark - Self-render helpers

- (void)prepareSelfRenderBanner {
    if (![self isReady]) {
        [self notifyError:@"NOT_READY" desc:@"Banner ad is not ready"];
        return;
    }

    ATShowConfig *config = [[ATShowConfig alloc] initWithScene:@"" showCustomExt:@""];
    config.showViewController = self.viewController;

    __block ATNativeBannerView *capturedNativeBannerView = nil;
    ATBannerView *bannerView = [[ATAdManager sharedManager] retrieveBannerViewForPlacementID:self.atPlacementId
                                                                                       config:config
                                                                     nativeMixBannerViewBlock:^(ATNativeBannerView *nativeBannerView) {
        capturedNativeBannerView = nativeBannerView;
    }];

    if (bannerView == nil || capturedNativeBannerView == nil) {
        [self notifyError:@"NO_BANNER_VIEW" desc:@"Failed to prepare self-render banner view"];
        return;
    }

    bannerView.delegate = self;
    bannerView.presentingViewController = self.viewController;
    if (!CGSizeEqualToSize(self.adSize, CGSizeZero)) {
        bannerView.frame = CGRectMake(0, 0, self.adSize.width, self.adSize.height);
    }

    self.bannerView = bannerView;
    self.nativeBannerView = capturedNativeBannerView;
    self.hasShownPreparedBanner = NO;
    self.boundMaterialIndex = NSNotFound;

    FlameBannerAdMaterial *material = [self buildMaterialFromNativeBannerView:capturedNativeBannerView];
    if (material == nil) {
        [self cleanupPreparedBannerViews];
        [self notifyError:@"NO_MATERIAL" desc:@"Failed to extract banner material"];
        return;
    }

    self.materials = @[material];

    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
    if ([self.listener respondsToSelector:@selector(onAdMaterialReady:)]) {
        [self.listener onAdMaterialReady:self.materials];
    }
}

- (FlameBannerAdMaterial *)buildMaterialFromNativeBannerView:(ATNativeBannerView *)nativeBannerView {
    id<ATNativeMaterialProtocol> nativeAd = nativeBannerView.nativeAdMaterial;
    if (nativeAd == nil) {
        return nil;
    }

    FlameBannerAdMaterial *material = [[FlameBannerAdMaterial alloc] init];
    material.title = nativeAd.title ?: @"";
    material.desc = nativeAd.mainText ?: @"";
    material.ctaText = nativeAd.ctaText ?: @"";
    material.iconUrl = nativeAd.iconUrl ?: @"";
    material.coverUrl = nativeAd.imageUrl ?: @"";
    material.advertiser = nativeAd.advertiser ?: @"";
    material.domain = nativeAd.domain ?: @"";
    material.warning = nativeAd.warning ?: @"";
    material.rating = [self numberValueForObject:nativeAd key:@"rating"];
    material.source = [self stringValueForObject:nativeAd key:@"source"];
    material.sponsor = [self resolvedSponsorFromNativeBannerView:nativeBannerView nativeAd:nativeAd];
    material.hasVideo = nativeAd.videoUrl.length > 0 || nativeBannerView.netWorkMediaView != nil;
    material.requiresAdvertiser = nativeBannerView.advertiserLabel != nil;
    material.requiresDomain = nativeBannerView.domainLabel != nil;
    material.requiresWarning = nativeBannerView.warningLabel != nil;
    return material;
}

- (UIView *)resolvedMediaAssetView {
    if (self.nativeBannerView.netWorkMediaBackView) {
        return self.nativeBannerView.netWorkMediaBackView;
    }
    if (self.nativeBannerView.netWorkMediaView) {
        return self.nativeBannerView.netWorkMediaView;
    }
    return self.nativeBannerView.mainImageView;
}

- (UIView *)resolvedLogoView {
    if (self.nativeBannerView.netWorkOptionView) {
        return self.nativeBannerView.netWorkOptionView;
    }
    return self.nativeBannerView.logoImageView;
}

- (NSArray<UIView *> *)resolvedClickableViewsForSlots:(FlameBannerAdRenderSlots *)slots
                                        containerView:(UIView *)containerView {
    NSMutableOrderedSet<UIView *> *clickableViews = [NSMutableOrderedSet orderedSet];
    for (UIView *clickableView in slots.clickableViews) {
        if (clickableView == nil) {
            continue;
        }
        if (clickableView == slots.closeSlotView || clickableView == slots.adMarkSlotView) {
            continue;
        }
        [clickableViews addObject:clickableView];
    }

    if (clickableViews.count == 0 && containerView != nil) {
        [clickableViews addObject:containerView];
    }
    return clickableViews.array;
}

- (NSString *)resolvedSponsorFromNativeBannerView:(ATNativeBannerView *)nativeBannerView
                                         nativeAd:(id<ATNativeMaterialProtocol>)nativeAd {
    NSString *sponsorText = [self stringValueForObject:nativeBannerView.sponsorLabel key:@"text"];
    if (sponsorText.length > 0) {
        return sponsorText;
    }

    NSString *sourceText = [self stringValueForObject:nativeAd key:@"source"];
    if (sourceText.length > 0) {
        return sourceText;
    }
    return @"";
}

- (NSString *)stringValueForObject:(id)object key:(NSString *)key {
    if (object == nil || key.length == 0) {
        return @"";
    }

    @try {
        id value = [object valueForKey:key];
        if ([value isKindOfClass:[NSString class]]) {
            return value;
        }
        if ([value respondsToSelector:@selector(stringValue)]) {
            return [value stringValue] ?: @"";
        }
    } @catch (__unused NSException *exception) {
    }
    return @"";
}

- (NSNumber *)numberValueForObject:(id)object key:(NSString *)key {
    if (object == nil || key.length == 0) {
        return nil;
    }

    @try {
        id value = [object valueForKey:key];
        if ([value isKindOfClass:[NSNumber class]]) {
            return value;
        }
        if ([value isKindOfClass:[NSString class]]) {
            NSString *stringValue = (NSString *)value;
            if (stringValue.length == 0) {
                return nil;
            }
            return @([stringValue doubleValue]);
        }
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

- (void)mountManagedView:(UIView *)managedView
                intoSlot:(UIView *)slotView
            managedViews:(NSMutableArray<UIView *> *)managedViews {
    if (managedView == nil || slotView == nil) {
        return;
    }

    managedView.frame = slotView.bounds;
    managedView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [slotView addSubview:managedView];
    if (![managedViews containsObject:managedView]) {
        [managedViews addObject:managedView];
    }
}

- (void)cleanupPreparedBannerViews {
    [self unbindMaterial];
    [self.bannerView destroyBanner];
    self.bannerView = nil;
    self.nativeBannerView = nil;
    self.materials = @[];
}

- (void)notifyError:(NSString *)code desc:(NSString *)desc {
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:code desc:desc];
    }
}

#pragma mark - ATBannerDelegate

- (void)bannerView:(ATBannerView *)bannerView didTapCloseButtonWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if (self.renderType == FlameBannerRenderTypeSelfRender) {
        [self unbindMaterial];
    }
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

- (void)bannerView:(ATBannerView *)bannerView didClickWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

- (void)bannerView:(ATBannerView *)bannerView didShowAdWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

@end

#endif // FLAME_BUILD_TK / 默认 TK
