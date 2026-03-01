# Flame iOS SDK 优化任务清单

> 版本: v0.1.1
> 分支: feat/tk_adapter
> 创建时间: 2026-03-01

---

## 📋 任务概览

本文档包含Flame iOS SDK的优化任务，按优先级分为3个阶段执行。

**统计**:
- 🔴 阶段1 (P0-必须修复): 4个任务
- 🟠 阶段2 (P1-重要优化): 8个任务
- 🟡 阶段3 (P2-后续迭代): 8个任务
- **总计**: 20个优化任务

---

## 🔴 阶段1: 核心问题修复 (P0-必须修复)

> **目标**: 修复影响稳定性和安全性的严重问题
> **预计工期**: 3-5天
> **必须完成**: 进入生产环境前

### 1.1 线程安全问题 ⚠️⚠️⚠️

**问题描述**:
- 单例的`appEntity`属性没有线程保护
- `isInitialized`标志在多线程环境下可能出现竞态条件
- 网络回调在主线程，但配置更新没有同步保护

**影响范围**:
- `FlameConfigManager.m`
- `FlameAdapterManager.m`
- `FlameSdk.m`

**解决方案**:
```objc
// 方案1: 使用串行队列保护
@property (nonatomic, strong) dispatch_queue_t syncQueue;

// 方案2: 使用@synchronized
@synchronized(self) {
    // 访问共享数据
}

// 方案3: 使用atomic属性（简单场景）
@property (atomic, strong) FlameAppEntity *appEntity;
```

**验证方法**:
- 编写多线程并发测试
- 使用Thread Sanitizer检测竞态条件

**优先级**: 🔥 P0 - 最高
**影响**: 可能导致崩溃或数据不一致

---

### 1.2 重复初始化未完全防护 ⚠️⚠️

**问题描述**:
- 只检查`isInitialized`但在配置获取成功前已经可以多次调用
- 没有使用`dispatch_once`或锁机制防止并发初始化

**影响范围**:
- `FlameSdk.m:109` (initWithAppId方法)
- `FlameAdapterManager.m:52` (initSDKWithAppId方法)

**解决方案**:
```objc
// 方案1: 使用dispatch_once
static dispatch_once_t initOnceToken;
dispatch_once(&initOnceToken, ^{
    // 初始化逻辑
});

// 方案2: 使用信号量
@property (nonatomic, strong) dispatch_semaphore_t initSemaphore;

// 方案3: 状态机
typedef NS_ENUM(NSInteger, FlameSDKState) {
    FlameSDKStateUninitialized,
    FlameSDKStateInitializing,
    FlameSDKStateInitialized,
    FlameSDKStateInitFailed
};
```

**验证方法**:
- 模拟多次快速调用init方法
- 检查是否产生多个网络请求

**优先级**: 🔥 P0 - 最高
**影响**: 重复初始化底层SDK或重复网络请求

---

### 1.3 内存泄漏风险 ⚠️⚠️

**问题描述**:
- `UpdateAppCallback`持有`initCallback`强引用，可能造成循环引用
- Adapter持有`viewController`和`listener`强引用，未使用weak
- 创建大量临时对象（如`FlameConfigLocalStorage`在每次调用时new）

**影响范围**:
- `FlameSdk.m:22-70` (UpdateAppCallback类)
- `AtRewardAdapter.h/m` 及其他Adapter
- `FlameConfigManager.m:39,47` (重复创建Storage)

**解决方案**:
```objc
// 1. UpdateAppCallback使用weak引用
@property (nonatomic, weak) id<FlameCallback> initCallback;

// 2. Adapter的listener使用weak
@property (nonatomic, weak) id<FlameRewardListener> listener;

// 3. Storage改为单例或缓存
@property (nonatomic, strong) FlameConfigLocalStorage *storage;
```

**验证方法**:
- 使用Instruments的Leaks工具检测
- 使用Memory Graph查看循环引用
- 模拟创建大量广告对象测试

**优先级**: 🔥 P0 - 最高
**影响**: 内存泄漏，无法释放对象

---

### 1.4 错误处理不完善 ⚠️

**问题描述**:
- 返回nil时没有触发listener回调，开发者无法感知失败
- 网络错误只记录日志，没有重试机制
- 缺少配置过期检测机制

**影响范围**:
- 所有create方法 (FlameSdk.m)
- `FlameConfigManager.m:46-123` (updateApp方法)
- `FlameNetworkUtils.m` (网络请求)

