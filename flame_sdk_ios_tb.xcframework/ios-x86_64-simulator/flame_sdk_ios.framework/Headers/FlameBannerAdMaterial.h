//
//  FlameBannerAdMaterial.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/5/8.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlameBannerAdMaterial : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, copy) NSString *ctaText;

@property (nonatomic, copy) NSString *iconUrl;
@property (nonatomic, copy) NSString *coverUrl;

@property (nonatomic, copy) NSString *advertiser;
@property (nonatomic, copy) NSString *domain;
@property (nonatomic, copy) NSString *warning;
@property (nonatomic, strong, nullable) NSNumber *rating;
@property (nonatomic, copy) NSString *sponsor;
@property (nonatomic, copy) NSString *source;

@property (nonatomic, assign) BOOL hasVideo;
@property (nonatomic, assign) BOOL requiresAdvertiser;
@property (nonatomic, assign) BOOL requiresDomain;
@property (nonatomic, assign) BOOL requiresWarning;

@end

NS_ASSUME_NONNULL_END
