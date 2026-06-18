/**
 * @author flame
 */

#import "FlameMd5SignatureUtils.h"
#import <CommonCrypto/CommonDigest.h>

@implementation FlameMd5SignatureUtils

+ (NSString *)signWithParams:(NSDictionary *)params appKey:(NSString *)appKey {

    if (params == nil || params.count == 0 || appKey.length == 0) {
        return nil;
    }

    // 1. key 按字母升序排序
    NSArray *sortedKeys =
        [[params allKeys] sortedArrayUsingSelector:@selector(compare:)];

    // 2. key=value 拼接
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        id value = params[key];
        if (value == nil) continue;
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
    }

    NSString *paramString = [pairs componentsJoinedByString:@"&"];

    // 3. 拼接盐值
    NSString *stringToHash =
        [NSString stringWithFormat:@"%@&key=%@", paramString, appKey];

    // 4. MD5
    const char *cStr = [stringToHash UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);

    // 5. 转 hex（小写）
    NSMutableString *hex = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }

    return hex;
}

@end
