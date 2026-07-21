//
//  TbNativeSelfRenderView.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "TbNativeSelfRenderView.h"
#import "FlameLogger.h"
#import <WindMillSDK/WindMillSDK.h>

// =============================================================================
// Phase 5A.18D-C 设计说明（对齐官方 ToBid demo：NativeAdView.swift / NativeAdStyle.swift）
// =============================================================================
//
// 物料字段映射表（编码前已从本地 WindMillSDK.h Header 核对）：
//
// | 概念         | 来源                                   | 本 view 处理                       |
// |---|---|---|
// | title        | WindMillNativeAd.title                  | 自建 _titleLabel                    |
// | desc         | WindMillNativeAd.desc                   | 自建 _descLabel                     |
// | icon         | WindMillNativeAd.iconUrl                | 自建 _iconImageView（NSURLSession） |
// | callToAction | WindMillNativeAd.callToAction           | 自建 _ctaButton                     |
// | rating       | WindMillNativeAd.rating                 | 自建 _ratingLabel                   |
// | 主图（单图） | WindMillNativeAdView.mainImageView      | 复用 WindMill 的 view（reparent）   |
// | 主图（视频） | WindMillNativeAdView.mediaView          | 复用 WindMill 的 view（reparent）   |
// | 组图（三图） | WindMillNativeAdView.imageViewList      | 复用 WindMill 的 view（reparent）   |
// | ad logo      | WindMillNativeAdView.logoView           | 复用 WindMill 的 view（reparent）   |
// | dislike      | WindMillNativeAdView.dislikeButton      | 复用 WindMill 的 view（reparent）   |
//
// 重要变更（vs Phase 5A.18D-B）：
// - 5A.18D-B：自建 mainImageView + NSURLSession 下载 → 与 WindMill mainImageView 冲突 + 主图加载不可靠
// - 5A.18D-C：完全复用 WindMill 提供的 mainImageView/mediaView/logoView/dislikeButton
//   （这些是 WindMillSDK.h 公开 readonly 属性，refreshData: 后 WindMill 自动加载图片/创建 view）
//   仅自建 icon（WindMill 不提供 icon view，官方 demo 也是自建 + sm_setImage）
//
// Reparent 风险评估：
// - reparent（[self addSubview:windMillView]）不会改变 view 所有权，view 归 nativeAdView 释放
// - 官方 demo 也是这个模式（TBNativeAdView.swift:70 adView.addSubview(titleLabel) 把自建挂到 adView）
// - cleanup 不主动 removeFromSuperview WindMill 的 view（让 nativeAdView 整体释放时处理）

@interface TbNativeSelfRenderView ()

// 自建控件
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *ratingLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIButton *ctaButton;

// WindMill 提供的 view（weak，归 nativeAdView 管）
@property (nonatomic, weak) WindMillNativeAdView *nativeAdView;
@property (nonatomic, weak) UIView *mainMediaView;       // mainImageView 或 mediaView
@property (nonatomic, strong) NSMutableArray<UIImageView *> *groupImageViews;  // 组图（strong 引用避免被 WindMill 释放？保持 weak）

// 物料 + 布局参数
@property (nonatomic, strong) WindMillNativeAd *nativeAd;
@property (nonatomic, assign) CGSize containerSize;
@property (nonatomic, assign) WindMillFeedADMode feedADMode;
@property (nonatomic, assign) BOOL isVideoAd;

// 图片下载任务（可取消）
@property (nonatomic, strong) NSMutableArray<NSURLSessionDataTask *> *imageTasks;

