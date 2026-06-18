/**
 * @author flame
 */

#import <Foundation/Foundation.h>

@interface FlameAesCryptoUtils : NSObject

/**
 * 1. 加密方法 (Server 端使用)
 */
+ (NSString *)encrypt:(NSString *)plaintext rawKey:(NSString *)rawKey;

/**
 * 2. 解析/解密方法 (SDK 端使用)
 */
+ (NSString *)decrypt:(NSString *)encryptedBase64 rawKey:(NSString *)rawKey;

@end
