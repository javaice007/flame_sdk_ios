//
//  P0DNetProbe.h — TEST_ONLY 网络证据探针（P0E §8-§12）
//  在 Host 层 swizzle NSURLSession dataTaskWithRequest:completionHandler:，
//  仅对 api.adsurge.cn 请求记录：最终 request（method/url/headers/body）与原始 response
//  （status/body 原文）。Host B / Host C 使用完全相同的本文件（同条件对照）。
//  敏感处理：AppKey 不出现在 URL/body 明文中（sign 已是 MD5）；response 原文按需截断。
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface P0DNetProbe : NSObject
+ (void)install;
@end

NS_ASSUME_NONNULL_END