// =============================================================================
// Phase 5A.18D-B1：异步图片回调生命周期加固
// =============================================================================
// 缺口背景：原实现 loadImageWithURL: 回调只做 error/data 校验，没校验
//   - View 是否已 cleanup（destroyed/re-enter 场景）
//   - 该 view 实例是否仍是当前 icon 容器
//   - 该请求 generation 是否仍是最新
// 即使 cleanup 取消了 task，NSURLSession cancel 后仍会回调（error=cancelled），
// dispatch_async 到主线程后才执行——若无校验，可能在已 cleanup 的 view 上
// 触发 setNeedsLayout 或更新到已被复用的 imageView。
//
// 加固策略（参考 spec §四）：
//   - _cleanedUp：cleanup 时置 YES，init 时置 NO（用于快速短路）
//   - _imageGeneration：每次 init/cleanup 时 +1，请求时捕获 requestGeneration
//   - _currentIconURL：当前正在请求的 icon URL，回调时校验一致性
//   - completion 内同时校验：self / cleanedUp / generation / imageView 身份 / URL 一致
// =============================================================================

/// 是否已 cleanup（YES 时所有迟到图片回调直接丢弃）
@property (nonatomic, assign) BOOL cleanedUp;

/// 图片请求 generation（每次 init 或 cleanup 时 +1）
@property (nonatomic, assign) NSUInteger imageGeneration;

/// 当前 icon 请求 URL（用于回调一致性校验，防止 URL 复用冲突）
@property (nonatomic, copy, nullable) NSString *currentIconURL;

@end

@implementation TbNativeSelfRenderView

- (instancetype)initWithNativeAd:(WindMillNativeAd *)nativeAd
                    nativeAdView:(WindMillNativeAdView *)nativeAdView
                    containerSize:(CGSize)containerSize {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _nativeAd = nativeAd;
        _nativeAdView = nativeAdView;
        _containerSize = containerSize;
        _feedADMode = nativeAd.feedADMode;
        _isVideoAd = nativeAd.isVideoAd;
        _imageTasks = [NSMutableArray array];
        _groupImageViews = [NSMutableArray array];
        // 5A.18D-B1：生命周期字段初始值
        _cleanedUp = NO;
        _imageGeneration = 1;  // 起始非 0，便于 dispatch_async 捕获时区分"未初始化"
        [self setupSubviews];
        [self applyMaterial];
    }
    return self;
}

#pragma mark - Setup

- (void)setupSubviews {
    self.backgroundColor = [UIColor whiteColor];
    self.clipsToBounds = YES;

    // icon（自建，WindMill 不提供）
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconImageView.clipsToBounds = YES;
    self.iconImageView.layer.cornerRadius = 8;
    self.iconImageView.layer.masksToBounds = YES;
    [self addSubview:self.iconImageView];

    // title（自建）
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.textAlignment = NSTextAlignmentLeft;
    [self addSubview:self.titleLabel];

    // rating（自建）
    self.ratingLabel = [[UILabel alloc] init];
    self.ratingLabel.font = [UIFont systemFontOfSize:11];
    self.ratingLabel.textColor = [UIColor grayColor];
    self.ratingLabel.numberOfLines = 1;
    [self addSubview:self.ratingLabel];

    // desc（自建）
    self.descLabel = [[UILabel alloc] init];
    self.descLabel.font = [UIFont systemFontOfSize:13];
    self.descLabel.textColor = [UIColor darkTextColor];
    self.descLabel.numberOfLines = 2;
    [self addSubview:self.descLabel];

    // CTA button（自建，仅样式，点击由 setClickableViews 注册）
    self.ctaButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.ctaButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.ctaButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.ctaButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.95 alpha:1.0];
    self.ctaButton.layer.cornerRadius = 12;
    self.ctaButton.contentEdgeInsets = UIEdgeInsetsMake(6, 14, 6, 14);
    [self addSubview:self.ctaButton];
}