**解决方案**:
```objc
// 1. create失败时触发回调
if (pId == nil || pId.length == 0) {
    if ([listener respondsToSelector:@selector(onAdError:desc:)]) {
        [listener onAdError:ERROR_CODE_INVALID_PLACEMENT
                       desc:@"Invalid placement ID"];
    }
    return nil;
}

// 2. 添加重试机制
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, assign) NSTimeInterval retryDelay;

// 3. 配置过期检测
@property (nonatomic, strong) NSDate *configExpiryDate;
```

**验证方法**:
- 测试各种错误场景
- 模拟网络失败
- 检查所有错误路径是否有回调

**优先级**: 🔥 P0 - 高
**影响**: 用户体验差，难以排查问题

---

## 🟠 阶段2: 架构优化与代码质量 (P1-重要优化)

> **目标**: 提升代码质量、可维护性和性能
> **预计工期**: 5-7天
> **建议时间**: v0.2.0版本

### 2.1 消除大量重复代码 🔧

**问题描述**:
- `FlameSdk.m`所有create方法几乎完全相同（6个方法）
- `FlameAdapterManager.m`所有create方法重复检查逻辑（6个方法）
- placementId验证逻辑重复6次

**影响范围**:
- `FlameSdk.m:139-260` (所有create方法)
- `FlameAdapterManager.m:103-238` (所有create方法)

**解决方案**:
```objc
// 方案1: 抽取公共方法
- (nullable id)createAdWithType:(FlameAdType)type
                 viewController:(UIViewController *)viewController
                    placementId:(NSString *)placementId
                       listener:(id)listener {
    NSString *pId = [self validateAndGetPId:placementId type:type];
    if (!pId) return nil;

    // 使用工厂模式创建
    return [self.adFactory createAd:type ...];
}

// 方案2: 使用宏减少重复
#define FLAME_CREATE_AD_IMPL(AdType, adType) \
+ (id<Flame##AdType##Ad>)create##AdType##Ad... { \
    return [self createAdWithType:FlameAdType##AdType ...]; \
}
```

**优先级**: 🟡 P1 - 高
**影响**: 代码冗余，维护成本高

---

### 2.2 统一单例模式实现 🔧

**问题描述**:
- 三个单例的实现方式略有不同
- `FlameAdapterManager`使用`[super alloc]`而其他用`[[self alloc] init]`
- 都没有重写`allocWithZone:`和`copyWithZone:`防止多实例

**影响范围**:
- `FlameSdk.m:81-86`
- `FlameConfigManager.m:25-32`
- `FlameAdapterManager.m:39-46`

**解决方案**:
```objc
// 标准单例模板
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static YourClass *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}
```

**优先级**: 🟡 P1 - 中
**影响**: 代码风格不统一，可能被绕过单例

---

### 2.3 完善配置缓存策略 🔧

**问题描述**:
- 只判断缓存是否存在，不判断缓存是否过期
- 没有缓存版本控制
- 本地缓存损坏时无降级方案

**影响范围**:
- `FlameConfigManager.m:46-66` (updateApp方法)
- `FlameConfigLocalStorage.m`

**解决方案**:
```objc
// 1. 添加缓存过期时间
@property (nonatomic, strong) NSDate *cacheExpiryDate;
#define CACHE_EXPIRY_SECONDS (24 * 60 * 60) // 24小时

// 2. 添加版本号
@property (nonatomic, copy) NSString *cacheVersion;
#define CURRENT_CACHE_VERSION @"1.0"

// 3. 降级方案
- (BOOL)isCacheValid {
    // 检查存在性、版本、过期时间、数据完整性
    return exists && versionMatch && !expired && dataValid;
}
```

**优先级**: 🟡 P1 - 中
**影响**: 使用过期配置或无法恢复

---

### 2.4 重构日志系统 🔧

**问题描述**:
- 所有日志级别输出格式完全相同，没有区分
- 每条日志输出3行分隔线，过于冗余
- 没有日志开关控制（debug/release）
- 不支持日志文件持久化

**影响范围**:
- `FlameLogger.m:15-38`
- 所有调用FlameLogger的地方

**解决方案**:
```objc
typedef NS_ENUM(NSInteger, FlameLogLevel) {
    FlameLogLevelDebug,
    FlameLogLevelInfo,
    FlameLogLevelWarning,
    FlameLogLevelError
};

@interface FlameLogger : NSObject

+ (void)setLogLevel:(FlameLogLevel)level;
+ (void)setLogEnabled:(BOOL)enabled;
+ (void)enableFileLogging:(NSString *)logPath;

// 区分不同级别的格式
+ (void)d:(NSString *)msg; // [DEBUG]
+ (void)i:(NSString *)msg; // [INFO]
+ (void)w:(NSString *)msg; // [WARNING]
+ (void)e:(NSString *)msg; // [ERROR]

@end
```

