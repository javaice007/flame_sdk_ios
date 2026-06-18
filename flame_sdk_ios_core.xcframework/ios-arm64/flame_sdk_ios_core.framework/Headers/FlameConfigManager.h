//
//  FlameConfigManager.h
//  FlameSDK
//
//  Created by flame.
//

#import <Foundation/Foundation.h>
#import "FlameCallback.h"

@interface FlameConfigManager : NSObject

+ (instancetype)sharedInstance;

- (void)updateAppWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback;

- (NSString *)getPt;
- (NSString *)getAId;
- (NSString *)getAKey;
- (NSString *)getPId:(NSString *)flamePlacementId;
- (NSString *)getSdkVersion;

- (void)clearCache;

/**
 * 取消当前进行中的请求（内部使用）
 */
- (void)cancelCurrentRequest;

/**
 * 取消当前进行中的请求并清除回调引用（供 FlameSdk.clear 调用）
 */
- (void)cancelCurrentRequestAndCallback;

@end