- (void)applyMaterial {
    WindMillNativeAd *ad = self.nativeAd;
    if (!ad) return;

    // 文本字段（空则隐藏）
    self.titleLabel.text = ad.title.length > 0 ? ad.title : @"";
    self.titleLabel.hidden = (ad.title.length == 0);

    self.descLabel.text = ad.desc.length > 0 ? ad.desc : @"";
    self.descLabel.hidden = (ad.desc.length == 0);

    NSString *ctaText = ad.callToAction.length > 0 ? ad.callToAction : @"了解更多";
    [self.ctaButton setTitle:ctaText forState:UIControlStateNormal];

    // rating（>0 才显示）
    if (ad.rating > 0) {
        self.ratingLabel.text = [NSString stringWithFormat:@"⭐️ %.1f", ad.rating];
        self.ratingLabel.hidden = NO;
    } else {
        self.ratingLabel.hidden = YES;
    }

    // icon（WindMill 不提供，自建 + NSURLSession 下载）
    // 5A.18D-B1：每次 applyMaterial 前先递增 generation（用于回调时区分新旧请求）
    self.imageGeneration += 1;
    if (ad.iconUrl.length > 0) {
        self.currentIconURL = [ad.iconUrl copy];  // 记录当前 URL，回调时校验
        [self loadImageWithURL:ad.iconUrl imageView:self.iconImageView];
        self.iconImageView.hidden = NO;
    } else {
        self.currentIconURL = nil;
        self.iconImageView.hidden = YES;
    }

    // ==========================================================================
    // 主图 / 媒体：复用 WindMillNativeAdView 提供的 readonly view（reparent 到本 view）
    // 参考官方 NativeAdStyle.swift:23-35 的分支逻辑
    // ==========================================================================
    [self reparentMediaViewsFromNativeAdView];

    [self setNeedsLayout];
}

/// 把 WindMillNativeAdView 提供的 mainImageView / mediaView / imageViewList / logoView /
/// dislikeButton reparent 到本 view 下，便于统一做 manual frame 布局。
- (void)reparentMediaViewsFromNativeAdView {
    WindMillNativeAdView *adView = self.nativeAdView;
    if (!adView) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] selfRender reparentMediaViews: nativeAdView nil"];
        return;
    }

    // 主媒体 view：视频优先 mediaView，否则 mainImageView
    if (self.isVideoAd && adView.mediaView) {
        self.mainMediaView = adView.mediaView;
        [self addSubview:adView.mediaView];
    } else if (adView.mainImageView) {
        self.mainMediaView = adView.mainImageView;
        [self addSubview:adView.mainImageView];
    } else if (self.feedADMode == WindMillFeedADModeGroupImage && adView.imageViewList.count > 0) {
        // 组图：reparent 所有 imageViewList（本阶段只渲染首图或三图横排）
        for (UIImageView *imgView in adView.imageViewList) {
            if (imgView) {
                [self addSubview:imgView];
                [self.groupImageViews addObject:imgView];
            }
        }
    } else {
        [FlameLogger w:[NSString stringWithFormat:
            @"[TB_NATIVE_DIAG] selfRender reparentMediaViews: no media/main/group view "
            "(feedADMode=%u isVideoAd=%d)",
            (unsigned int)self.feedADMode, self.isVideoAd]];
    }

    // logoView（广告标识，左下角）
    if (adView.logoView) {
        [self addSubview:adView.logoView];
    }

    // dislikeButton（右上角）
    if (adView.dislikeButton) {
        [self addSubview:adView.dislikeButton];
    }

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] selfRender reparentMediaViews: mainMediaView=%p groupCount=%lu "
        "logoView=%p dislikeButton=%p feedADMode=%u",
        self.mainMediaView, (unsigned long)self.groupImageViews.count,
        adView.logoView, adView.dislikeButton, (unsigned int)self.feedADMode]];
}

