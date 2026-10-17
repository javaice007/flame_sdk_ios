//
//  P0DNetProbe.m — 见 P0DNetProbe.h。
//  实现说明：sharedSession 的具体类是私有子类（__NSURLSessionLocal 等），
//  须在具体类上以 C IMP 替换实例方法实现（method_setImplementation），
//  不能在 NSURLSession 抽象类上做 method_exchange（会在具体类实例上找不到方法而 crash）。
//
#import "P0DNetProbe.h"
#import <objc/runtime.h>

static BOOL IsFlameURL(NSURL *url) {
    return url.host.length > 0 && [url.host.lowercaseString containsString:@"adsurge.cn"];
}

typedef NSURLSessionDataTask *(*P0DDataTaskIMP)(id, SEL, NSURLRequest *, void (^)(NSData *, NSURLResponse *, NSError *));
static P0DDataTaskIMP gOrigDataTask = NULL;

static NSURLSessionDataTask *P0DDataTask(id self, SEL _cmd, NSURLRequest *request, void (^handler)(NSData *, NSURLResponse *, NSError *))
{
    if (!IsFlameURL(request.URL) || !gOrigDataTask) {
        return gOrigDataTask(self, _cmd, request, handler);
    }

    NSString *bodyStr = @"<nil>";
    if (request.HTTPBody) {
        bodyStr = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding] ?: @"<non-utf8>";
    }
    NSLog(@"[P0D-NET] >>>REQUEST url=%@ method=%@ headers=%@ bodyLen=%lu body=%@",
          request.URL.absoluteString, request.HTTPMethod,
          request.allHTTPHeaderFields ?: @{},
          (unsigned long)request.HTTPBody.length, bodyStr);

    void (^wrapped)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSString *respBody = @"<nil>";
        if (data) {
            respBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"<non-utf8>";
            if (respBody.length > 3000) respBody = [[respBody substringToIndex:3000] stringByAppendingString:@"…<trunc>"];
        }
        NSLog(@"[P0D-NET] <<<RESPONSE status=%ld err=%@ headers=%@ bodyLen=%lu body=%@",
              (long)http.statusCode, error.localizedDescription ?: @"-", http.allHeaderFields,
              (unsigned long)data.length, respBody);
        if (handler) handler(data, response, error);
    };
    return gOrigDataTask(self, _cmd, request, wrapped);
}

@implementation P0DNetProbe

+ (void)install
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // sharedSession 请求最终落到其具体类（私有子类）的实例方法上
        Class concrete = object_getClass([NSURLSession sharedSession]);
        Method m = class_getInstanceMethod(concrete, @selector(dataTaskWithRequest:completionHandler:));
        if (m) {
            gOrigDataTask = (P0DDataTaskIMP)method_getImplementation(m);
            method_setImplementation(m, (IMP)P0DDataTask);
            NSLog(@"[P0D-NET] probe installed on %s", class_getName(concrete));
        } else {
            NSLog(@"[P0D-NET] probe FAILED (method not found)");
        }
    });
}

@end
