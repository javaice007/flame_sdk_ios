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

- (NSString *)getAId;
- (NSString *)getAKey;
- (NSString *)getPId:(NSString *)flamePlacementId;
- (NSString *)getSdkVersion;

- (void)clearCache;
@end
