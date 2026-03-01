#import "FlameAesCryptoUtils.h"
#import <openssl/evp.h>
#import <openssl/rand.h>

@implementation FlameAesCryptoUtils

static const int kIVLength = 12;   // GCM 标准 IV 长度
static const int kTagLength = 16;  // 128-bit TAG

#pragma mark - AES-GCM Encrypt

+ (NSString *)encrypt:(NSString *)plaintext rawKey:(NSString *)rawKey {

    NSData *plainData = [plaintext dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData   = [rawKey dataUsingEncoding:NSUTF8StringEncoding];

    // 1. 生成 12 字节随机 IV
    NSMutableData *ivData = [NSMutableData dataWithLength:kIVLength];
    RAND_bytes(ivData.mutableBytes, kIVLength);

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    NSMutableData *cipherData = [NSMutableData dataWithLength:plainData.length];

    int len = 0;
    int cipherLen = 0;

    // 2. 使用 AES-128-GCM（根据 key 长度自动选用 128/192/256）
    const EVP_CIPHER *cipher = NULL;
    if (keyData.length == 16) cipher = EVP_aes_128_gcm();
    else if (keyData.length == 24) cipher = EVP_aes_192_gcm();
    else if (keyData.length == 32) cipher = EVP_aes_256_gcm();
    else return nil;

    EVP_EncryptInit_ex(ctx, cipher, NULL, NULL, NULL);
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, kIVLength, NULL);
    EVP_EncryptInit_ex(ctx, NULL, NULL, keyData.bytes, ivData.bytes);

    // 3. 加密正文
    EVP_EncryptUpdate(ctx, cipherData.mutableBytes, &len, plainData.bytes, (int)plainData.length);
    cipherLen = len;

    // 4. Final（GCM 不产生额外密文）
    EVP_EncryptFinal_ex(ctx, cipherData.mutableBytes + len, &len);
    cipherLen += len;

    // 5. 获取认证 TAG
    NSMutableData *tagData = [NSMutableData dataWithLength:kTagLength];
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, kTagLength, tagData.mutableBytes);

    EVP_CIPHER_CTX_free(ctx);

    // 6. 拼接：IV + CIPHER + TAG
    NSMutableData *output = [NSMutableData data];
    [output appendData:ivData];
    [output appendData:[cipherData subdataWithRange:NSMakeRange(0, cipherLen)]];
    [output appendData:tagData];

    return [output base64EncodedStringWithOptions:0];
}

#pragma mark - AES-GCM Decrypt

+ (NSString *)decrypt:(NSString *)encryptedBase64 rawKey:(NSString *)rawKey {

    NSData *combined = [[NSData alloc] initWithBase64EncodedString:encryptedBase64 options:0];
    NSData *keyData   = [rawKey dataUsingEncoding:NSUTF8StringEncoding];

    if (!combined || combined.length < kIVLength + kTagLength) return nil;

    // 1. 分离组件
    NSData *ivData = [combined subdataWithRange:NSMakeRange(0, kIVLength)];
    NSData *cipherAndTag =
        [combined subdataWithRange:NSMakeRange(kIVLength, combined.length - kIVLength)];

    NSData *cipherData =
        [cipherAndTag subdataWithRange:NSMakeRange(0, cipherAndTag.length - kTagLength)];
    NSData *tagData =
        [cipherAndTag subdataWithRange:NSMakeRange(cipherAndTag.length - kTagLength, kTagLength)];

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    NSMutableData *plainData = [NSMutableData dataWithLength:cipherData.length];

    int len = 0;
    int plainLen = 0;

    // 2. 初始化 GCM 解密
    const EVP_CIPHER *cipher = NULL;
    if (keyData.length == 16) cipher = EVP_aes_128_gcm();
    else if (keyData.length == 24) cipher = EVP_aes_192_gcm();
    else if (keyData.length == 32) cipher = EVP_aes_256_gcm();
    else return nil;

    EVP_DecryptInit_ex(ctx, cipher, NULL, NULL, NULL);
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, kIVLength, NULL);
    EVP_DecryptInit_ex(ctx, NULL, NULL, keyData.bytes, ivData.bytes);

    // 3. 解密正文
    EVP_DecryptUpdate(ctx, plainData.mutableBytes, &len, cipherData.bytes, (int)cipherData.length);
    plainLen = len;

    // 4. 设置 TAG（非常关键）
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, kTagLength, (void *)tagData.bytes);

    // 5. Final 会校验 TAG（如果 TAG 不匹配，则解密失败）
    int ret = EVP_DecryptFinal_ex(ctx, plainData.mutableBytes + len, &len);
    EVP_CIPHER_CTX_free(ctx);

    if (ret <= 0) {
        // TAG 校验失败 → 密文或 key 被篡改
        return nil;
    }

    plainLen += len;
    NSData *realPlain = [plainData subdataWithRange:NSMakeRange(0, plainLen)];

    return [[NSString alloc] initWithData:realPlain encoding:NSUTF8StringEncoding];
}

@end
