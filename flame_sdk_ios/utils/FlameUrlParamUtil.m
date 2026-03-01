#import "FlameUrlParamUtil.h"

@implementation FlameUrlParamUtil

+ (NSString *)format:(NSDictionary *)params {
    if (!params || params.count == 0) return @"";
    
    // 1. 获取所有 Key 并排序
    NSArray *allKeys = [params allKeys];
    NSArray *sortedKeys = [allKeys sortedArrayUsingSelector:@selector(compare:)];
    
    // 2. 遍历排序后的 Key 进行拼接
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        id value = params[key];
        NSString *pair = [NSString stringWithFormat:@"%@=%@", key, value];
        [pairs addObject:pair];
    }
    
    return [pairs componentsJoinedByString:@"&"];
}

@end
