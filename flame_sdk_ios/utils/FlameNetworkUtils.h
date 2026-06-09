#import <Foundation/Foundation.h>

typedef void(^FlameNetworkCompletion)(NSDictionary *result, NSError *error);

@interface FlameNetworkUtils : NSObject

/**
 * 发送 POST 请求
 * @param urlString 请求地址
 * @param params 已经拼接好的参数字符串 (a=1&b=2&sign=xxx)
 */
/**
 * 发送 POST 请求
 * @param urlString 请求地址
 * @param params 已经拼接好的参数字符串 (a=1&b=2&sign=xxx)
 * @return NSURLSessionDataTask 可用于取消请求
 */
+ (NSURLSessionDataTask *)doPost:(NSString *)urlString params:(NSString *)params completion:(FlameNetworkCompletion)completion;


/**
 * 发送 JSON POST 请求
 * @return NSURLSessionDataTask 可用于取消请求；JSON 序列化失败时返回 nil
 */
+ (NSURLSessionDataTask *)doPostJson:(NSString *)urlString
      jsonBody:(NSDictionary *)jsonBody
    completion:(FlameNetworkCompletion)completion;
@end
