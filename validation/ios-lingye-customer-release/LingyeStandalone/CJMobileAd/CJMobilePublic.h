//
//  CJMobilePublic.h
//  CJMobileAdDemo
//
//  Created by Gaodun_Jun on 2022/6/29.
//

#ifndef CJMobilePublic_h
#define CJMobilePublic_h

// 媒体ID
#define appID  @"96ff49947661db62"

// 开屏测试ID
#define splashId           @"8a4965ae2b5f4ce6"
// 激励视频测试ID
#define rewardVideoId      @"dee3663658a69082"
// 全屏视频测试ID
#define fullscreenVideoId  @"cd2aa9c2dd467fe0"
// 信息流测试ID
#define nativeId           @"25b03bd651edf47b"
// 插屏测试ID
#define intersititialId    @"13793fe3aaa5a632"
// 短视频测试ID
#define shortVideoId       @"be537b85a50e9954"
// banner测试ID
#define bannerId           @"017fad6fe3160b9f"
// 自渲染测试ID
#define feedNativeId       @"46dd2c3db750dcbc"
#define iconId             @"3a3f114ba9ada982"



#define jScreenBounds      [UIScreen mainScreen].bounds.size
#define jScreenW           [UIScreen mainScreen].bounds.size.width
#define jScreenH           [UIScreen mainScreen].bounds.size.height
#define jRGBA(r,g,b,a)     [UIColor colorWithRed:r/255 green:g/255 blue:b/255 alpha:a]

#import "Masonry.h"
#import "BannerVC.h"
#import "NativeViewController.h"
#import "InterstitialVC.h"
#import "SplashVC.h"
#import "FullscreenVC.h"
#import "RewardVideoVC.h"

#endif /* CJMobilePublic_h */
