#import <Foundation/Foundation.h>

typedef void(^FlameNetworkCompletion)(NSDictionary *result, NSError *error);

@interface FlameNetworkUtils : NSObject

/**
 * 发送 POST 请求
 * @param urlString 请求地址
 * @param params 已经拼接好的参数字符串 (a=1&b=2&sign=xxx)
 */
+ (void)doPost:(NSString *)urlString params:(NSString *)params completion:(FlameNetworkCompletion)completion;


// ✅ 新增 JSON POSTJSON
+ (void)doPostJson:(NSString *)urlString
      jsonBody:(NSDictionary *)jsonBody
    completion:(FlameNetworkCompletion)completion;
@end
