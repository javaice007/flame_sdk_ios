#import <Foundation/Foundation.h>

@interface FlameUrlParamUtil : NSObject

/**
 * 将字典参数按 Key 字典序排列并拼接成 a=1&b=2 格式
 */
+ (NSString *)format:(NSDictionary *)params;

@end
