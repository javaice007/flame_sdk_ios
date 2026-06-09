#import "FlameNetworkUtils.h"

@implementation FlameNetworkUtils

+ (NSURLSessionDataTask *)doPost:(NSString *)urlString params:(NSString *)params completion:(FlameNetworkCompletion)completion {
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    request.HTTPMethod = @"POST";
    request.timeoutInterval = 15.0;

    // 设置 Body 数据
    request.HTTPBody = [params dataUsingEncoding:NSUTF8StringEncoding];

    // 设置标准的表单请求头
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    // 显式 copy completion block，确保堆上生命周期稳定
    FlameNetworkCompletion completionCopy = [completion copy];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        // 在主线程回调，方便 UI 或后续逻辑处理
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completionCopy) completionCopy(nil, error);
                return;
            }

            if (!data) {
                NSError *emptyError = [NSError errorWithDomain:@"FlameNetwork" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Empty data received"}];
                if (completionCopy) completionCopy(nil, emptyError);
                return;
            }

            // 解析 JSON 响应
            NSError *jsonError;
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];

            if (jsonError) {
                if (completionCopy) completionCopy(nil, jsonError);
            } else {
                if (completionCopy) completionCopy(dict, nil);
            }
        });
    }];

    [task resume];
    return task;
}

+ (NSURLSessionDataTask *)doPostJson:(NSString *)urlString
      jsonBody:(NSDictionary *)jsonBody
    completion:(FlameNetworkCompletion)completion {

    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    request.HTTPMethod = @"POST";
    request.timeoutInterval = 15.0;

    // 1. 设置 JSON 请求头
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    // 显式 copy completion block，确保堆上生命周期稳定
    FlameNetworkCompletion completionCopy = [completion copy];

    // 2. 设置 Body
    if (jsonBody) {
        NSError *jsonError;
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:jsonBody
                                                           options:0
                                                             error:&jsonError];
        if (jsonError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionCopy) {
                    completionCopy(nil, jsonError);
                }
            });
            return nil;
        }
        request.HTTPBody = bodyData;
    }

    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data,
                                                        NSURLResponse *response,
                                                        NSError *error) {

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completionCopy) completionCopy(nil, error);
                return;
            }

            if (!data) {
                NSError *emptyError =
                [NSError errorWithDomain:@"FlameNetwork"
                                    code:-1
                                userInfo:@{NSLocalizedDescriptionKey:
                                               @"Empty data received"}];
                if (completionCopy) completionCopy(nil, emptyError);
                return;
            }

            NSError *jsonError;
            NSDictionary *dict =
            [NSJSONSerialization JSONObjectWithData:data
                                            options:kNilOptions
                                              error:&jsonError];

            if (jsonError) {
                if (completionCopy) completionCopy(nil, jsonError);
            } else {
                if (completionCopy) completionCopy(dict, nil);
            }
        });
    }];

    [task resume];
    return task;
}

@end