**优先级**: 🟡 P1 - 中
**影响**: 生产环境日志泄露，性能损耗

---

### 2.5 优化数据持久化 🔧

**问题描述**:
- pMap使用自定义字符串序列化而不是JSON
- 每次都创建新的`FlameConfigLocalStorage`实例
- `synchronize()`方法在iOS 12+已废弃

**影响范围**:
- `FlameConfigLocalStorage.m:42-84`
- `FlameConfigManager.m:39,47`

**解决方案**:
```objc
// 1. 使用JSON序列化
- (void)putPMap:(NSDictionary *)pMap {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:pMap ...];
    [self.userDefaults setObject:jsonData forKey:KEY_PLACEMENT_MAP];
}

- (NSDictionary *)getPMap {
    NSData *jsonData = [self.userDefaults objectForKey:KEY_PLACEMENT_MAP];
    return [NSJSONSerialization JSONObjectWithData:jsonData ...];
}

// 2. Storage改为单例
+ (instancetype)sharedInstance;

// 3. 移除synchronize调用（iOS自动管理）
```

**优先级**: 🟡 P1 - 中
**影响**: 序列化不可靠，性能差

---

### 2.6 统一错误码管理 🔧

**问题描述**:
- 错误码使用字符串不统一（`@"-1"`, `@"AD_NOT_READY"`）
- 没有统一的错误码枚举
- 错误描述信息硬编码

**影响范围**:
- `FlameErrorCode.h/m`
- 所有回调错误的地方

**解决方案**:
```objc
// FlameErrorCode.h
typedef NS_ENUM(NSInteger, FlameErrorCode) {
    FlameErrorCodeSuccess = 0,
    FlameErrorCodeNetworkError = 1000,
    FlameErrorCodeInvalidPlacement = 2000,
    FlameErrorCodeAdNotReady = 3000,
    FlameErrorCodeSDKNotInit = 4000,
    // ...
};

@interface FlameErrorHelper : NSObject
+ (NSString *)codeToString:(FlameErrorCode)code;
+ (NSString *)descriptionForCode:(FlameErrorCode)code;
@end

// 使用
[listener onAdError:[FlameErrorHelper codeToString:FlameErrorCodeAdNotReady]
               desc:[FlameErrorHelper descriptionForCode:FlameErrorCodeAdNotReady]];
```

**优先级**: 🟡 P1 - 中
**影响**: 难以维护和国际化

---

### 2.7 增强网络层功能 🔧

**问题描述**:
- 没有重试机制
- 没有请求队列管理
- 超时时间硬编码（15s）
- 没有HTTPS证书校验
- 没有请求取消机制

**影响范围**:
- `FlameNetworkUtils.m`

**解决方案**:
```objc
@interface FlameNetworkUtils : NSObject

// 配置
@property (nonatomic, assign) NSTimeInterval timeout; // 可配置
@property (nonatomic, assign) NSInteger maxRetries;
@property (nonatomic, assign) BOOL enableSSLPinning;

// 请求方法（带重试）
+ (void)doPostJson:(NSString *)url
          jsonBody:(NSDictionary *)body
        retryCount:(NSInteger)retry
        completion:(FlameNetworkCompletion)completion;

// 取消请求
+ (void)cancelAllRequests;
+ (void)cancelRequest:(NSString *)requestId;

@end
```

**优先级**: 🟡 P1 - 低
**影响**: 网络环境差时用户体验不佳

---

### 2.8 移除@throw异常处理 🔧

**问题描述**:
- 使用`@throw`抛出异常会导致app崩溃
- iOS开发不推荐使用异常处理业务逻辑

**影响范围**:
- `FlameSdk.m:128-131`
- `FlameAdapterManager.m:97-100`

**解决方案**:
```objc
// 替换前
+ (void)checkInitialization {
    if (![self isInitialized]) {
        @throw [NSException exceptionWithName:...]; // ❌
    }
}

// 替换后
+ (BOOL)checkInitialization {
    if (![self isInitialized]) {
        [FlameLogger e:@"SDK not initialized"];
        return NO;
    }
    return YES;
}

// 调用处
if (![FlameAdapterManager checkInitialization]) {
    if ([listener respondsToSelector:@selector(onAdError:desc:)]) {
        [listener onAdError:ERROR_CODE_SDK_NOT_INIT
                       desc:@"SDK must be initialized first"];
    }
    return;
}
```

**优先级**: 🟡 P1 - 中
**影响**: App可能崩溃

