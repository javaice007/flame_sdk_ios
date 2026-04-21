# Flame SDK for iOS

Flame SDK 是一个用于 iOS 平台的广告聚合 SDK，当前基于 TopOn (AnyThinkSDK) 实现。

## 版本信息

- **SDK 版本**: 1.0.0
- **最低支持**: iOS 10.0+
- **开发语言**: Objective-C

## 目录结构

```
flame_sdk_ios/
├── core/                    # 核心模块
│   ├── FlameSdk.{h,m}      # SDK 主入口
│   ├── FlameConfigManager   # 配置管理器
│   └── FlameAppEntity       # 配置实体
├── adapter/                 # 广告平台适配器
│   ├── tk/                  # TopOn 适配器
│   └── FlameAdapterManager  # 适配器管理器
├── ads/                     # 广告类型实现
│   ├── reward/             # 激励视频
│   ├── interstitial/       # 插屏广告
│   ├── splash/             # 开屏广告
│   ├── banner/             # 横幅广告
│   ├── native/             # 原生广告
│   └── draw/               # 视频流广告
└── utils/                   # 工具类
    ├── FlameLogger         # 日志工具
    ├── FlameConfigLocalStorage  # 本地存储
    └── ...
```

## 初始化

### 基础初始化

```objective-c
#import <FlameSdk/FlameSdk.h>

[FlameSdk initWithAppId:@"your_app_id" appKey:@"your_app_key"];
```

### 带回调的初始化

```objective-c
[FlameSdk initWithAppId:@"your_app_id"
                 appKey:@"your_app_key"
               callback:^{
    - (void)success {
        NSLog(@"SDK 初始化成功");
    }

    - (void)fail:(NSString *)code desc:(NSString *)desc {
        NSLog(@"SDK 初始化失败: %@ - %@", code, desc);
    }
}];
```

## 广告位ID缓存策略

### 缓存架构

Flame SDK 采用**两级缓存策略**，确保快速启动和离线可用：

```
┌────────────────────────────────────────┐
│          SDK 初始化流程                 │
└───────────────┬────────────────────────┘
                ↓
    ┌──────────────────────┐
    │   检查本地持久化缓存   │
    │   (NSUserDefaults)    │
    └──────┬───────┬────────┘
           │       │
    缓存存在│       │缓存不存在
           ↓       ↓
    ┌──────────┐ ┌──────────────┐
    │ 加载到内存│ │ 请求远程服务器 │
    │ 立即可用  │ │ (HTTPS API)   │
    └──────────┘ └───────┬───────┘
                         ↓
                  ┌─────────────┐
                  │ 保存到本地   │
                  │ + 加载到内存 │
                  └─────────────┘
```

### 1. 内存缓存（第一级）

**实现位置**: `FlameConfigManager.appEntity`

**数据结构**:
```objective-c
FlameAppEntity {
    NSString *pt;      // 平台类型
    NSString *aId;     // Adapter AppId (TopOn)
    NSString *aKey;    // Adapter AppKey
    NSMutableDictionary *pIds;  // 广告位映射表
                                 // Key: Flame PlacementId
                                 // Value: TopOn PlacementId
}
```

**特性**:
- 线程安全: `atomic` 属性保护
- 访问速度: O(1) 字典查找
- 生命周期: App 运行期间

### 2. 持久化缓存（第二级）

**实现位置**: `FlameConfigLocalStorage`

**存储方式**: `NSUserDefaults` (沙盒存储)

**Suite Name**: `flame_sdk_conf`

**存储键值**:
| Key | 描述 | 示例 |
|-----|------|------|
| `pt` | 平台类型 | "topon" |
| `aId` | Adapter AppId | "a63abc123456" |
| `aKey` | Adapter AppKey | "7f8e9d..." |
| `pMap` | 广告位映射表 | "flame_id1=topon_id1&flame_id2=topon_id2" |

**特性**:
- 持久化: App 重启后保留
- 跨会话: 无需重复网络请求
- 清除时机: 仅手动调用 `[FlameSdk clear]`

### 缓存读取流程

```objective-c
// 初始化时的缓存策略
- (void)updateAppWithAppId:(NSString *)appId
                    appKey:(NSString *)appKey
                  callback:(id<FlameCallback>)callback {

    // Step 1: 尝试读取本地缓存
    NSString *aId = [storage getAId];
    NSString *aKey = [storage getAKey];
    NSDictionary *pMap = [storage getPMap];

    // Step 2: 检查缓存完整性
    if (aId.length > 0 && aKey.length > 0 && pMap.count > 0) {
        // ✅ 缓存命中 - 直接使用
        [FlameLogger i:@"load ad from local cache......"];
        self.appEntity = [[FlameAppEntity alloc] init];
        self.appEntity.aId = aId;
        self.appEntity.aKey = aKey;
        [self.appEntity.pIds addEntriesFromDictionary:pMap];
        [callback success];
        return;  // 不发起网络请求
    }

    // Step 3: 缓存未命中 - 请求远程服务器
    [FlameLogger i:@"load ad from remote server......"];
    [self fetchFromRemoteServer:appId appKey:appKey callback:callback];
}
```