#pragma mark - Layout（manual frame，对齐官方 NativeAdStyle.swift 间距）

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.containerSize.width > 0 ? self.containerSize.width : self.bounds.size.width;
    if (width <= 0) width = [UIScreen mainScreen].bounds.size.width;

    CGFloat padding = 12;
    CGFloat currentY = padding;

    // ========= 顶部行：icon + (title / rating) + dislike 右上 =========
    CGFloat iconSize = 50;  // 对齐官方 NativeAdStyle.swift:123 (50×50)
    BOOL hasIcon = !self.iconImageView.hidden;

    if (hasIcon) {
        self.iconImageView.frame = CGRectMake(padding, currentY, iconSize, iconSize);
    }

    // dislikeButton 右上角（WindMill 提供）
    if (self.nativeAdView.dislikeButton && !self.nativeAdView.dislikeButton.hidden) {
        self.nativeAdView.dislikeButton.frame = CGRectMake(width - 24 - padding, padding, 24, 24);
    }

    // title/rating 在 icon 右侧
    CGFloat titleX = hasIcon ? (padding + iconSize + 10) : padding;  // 对齐官方 left=iconSize+padding*2
    CGFloat titleRightReserved = 30;  // 右侧给 dislikeButton 留位置
    CGFloat titleWidth = width - titleX - padding - titleRightReserved;
    if (titleWidth < 80) titleWidth = width - titleX - padding;  // 兜底

    // title 高度
    if (!self.titleLabel.hidden) {
        CGSize titleMaxSize = CGSizeMake(titleWidth, CGFLOAT_MAX);
        CGRect titleRect = [self.titleLabel.text boundingRectWithSize:titleMaxSize
                                                             options:NSStringDrawingUsesLineFragmentOrigin
                                                          attributes:@{NSFontAttributeName: self.titleLabel.font}
                                                             context:nil];
        CGFloat titleHeight = ceil(titleRect.size.height);
        if (titleHeight < 20) titleHeight = 20;
        self.titleLabel.frame = CGRectMake(titleX, currentY, titleWidth, titleHeight);

        // rating 紧贴 title 下方（如有）
        if (!self.ratingLabel.hidden) {
            CGFloat ratingY = currentY + titleHeight + 2;
            CGSize ratingSize = [self.ratingLabel sizeThatFits:CGSizeMake(titleWidth, CGFLOAT_MAX)];
            self.ratingLabel.frame = CGRectMake(titleX, ratingY, titleWidth, ratingSize.height);
            currentY = ratingY + ratingSize.height + padding;
        } else {
            currentY = currentY + titleHeight + padding;
        }
    } else if (hasIcon) {
        // 无 title 但有 icon，仍按 icon 高度推进
        currentY = currentY + iconSize + padding;
    }

    // ========= desc =========
    if (!self.descLabel.hidden) {
        CGSize descMaxSize = CGSizeMake(width - padding * 2, CGFLOAT_MAX);
        CGRect descRect = [self.descLabel.text boundingRectWithSize:descMaxSize
                                                            options:NSStringDrawingUsesLineFragmentOrigin
                                                         attributes:@{NSFontAttributeName: self.descLabel.font}
                                                            context:nil];
        CGFloat descHeight = ceil(descRect.size.height);
        self.descLabel.frame = CGRectMake(padding, currentY, width - padding * 2, descHeight);
        currentY = currentY + descHeight + padding;
    }

    // ========= 主图 / 视频 / 组图 =========
    CGFloat imageWidth = width - padding * 2;
    CGFloat mediaBottomY = currentY;  // 默认无主图

    if (self.mainMediaView) {
        // 单一媒体 view（mainImageView 或 mediaView）
        CGFloat imageHeight = [self mediaHeightForWidth:imageWidth];
        self.mainMediaView.frame = CGRectMake(padding, currentY, imageWidth, imageHeight);
        self.mainMediaView.clipsToBounds = YES;
        mediaBottomY = currentY + imageHeight;
        currentY = mediaBottomY + padding;
    } else if (self.groupImageViews.count > 0) {
        // 组图：三图横排（对齐官方 NativeAdStyle.swift:63-68 height = width * 0.3）
        CGFloat groupHeight = imageWidth * 0.3;
        CGFloat cellSpacing = 6;
        CGFloat cellWidth = (imageWidth - cellSpacing * (self.groupImageViews.count - 1)) / self.groupImageViews.count;
        CGFloat x = padding;
        for (UIImageView *imgView in self.groupImageViews) {
            imgView.frame = CGRectMake(x, currentY, cellWidth, groupHeight);
            imgView.clipsToBounds = YES;
            x = x + cellWidth + cellSpacing;
        }
        mediaBottomY = currentY + groupHeight;
        currentY = mediaBottomY + padding;
    }

    // ========= CTA button（右下） =========
    [self.ctaButton sizeToFit];
    CGRect ctaFit = self.ctaButton.frame;
    ctaFit.size.width = ctaFit.size.width + 28;  // 补 contentEdgeInsets 左右 14*2
    ctaFit.size.height = ctaFit.size.height + 12;  // 补上下 6*2
    ctaFit.origin.x = width - padding - ctaFit.size.width;
    ctaFit.origin.y = currentY;
    self.ctaButton.frame = ctaFit;
    CGFloat ctaBottomY = currentY + ctaFit.size.height;
    currentY = ctaBottomY + padding;

    // ========= logoView（左下角，与 CTA 同行或底部） =========
    if (self.nativeAdView.logoView) {
        // logo 放在 CTA 左侧（与 CTA 底对齐）
        CGFloat logoY = ctaBottomY - 15;  // 默认 15 高度（参考官方 NativeAdStyle.swift:137 fallback CGSize(30,30)）
        self.nativeAdView.logoView.frame = CGRectMake(padding, logoY, 30, 15);
        // 不额外推进 currentY（logo 与 cta 同行，不影响总高度）
    }

    // ========= 更新自身总高度（驱动 nativeAdView 高度） =========
    CGRect f = self.frame;
    f.size.width = width;
    f.size.height = currentY;
    self.frame = f;

    // 通知 Adapter 高度变化（Adapter 据此回写 nativeAdView.frame.size.height）
    if (self.onLayoutChanged) {
        self.onLayoutChanged(currentY);
    }
}