---

## 🟡 阶段3: 增强功能与最佳实践 (P2-后续迭代)

> **目标**: 提升开发体验、安全性和可扩展性
> **预计工期**: 7-10天
> **建议时间**: v0.3.0版本

### 3.1 优化API设计 💡

**问题描述**:
- 返回nil无法通过编译器检查（没有`nullable`标记）
- 没有Builder模式简化参数传递
- 缺少链式调用支持
- 没有提供同步/异步两种初始化方式选择

**解决方案**:
```objc
// 1. 添加nullability注解
+ (nullable id<FlameRewardAd>)createRewardAdWithViewController:(UIViewController *)viewController
                                                    placementId:(NSString *)placementId
                                                       listener:(id<FlameRewardListener>)listener;

// 2. Builder模式
FlameRewardAdBuilder *builder = [FlameRewardAdBuilder new];
id<FlameRewardAd> ad = builder
    .viewController(self)
    .placementId(@"reward_001")
    .listener(self)
    .userId(@"user123")
    .build();

// 3. 同步/异步初始化
[FlameSdk initWithAppId:appId appKey:appKey callback:^{...}]; // 异步
BOOL success = [FlameSdk initSyncWithAppId:appId appKey:appKey]; // 同步
```

**优先级**: 🔵 P2 - 低
**影响**: 开发者体验

---

### 3.2 添加性能监控 💡

**问题描述**:
- 没有广告加载时间统计
- 没有网络请求耗时监控
- 没有内存占用监控
- 没有崩溃日志收集

**解决方案**:
```objc
@interface FlameAnalytics : NSObject

// 性能指标
+ (void)trackAdLoadTime:(NSTimeInterval)time placementId:(NSString *)pid;
+ (void)trackNetworkRequest:(NSString *)url duration:(NSTimeInterval)duration;
+ (void)trackMemoryUsage:(NSUInteger)bytes;

// 获取报告
+ (NSDictionary *)getPerformanceReport;

@end
```

**优先级**: 🔵 P2 - 低
**影响**: 无法量化SDK性能

---

### 3.3 增强安全措施 💡

**问题描述**:
- MD5已不安全，应使用HMAC-SHA256
- AES加密密钥直接使用appKey可能不够随机
- 没有证书固定(SSL Pinning)
- 敏感信息（appKey）明文存储在内存

**解决方案**:
```objc
// 1. 使用HMAC-SHA256替代MD5
+ (NSString *)signWithParams:(NSDictionary *)params
                      appKey:(NSString *)appKey {
    // 使用HMAC-SHA256
    return [self hmacSHA256:sortedParams key:appKey];
}

// 2. SSL Pinning
[FlameNetworkUtils enableSSLPinning:YES
                       certificates:@[@"cert1", @"cert2"]];

// 3. 敏感信息保护
// 使用Keychain存储appKey
// 内存中使用后立即清除
```

**优先级**: 🔵 P2 - 中
**影响**: 安全风险

---

### 3.4 提升可测试性 💡

**问题描述**:
- 依赖注入不足，难以测试
- 所有依赖都是硬编码（TopOn SDK）
- 没有Protocol抽象网络层和存储层

**解决方案**:
```objc
// 1. 抽象依赖为Protocol
@protocol FlameNetworkService <NSObject>
- (void)post:(NSString *)url ...;
@end

@protocol FlameStorageService <NSObject>
- (void)save:(NSString *)key value:(id)value;
@end

// 2. 依赖注入
@interface FlameConfigManager : NSObject
- (instancetype)initWithNetwork:(id<FlameNetworkService>)network
                        storage:(id<FlameStorageService>)storage;
@end

// 3. Mock实现用于测试
@interface MockNetworkService : NSObject<FlameNetworkService>
@end
```

**优先级**: 🔵 P2 - 低
**影响**: 可测试性差

---

### 3.5 配置动态化 💡

**问题描述**:
- API地址硬编码在代码中
- 无法动态切换环境（测试/生产）
- 无法热更新API域名

**解决方案**:
```objc
typedef NS_ENUM(NSInteger, FlameEnvironment) {
    FlameEnvironmentProduction,
    FlameEnvironmentStaging,
    FlameEnvironmentDevelopment
};

@interface FlameSdk : NSObject

+ (void)setEnvironment:(FlameEnvironment)env;
+ (void)setCustomAPIBaseURL:(NSString *)baseURL;

@end
```

**优先级**: 🔵 P2 - 低
**影响**: 灵活性不足

---

### 3.6 优化回调队列 💡

