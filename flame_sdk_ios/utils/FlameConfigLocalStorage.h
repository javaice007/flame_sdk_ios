/**
 * @author flame
 */

#import <Foundation/Foundation.h>

@interface FlameConfigLocalStorage : NSObject

+ (instancetype)sharedInstance;

- (NSString *)getPt;
- (NSString *)getAId;
- (NSString *)getAKey;
- (NSDictionary<NSString *, NSString *> *)getPMap;
- (NSString *)getCV;
- (NSTimeInterval)getCachedAt;

- (void)putWithPt:(NSString *)pt
              aId:(NSString *)aId
             aKey:(NSString *)aKey
             pMap:(NSDictionary<NSString *, NSString *> *)pMap;

- (void)putWithPt:(NSString *)pt
              aId:(NSString *)aId
             aKey:(NSString *)aKey
             pMap:(NSDictionary<NSString *, NSString *> *)pMap
                cv:(NSString *)cv
         cachedAt:(NSTimeInterval)cachedAt;

- (void)clear;

@end