### 广告位ID查询性能

```objective-c
// 运行时查询 - 纯内存操作，无网络请求
NSString *toponPlacementId = [[FlameConfigManager sharedInstance] getPId:@"flame_placement_id"];

// 时间复杂度: O(1)
// 线程安全: ✅
// 网络请求: ❌ 无
```

### 缓存刷新策略

**当前策略**:
- 首次启动: 请求远程 API → 保存缓存
- 后续启动: 读取本地缓存 → 直接使用
- **无自动过期**: 缓存永久有效，直到手动清除

**手动清除缓存**:
```objective-c
// 清除所有配置缓存（内存 + 持久化）
[FlameSdk clear];
```

### 缓存策略特性对比

| 特性 | 支持情况 | 说明 |
|------|---------|------|
| 持久化存储 | ✅ | 使用 NSUserDefaults |
| 离线可用 | ✅ | 缓存后无需网络 |
| 自动过期 | ❌ | 无 TTL 机制 |
| 版本控制 | ❌ | 无缓存版本号 |
| 完整性校验 | ⚠️ | 仅检查非空 |
| 线程安全 | ✅ | atomic + @synchronized |
| 强制刷新 | ⚠️ | 需先 clear 再 init |

### 缓存数据流

```
App 首次启动:
  [FlameSdk init]
    → 检查本地缓存 (未命中)
    → HTTPS 请求 api.adsurge.cn/api/v1/sdk/init
    → AES 解密响应数据
    → 保存到 NSUserDefaults
    → 加载到内存 (appEntity)
    ✅ 初始化完成

App 后续启动:
  [FlameSdk init]
    → 检查本地缓存 (命中)
    → 加载到内存 (appEntity)
    ✅ 初始化完成 (无网络请求)

运行时查询:
  getPId:@"placement_id"
    → 从内存读取 (appEntity.pIds)
    → 返回映射的 TopOn PlacementId
    ✅ O(1) 查找
```

## 异常处理

### 初始化失败处理

SDK 在初始化过程中可能遇到以下异常：

| 场景 | 行为 | 状态 |
|------|------|------|
| 网络故障 | 触发 `fail` 回调 | `FlameSDKInitStateFailed` |
| 配置解析失败 | 触发 `fail` 回调 | `FlameSDKInitStateFailed` |
| Adapter 初始化失败 | 触发 `fail` 回调 | `FlameSDKInitStateFailed` |
| 重复初始化 | 直接返回成功 | `FlameSDKInitStateInitialized` |

**安全保障**:
```objective-c
// 检查初始化状态
if (![FlameSdk isInitialized]) {
    // SDK 未初始化，不应请求广告
}

// 失败后可以重试
[FlameSdk initWithAppId:appId appKey:appKey callback:callback];
```

## 调试模式

```objective-c
// 开启 Debug 日志
[FlameSdk setDebug:YES];
```

## 广告类型

Flame SDK 支持以下广告类型：

- ✅ 激励视频 (`FlameRewardAd`)
- ✅ 插屏广告 (`FlameInterstitialAd`)
- ✅ 开屏广告 (`FlameSplashAd`)
- ✅ 横幅广告 (`FlameBannerAd`)
- ✅ 原生广告 (`FlameNativeAd`)
- ✅ 视频流广告 (`FlameDrawAd`)

详细使用文档请参考各广告类型的接口说明。

## 注意事项

1. **缓存更新**: 当前版本不支持自动缓存过期，如需更新广告位配置，请先调用 `[FlameSdk clear]` 清除缓存后重新初始化

2. **线程安全**: SDK 内部已处理线程安全，可在任意线程调用

3. **初始化时机**: 建议在 `application:didFinishLaunchingWithOptions:` 中完成初始化

4. **网络依赖**: 首次启动需要网络请求，后续启动依赖本地缓存（建议首次启动时有网络环境）

## 技术支持

如有问题，请联系技术支持团队。

## 更新日志

### v1.0.0 (2026-03-18)
- 初始版本发布
- 支持 TopOn 适配器
- 实现两级缓存策略
- 支持 6 种广告类型