**问题描述**:
- 强制在主线程回调，但有些场景不需要
- 没有提供自定义回调队列的选项

**解决方案**:
```objc
@interface FlameNetworkUtils : NSObject

+ (void)doPostJson:(NSString *)url
          jsonBody:(NSDictionary *)body
     callbackQueue:(dispatch_queue_t)queue // 新增
        completion:(FlameNetworkCompletion)completion;

@end

// 使用
dispatch_queue_t myQueue = dispatch_queue_create("com.flame.callback", NULL);
[FlameNetworkUtils doPostJson:url
                     jsonBody:body
                callbackQueue:myQueue
                   completion:^{...}];
```

**优先级**: 🔵 P2 - 低
**影响**: 灵活性不足

---

### 3.7 版本管理规范化 💡

**问题描述**:
- SDK版本硬编码
- 没有自动化版本号管理
- 无法在运行时获取详细版本信息

**解决方案**:
```objc
// 1. 版本信息类
@interface FlameSDKVersion : NSObject

@property (nonatomic, readonly) NSString *version;      // 1.0.0
@property (nonatomic, readonly) NSString *buildNumber;  // 2024010101
@property (nonatomic, readonly) NSString *commitHash;   // a1b2c3d
@property (nonatomic, readonly) NSDate *buildDate;

+ (instancetype)currentVersion;

@end

// 2. 使用脚本自动生成版本文件
// build-scripts/generate_version.sh
```

**优先级**: 🔵 P2 - 低
**影响**: 版本管理不规范

---

### 3.8 广告预加载机制 💡

**问题描述**:
- 没有广告预加载机制
- 没有广告池管理
- 没有智能加载策略（WiFi vs 蜂窝）

**解决方案**:
```objc
@interface FlameAdPreloader : NSObject

// 预加载指定数量的广告
+ (void)preloadAds:(FlameAdType)type
       placementId:(NSString *)pid
             count:(NSInteger)count;

// 智能预加载（根据网络环境）
+ (void)enableSmartPreload:(BOOL)enabled;

// 广告池管理
+ (NSInteger)availableAdCount:(NSString *)placementId;

@end
```

**优先级**: 🔵 P2 - 低
**影响**: 广告展示延迟

---

## 📊 任务执行计划

### 里程碑规划

| 阶段 | 版本 | 任务数 | 预计工期 | 交付时间 |
|-----|------|--------|---------|---------|
| 阶段1 | v0.1.2 | 4 | 3-5天 | Week 1 |
| 阶段2 | v0.2.0 | 8 | 5-7天 | Week 2-3 |
| 阶段3 | v0.3.0 | 8 | 7-10天 | Week 4-5 |

### 优先级说明

- 🔥 **P0**: 严重问题，必须在生产环境前修复
- 🟡 **P1**: 重要优化，影响代码质量和可维护性
- 🔵 **P2**: 增强功能，提升开发体验和性能

### 验收标准

#### 阶段1验收标准
- [ ] 通过Thread Sanitizer无竞态条件
- [ ] 通过Instruments Leaks无内存泄漏
- [ ] 所有错误场景都有回调通知
- [ ] 单元测试覆盖率 > 60%

#### 阶段2验收标准
- [ ] 代码重复率 < 5%
- [ ] 所有单例实现一致
- [ ] 配置缓存有过期机制
- [ ] 日志系统支持级别控制
- [ ] 错误码统一管理
- [ ] 单元测试覆盖率 > 70%

#### 阶段3验收标准
- [ ] API都有nullability注解
- [ ] 性能数据可追踪
- [ ] 安全检查通过（静态分析工具）
- [ ] 主要模块可Mock测试
- [ ] 单元测试覆盖率 > 80%

---

## 📝 变更日志

| 日期 | 版本 | 变更内容 | 负责人 |
|-----|------|---------|--------|
| 2026-03-01 | v1.0 | 创建优化任务清单，包含20个任务分3个阶段 | - |

---

## 🔗 相关文档

- [SDK架构设计](./docs/architecture.md)
- [API文档](./docs/api.md)
- [测试计划](./docs/testing.md)
- [发布流程](./docs/release.md)

---

## 📌 注意事项

1. **向后兼容**: 所有优化必须保持API向后兼容，除非标记为Breaking Change
2. **测试先行**: 每个优化都应先编写测试用例
3. **文档同步**: 修改后及时更新API文档和示例代码
4. **代码审查**: 所有代码必须经过Code Review后才能合并
5. **性能测试**: 重要优化需要进行性能对比测试

---

**最后更新**: 2026-03-01
**文档版本**: v1.0
**维护者**: Flame SDK Team
