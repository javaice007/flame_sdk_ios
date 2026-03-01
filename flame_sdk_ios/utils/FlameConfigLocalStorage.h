/**
 * @author flame
 */

#import <Foundation/Foundation.h>

@interface FlameConfigLocalStorage : NSObject

- (instancetype)init;

- (NSString *)getPt;
- (NSString *)getAId;
- (NSString *)getAKey;
- (NSDictionary<NSString *, NSString *> *)getPMap;

- (void)putWithPt:(NSString *)pt
              aId:(NSString *)aId
             aKey:(NSString *)aKey
             pMap:(NSDictionary<NSString *, NSString *> *)pMap;

- (void)clear;

@end
