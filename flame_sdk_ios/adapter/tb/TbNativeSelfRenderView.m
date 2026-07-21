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

// 物料字段映射表（编码前已从本地 WindMillSDK.h Header 核对）：
//
// | Flame/TK 概念 | AtNativeSelfRenderView 控件 | WindMillNativeAd 字段（Header） | TbNativeSelfRenderView 控件 |
// |---|---|---|---|
// | title         | titleLabel      | title (NSString?)            | _titleLabel      |
// | desc          | textLabel       | desc (NSString?)             | _descLabel       |
// | icon          | iconImageView   | iconUrl (NSString?)          | _iconImageView   |
// | main image    | mainImageView   | imageUrlList[0] / imageModelList[0] | _mainImageView |
// | group image   | (TK 无)         | imageUrlList (1=大图, 3=组图) | _mainImageView（首图，组图本阶段只展示首图） |
// | CTA           | ctaLabel        | callToAction (NSString?)     | _ctaLabel        |
// | advertiser    | advertiserLabel | (WindMillNativeAd 无此字段)   | 不显示            |
// | media/video   | mediaView       | WindMillNativeAdView.mediaView (由 Adapter 注入，不在本 view) | 不在本 view |
// | ad logo       | logoImageView   | WindMillNativeAdView.logoView (由 Adapter 注入) | 不在本 view |
// | dislike       | dislikeButton   | WindMillNativeAdView.dislikeButton (由 Adapter 注入) | 不在本 view |
// | rating        | ratingLabel     | rating (CGFloat)             | _ratingLabel     |
//
// 注：WindMillNativeAd 没有 advertiser / logo / dislikeButton 字段——
//     logoView / dislikeButton 是 WindMillNativeAdView 的属性（由 ToBid 创建），
//     由 Adapter 在挂载本 view 时一并加到 WindMillNativeAdView 上（不在 SelfRenderView 内创建）。
//     本 view 只负责文本/图片类字段（title/desc/icon/main image/cta/rating）。

@interface TbNativeSelfRenderView ()

// 子控件
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *ratingLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIImageView *mainImageView;
@property (nonatomic, strong) UIButton *ctaButton;

// 物料 + 布局参数
@property (nonatomic, strong) WindMillNativeAd *nativeAd;
@property (nonatomic, assign) CGSize containerSize;
@property (nonatomic, assign) WindMillFeedADMode feedADMode;

// 图片下载任务（可取消）
@property (nonatomic, strong) NSMutableArray<NSURLSessionDataTask *> *imageTasks;

@end

@implementation TbNativeSelfRenderView

- (instancetype)initWithNativeAd:(WindMillNativeAd *)nativeAd
                    containerSize:(CGSize)containerSize {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _nativeAd = nativeAd;
        _containerSize = containerSize;
        _feedADMode = nativeAd.feedADMode;
        _imageTasks = [NSMutableArray array];
        [self setupSubviews];
        [self applyMaterial];
    }
    return self;
}

#pragma mark - Setup

- (void)setupSubviews {
    self.backgroundColor = [UIColor whiteColor];

    // icon
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconImageView.clipsToBounds = YES;
    self.iconImageView.layer.cornerRadius = 8;
    [self addSubview:self.iconImageView];

    // title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.numberOfLines = 2;
    [self addSubview:self.titleLabel];

    // rating
    self.ratingLabel = [[UILabel alloc] init];
    self.ratingLabel.font = [UIFont systemFontOfSize:11];
    self.ratingLabel.textColor = [UIColor grayColor];
    [self addSubview:self.ratingLabel];

    // desc
    self.descLabel = [[UILabel alloc] init];
    self.descLabel.font = [UIFont systemFontOfSize:13];
    self.descLabel.textColor = [UIColor darkTextColor];
    self.descLabel.numberOfLines = 2;
    [self addSubview:self.descLabel];

    // main image
    self.mainImageView = [[UIImageView alloc] init];
    self.mainImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.mainImageView.clipsToBounds = YES;
    self.mainImageView.layer.cornerRadius = 6;
    [self addSubview:self.mainImageView];

    // CTA button（仅样式，点击由 setClickableViews 注册）
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

    // icon
    if (ad.iconUrl.length > 0) {
        [self loadImageWithURL:ad.iconUrl imageView:self.iconImageView];
    } else {
        self.iconImageView.hidden = YES;
    }

    // main image：LargeImage / SmallImage / PortraitImage 取 imageUrlList[0]
    // GroupImage 本阶段只展示首图（spec §十三：组图图片不足动态隐藏，不创建空白格）
    NSString *mainImageUrl = nil;
    if (ad.imageUrlList.count > 0) {
        mainImageUrl = ad.imageUrlList.firstObject;
    }
    if (mainImageUrl.length > 0) {
        [self loadImageWithURL:mainImageUrl imageView:self.mainImageView];
    } else {
        // 无主图且无 mediaView（mediaView 由 Adapter 在 WindMillNativeAdView 上判断），
        // 本 view 标记 main image 隐藏；Adapter 会检查是否有 mediaView fallback
        self.mainImageView.hidden = YES;
    }

    [self setNeedsLayout];
}

