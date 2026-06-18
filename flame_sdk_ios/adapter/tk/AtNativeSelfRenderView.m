//
//  AtNativeSelfRenderView.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/3/17.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import "AtNativeSelfRenderView.h"

@implementation AtNativeSelfRenderView

- (instancetype)initWithOffer:(ATNativeAdOffer *)offer {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = [UIColor clearColor]; // 透明背景，由调用端容器控制
        [self setupUIWithOffer:offer];
    }
    return self;
}

- (void)setupUIWithOffer:(ATNativeAdOffer *)offer {
    id<ATNativeMaterialProtocol> nativeAd = offer.nativeAd;

    // 1. 图标
    _iconImageView = [[UIImageView alloc] init];
    _iconImageView.contentMode = UIViewContentModeScaleAspectFill;
    _iconImageView.clipsToBounds = YES;
    _iconImageView.layer.cornerRadius = 4.0;
    if (nativeAd.icon) {
        _iconImageView.image = nativeAd.icon;
    } else if (nativeAd.iconUrl) {
        [self loadImageWithURL:nativeAd.iconUrl imageView:_iconImageView];
    }
    [self addSubview:_iconImageView];

    // 2. 标题
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont boldSystemFontOfSize:16];
    _titleLabel.textColor = [UIColor blackColor];
    _titleLabel.numberOfLines = 1;
    _titleLabel.text = nativeAd.title ?: @"";
    [self addSubview:_titleLabel];

    // 3. 描述
    _textLabel = [[UILabel alloc] init];
    _textLabel.font = [UIFont systemFontOfSize:14];
    _textLabel.textColor = [UIColor grayColor];
    _textLabel.numberOfLines = 2;
    _textLabel.text = nativeAd.mainText ?: @"";
    [self addSubview:_textLabel];

    // 4. CTA按钮
    _ctaLabel = [[UILabel alloc] init];
    _ctaLabel.font = [UIFont systemFontOfSize:14];
    _ctaLabel.textColor = [UIColor whiteColor];
    _ctaLabel.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    _ctaLabel.textAlignment = NSTextAlignmentCenter;
    _ctaLabel.layer.cornerRadius = 4.0;
    _ctaLabel.clipsToBounds = YES;
    _ctaLabel.text = nativeAd.ctaText ?: @"了解更多";
    [self addSubview:_ctaLabel];

    // 5. 主图
    _mainImageView = [[UIImageView alloc] init];
    _mainImageView.contentMode = UIViewContentModeScaleAspectFill;
    _mainImageView.clipsToBounds = YES;
    if (nativeAd.mainImage) {
        _mainImageView.image = nativeAd.mainImage;
    } else if (nativeAd.imageUrl) {
        [self loadImageWithURL:nativeAd.imageUrl imageView:_mainImageView];
    }
    [self addSubview:_mainImageView];

    // 6. 广告商
    _advertiserLabel = [[UILabel alloc] init];
    _advertiserLabel.font = [UIFont systemFontOfSize:12];
    _advertiserLabel.textColor = [UIColor lightGrayColor];
    _advertiserLabel.text = nativeAd.advertiser ?: @"";
    [self addSubview:_advertiserLabel];

    // 7. 评分
    _ratingLabel = [[UILabel alloc] init];
    _ratingLabel.font = [UIFont systemFontOfSize:12];
    _ratingLabel.textColor = [UIColor orangeColor];
    if (nativeAd.rating && [nativeAd.rating floatValue] > 0) {
        _ratingLabel.text = [NSString stringWithFormat:@"⭐️ %.1f", [nativeAd.rating floatValue]];
    }
    [self addSubview:_ratingLabel];

    // 8. Logo (SDK提供)
    _logoImageView = [[UIImageView alloc] init];
    if (nativeAd.logo) {
        _logoImageView.image = nativeAd.logo;
    }
    [self addSubview:_logoImageView];

    // 9. 关闭按钮
    _dislikeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_dislikeButton setTitle:@"✕" forState:UIControlStateNormal];
    [_dislikeButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    _dislikeButton.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.8];
    _dislikeButton.layer.cornerRadius = 12.0;
    [self addSubview:_dislikeButton];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat padding = 12.0;
    CGFloat currentY = padding;

    // 顶部：图标 + 标题 + 评分
    CGFloat iconSize = 50.0;
    _iconImageView.frame = CGRectMake(padding, currentY, iconSize, iconSize);

    CGFloat labelX = iconSize + padding * 2;
    CGFloat labelWidth = width - labelX - padding - 60; // 右侧留空间给关闭按钮

    _titleLabel.frame = CGRectMake(labelX, currentY, labelWidth, 20);
    _ratingLabel.frame = CGRectMake(labelX, currentY + 22, labelWidth, 16);
    _advertiserLabel.frame = CGRectMake(labelX, currentY + 40, labelWidth, 14);

    // 关闭按钮（右上角）
    _dislikeButton.frame = CGRectMake(width - 24 - padding, padding, 24, 24);

    currentY += iconSize + padding;

    // 描述文本
    CGSize textSize = [_textLabel sizeThatFits:CGSizeMake(width - padding * 2, CGFLOAT_MAX)];
    _textLabel.frame = CGRectMake(padding, currentY, width - padding * 2, MIN(textSize.height, 40));
    currentY += CGRectGetHeight(_textLabel.frame) + padding;

    // 主图或媒体视图
    if (_mediaView) {
        CGFloat mediaHeight = (width - padding * 2) * 9.0 / 16.0; // 16:9比例
        _mediaView.frame = CGRectMake(padding, currentY, width - padding * 2, mediaHeight);
        currentY += mediaHeight + padding;
    } else if (_mainImageView.image) {
        CGFloat imageHeight = (width - padding * 2) * 9.0 / 16.0;
        _mainImageView.frame = CGRectMake(padding, currentY, width - padding * 2, imageHeight);
        currentY += imageHeight + padding;
    }

    // CTA按钮
    CGFloat ctaHeight = 44.0;
    _ctaLabel.frame = CGRectMake(padding, currentY, width - padding * 2, ctaHeight);
    currentY += ctaHeight + padding;

    // Logo（右下角）
    if (_logoImageView.image) {
        _logoImageView.frame = CGRectMake(width - 50 - padding, currentY - 50 - padding, 50, 50);
    }
}

- (void)setMediaView:(UIView *)mediaView {
    if (_mediaView) {
        [_mediaView removeFromSuperview];
    }
    _mediaView = mediaView;
    if (_mediaView) {
        [self addSubview:_mediaView];
        [self setNeedsLayout];
    }
}

- (CGSize)intrinsicContentSize {
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width <= 0) {
        width = UIScreen.mainScreen.bounds.size.width - 32;
    }

    CGFloat height = 12 + 50 + 12; // 图标区域
    height += 40 + 12; // 描述文本

    if (_mediaView || _mainImageView.image) {
        height += (width - 24) * 9.0 / 16.0 + 12; // 媒体区域
    }

    height += 44 + 12; // CTA按钮

    return CGSizeMake(width, height);
}

#pragma mark - Helper

- (void)loadImageWithURL:(NSString *)urlString imageView:(UIImageView *)imageView {
    if (!urlString || !imageView) return;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            UIImage *image = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                imageView.image = image;
                [self setNeedsLayout];
            });
        }
    });
}

@end

#endif // FLAME_BUILD_TK / 默认 TK
