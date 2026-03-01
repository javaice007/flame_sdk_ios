/**
 * @author flame
 */

#import <Foundation/Foundation.h>

@interface FlameMd5SignatureUtils : NSObject

+ (NSString *)signWithParams:(NSDictionary *)params
                      appKey:(NSString *)appKey;

@end