#pragma mark - Layout（manual frame，参考 TK AtNativeSelfRenderView.m 策略）

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.containerSize.width > 0 ? self.containerSize.width : self.bounds.size.width;
    if (width <= 0) width = [UIScreen mainScreen].bounds.size.width;

    CGFloat padding = 12;
    CGFloat currentY = padding;

    // ========= 顶部行：icon + (title + rating) =========
    CGFloat iconSize = 30;
    BOOL hasIcon = !self.iconImageView.hidden;

    if (hasIcon) {
        self.iconImageView.frame = CGRectMake(padding, currentY, iconSize, iconSize);
    }

    // title/rating 在 icon 右侧
    CGFloat titleX = hasIcon ? (padding + iconSize + 8) : padding;
    CGFloat titleWidth = width - titleX - padding;

    // title 高度
    CGSize titleMaxSize = CGSizeMake(titleWidth, CGFLOAT_MAX);
    CGRect titleRect = [self.titleLabel.text boundingRectWithSize:titleMaxSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName: self.titleLabel.font}
                                                         context:nil];
    CGFloat titleHeight = ceil(titleRect.size.height);
    if (titleHeight < 20) titleHeight = 20;  // 最小高度
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

    // ========= main image =========
    if (!self.mainImageView.hidden) {
        // LargeImage：宽度铺满，高度按 16:9（参考 TK AtNativeSelfRenderView.m）
        // SmallImage：本阶段也铺满（简化，首版聚焦 LargeImage 真机验证）
        // PortraitImage：按 3:4
        CGFloat imageWidth = width - padding * 2;
        CGFloat imageHeight;
        switch (self.feedADMode) {
            case WindMillFeedADModePortraitImage:
                imageHeight = imageWidth * 4.0 / 3.0;
                break;
            case WindMillFeedADModeSmallImage:
                // 小图：固定 120 高（参考常见 native 小图布局）
                imageHeight = 120;
                break;
            case WindMillFeedADModeGroupImage:
                // 组图：本阶段只展示首图，高度同 LargeImage
            case WindMillFeedADModeLargeImage:
            default:
                imageHeight = imageWidth * 9.0 / 16.0;
                break;
        }
        self.mainImageView.frame = CGRectMake(padding, currentY, imageWidth, imageHeight);
        currentY = currentY + imageHeight + padding;
    }

    // ========= CTA button（右下） =========
    [self.ctaButton sizeToFit];
    CGRect ctaFit = self.ctaButton.frame;
    ctaFit.size.width = ctaFit.size.width + 28;  // 补 contentEdgeInsets
    ctaFit.size.height = ctaFit.size.height + 12;
    ctaFit.origin.x = width - padding - ctaFit.size.width;
    ctaFit.origin.y = currentY;
    self.ctaButton.frame = ctaFit;
    currentY = currentY + ctaFit.size.height + padding;

    // 更新自身总高度
    CGRect f = self.frame;
    f.size.width = width;
    f.size.height = currentY;
    self.frame = f;
}

#pragma mark - clickableViews（供 Adapter 注册）

- (NSArray<UIView *> *)clickableViews {
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    if (!self.mainImageView.hidden && self.mainImageView.image != nil) {
        [views addObject:self.mainImageView];
    }
    if (!self.iconImageView.hidden && self.iconImageView.image != nil) {
        [views addObject:self.iconImageView];
    }
    if (!self.titleLabel.hidden && self.titleLabel.text.length > 0) {
        [views addObject:self.titleLabel];
    }
    if (!self.descLabel.hidden && self.descLabel.text.length > 0) {
        [views addObject:self.descLabel];
    }
    [views addObject:self.ctaButton];  // CTA 始终可点击
    return views;
}

#pragma mark - Image loading（最小内部实现，不引入第三方库）

- (void)loadImageWithURL:(NSString *)urlString imageView:(UIImageView *)imageView {
    if (urlString.length == 0 || !imageView) return;
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // generation 校验：通过 task identity + imageView pointer（destroy 后 imageView 被清理，image 设置无效）
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                [FlameLogger d:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] image load fail: %@ err=%@", urlString, error.localizedDescription]];
                imageView.hidden = YES;
                return;
            }
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                imageView.image = image;
                [self setNeedsLayout];
            } else {
                imageView.hidden = YES;
            }
        });
    }];
    [task resume];
    [self.imageTasks addObject:task];
}

#pragma mark - cleanup

- (void)cleanup {
    // 取消进行中的图片下载
    for (NSURLSessionDataTask *task in self.imageTasks) {
        [task cancel];
    }
    [self.imageTasks removeAllObjects];

    // 移除子控件
    for (UIView *sub in self.subviews) {
        [sub removeFromSuperview];
    }
    self.iconImageView = nil;
    self.titleLabel = nil;
    self.ratingLabel = nil;
    self.descLabel = nil;
    self.mainImageView = nil;
    self.ctaButton = nil;
    self.nativeAd = nil;
}

@end