/// 根据 feedADMode 计算主图高度（对齐官方 NativeAdStyle.swift 0.5625/0.3 等比例）
- (CGFloat)mediaHeightForWidth:(CGFloat)mediaWidth {
    switch (self.feedADMode) {
        case WindMillFeedADModePortraitImage:
            return mediaWidth * 4.0 / 3.0;  // 竖图 3:4
        case WindMillFeedADModeSmallImage:
            return 120;  // 小图固定高度
        case WindMillFeedADModeVideo:
        case WindMillFeedADModeVideoPortrait:
        case WindMillFeedADModeVideoLandSpace:
            return mediaWidth * 9.0 / 16.0;  // 视频 16:9
        case WindMillFeedADModeLargeImage:
        case WindMillFeedADModeGroupImage:
        default:
            return mediaWidth * 9.0 / 16.0;  // 大图 16:9（官方 0.5625）
    }
}

#pragma mark - clickableViews（供 Adapter 注册）

- (NSArray<UIView *> *)clickableViews {
    NSMutableArray<UIView *> *views = [NSMutableArray array];

    // 自建控件（icon 需要图片加载完才有意义，但 WindMill 内部会延迟响应，宽松注册）
    if (!self.iconImageView.hidden) {
        [views addObject:self.iconImageView];
    }
    if (!self.titleLabel.hidden && self.titleLabel.text.length > 0) {
        [views addObject:self.titleLabel];
    }
    if (!self.descLabel.hidden && self.descLabel.text.length > 0) {
        [views addObject:self.descLabel];
    }
    [views addObject:self.ctaButton];  // CTA 始终可点击

    // WindMill 提供的主媒体 view（官方 NativeAdStyle.swift:162-172 注册 mediaView / mainImageView）
    if (self.mainMediaView) {
        [views addObject:self.mainMediaView];
    }
    for (UIImageView *imgView in self.groupImageViews) {
        [views addObject:imgView];
    }

    // dislikeButton（WindMill 提供，用于"不感兴趣"关闭）
    if (self.nativeAdView.dislikeButton) {
        [views addObject:self.nativeAdView.dislikeButton];
    }

    return views;
}

#pragma mark - Image loading（最小内部实现，仅用于 icon；主图由 WindMill 加载）

- (void)loadImageWithURL:(NSString *)urlString imageView:(UIImageView *)imageView {
    if (urlString.length == 0 || !imageView) return;
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    // 5A.18D-B1：捕获请求时 generation / URL / imageView 身份
    // 所有捕获都用 weak（避免延长 view 生命周期），主线程回调时再做强校验
    NSUInteger requestGeneration = self.imageGeneration;
    NSString *requestURLString = [urlString copy];
    __weak UIImageView *weakImageView = imageView;
    __weak typeof(self) weakSelf = self;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // NSURLSession cancel 后仍会调本回调（error=NSURLErrorCancelled），
        // dispatch_async 到主线程后必须做完整校验，不能假定 cancel 就不回调
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            UIImageView *strongImageView = weakImageView;

            // 完整 8 重校验（spec §四）：
            // 1. self 存在
            if (!strongSelf) {
                return;
            }
            // 2. View 未 cleanup（destroyed/re-enter 场景）
            if (strongSelf.cleanedUp) {
                return;
            }
            // 3. generation 一致（新物料请求已发出，本回调过期）
            if (requestGeneration != strongSelf.imageGeneration) {
                return;
            }
            // 4. 目标 imageView 仍是当前 self.iconImageView（防止 view 复用）
            if (strongImageView != strongSelf.iconImageView) {
                return;
            }
            // 5. 当前 URL 仍与本请求 URL 一致（防止 URL 复用冲突）
            NSString *currentURL = strongSelf.currentIconURL;
            if (!currentURL || ![currentURL isEqualToString:requestURLString]) {
                return;
            }

            // 校验通过，处理结果
            if (error || !data) {
                [FlameLogger d:[NSString stringWithFormat:
                    @"[TB_NATIVE_DIAG] icon load fail: %@ err=%@",
                    urlString, error.localizedDescription]];
                strongImageView.hidden = YES;
                return;
            }
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                strongImageView.image = image;
                [strongSelf setNeedsLayout];  // 触发重新布局（icon 加载完后高度可能变化）
            } else {
                strongImageView.hidden = YES;
            }
        });
    }];
    [task resume];
    [self.imageTasks addObject:task];
}

#pragma mark - cleanup

- (void)cleanup {
    // 5A.18D-B1：先标记 cleanedUp + 递增 generation，确保 dispatch_async 队列里的
    // 迟到回调即使后续到达也会被 loadImageWithURL 回调里的 8 重校验直接丢弃
    self.cleanedUp = YES;
    self.imageGeneration += 1;
    self.currentIconURL = nil;

    // 取消进行中的图片下载（仅 icon）
    for (NSURLSessionDataTask *task in self.imageTasks) {
        [task cancel];
    }
    [self.imageTasks removeAllObjects];

    // 移除自建子控件（不主动 remove WindMill 的 mainImageView/mediaView/logoView/dislikeButton，
    // 它们归 nativeAdView 管，nativeAdView 整体释放时会处理）
    [self.iconImageView removeFromSuperview];
    [self.titleLabel removeFromSuperview];
    [self.ratingLabel removeFromSuperview];
    [self.descLabel removeFromSuperview];
    [self.ctaButton removeFromSuperview];

    self.iconImageView = nil;
    self.titleLabel = nil;
    self.ratingLabel = nil;
    self.descLabel = nil;
    self.ctaButton = nil;

    [self.groupImageViews removeAllObjects];
    self.mainMediaView = nil;
    self.nativeAd = nil;
    self.nativeAdView = nil;
    self.onLayoutChanged = nil;
    // cleanedUp / imageGeneration 不重置：cleanup 后 view 不再复用，
    // 保持 cleanedUp=YES / generation 已 +1 即可阻断所有迟到回调
}

@end
