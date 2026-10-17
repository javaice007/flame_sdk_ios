# 02 · SDK 初始化与配置

> 代码证据：`flame_sdk_ios/core/FlameSdk.{h,m}`、`flame_sdk_ios/core/FlameConfigManager.{h,m}`、
> `flame_sdk_ios/mediation/{tk/FlameTKProvider.m, tb/FlameTBProvider.m}`、`flame_sdk_ios/core/FlameAppEntity.m`

## 1. Public Init API（源码术语，非后端术语）

`FlameSdk.h` 暴露（全部类方法，另有 `+sharedInstance` 与实例方法 `-getVersion`）：

```objc
+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey;
+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback;
+ (void)clear;
+ (void)setDebug:(BOOL)isDebug;
+ (BOOL)isInitialized;
+ (BOOL)checkInitialization;
```

- **参数在源码中叫 `appId` / `appKey`**（即文档语境的 platformAppid / platformAppkey，但公开签名不用后端术语）。
- 它们是 **Flame 平台**的凭证，不是 AnyThink/ToBid 的；聚合平台凭证（aId/aKey）由服务端下发。
- callback 类型 `id<FlameCallback>`：`-success` / `-fail:(NSString*)code desc:(NSString*)desc`（**字符串错误码**）。

## 2. 初始化 API Surface 一览

| API | 用途 | 前置条件 | 后置状态 | 客户是否需要 | 属性 |
|---|---|---|---|---|---|
| `+initWithAppId:appKey:` | 无回调初始化 | 无 | 见状态机 | 基本用法 | STABLE |
| `+initWithAppId:appKey:callback:` | 带回调初始化 | 无 | 见状态机 | 推荐用法 | STABLE |
| `+clear` | 清缓存+重置状态+清 Router | 无 | Uninitialized | 失败后重试前 / Demo 每次启动前调用 | STABLE |
| `+isInitialized` | 查询状态 | 无 | 不变 | 可选 | STABLE |
| `+checkInitialization` | 校验+失败打日志 | 无 | 不变 | 内部偏多（Impl 层在用） | PUBLIC_INTERNALISH |
| `+setDebug:` | 平台 SDK 日志开关 | 无 | 不变 | 调试期 | STABLE（注意：只作用于 AnyThink/WindMill，不影响 FlameLogger） |
| `-getVersion` | 版本号字符串 | 实例 | 不变 | 展示用 | STABLE（返回 FlameConfigManager.m:17 的 FLAME_SDK_VERSION 常量，非 Bundle 版本） |

## 3. Init 状态机（4 态，源码确认）

`FlameSdk.m` 私有枚举：`Uninitialized / Initializing / Initialized / Failed`，`@synchronized(instance)` 保护 + `pendingCallbacks` 等待队列。

| 场景 | 行为 |
|---|---|
| 第一次 init | Uninitialized→Initializing→发配置请求→成功走 Provider 初始化→Initialized/Failed |
| 并发重复 init（Initializing 中） | 新 callback **入队不重发请求**，完成后与首个 callback 一起被通知 |
| 已 Initialized 再 init | **立即 success 回调**，不发请求 |
| Failed 后再 init | **fail(14000)**，desc 提示必须先 `clear()`（不自动穿透重试） |
| clear 后再 init | 正常重新走全流程（清内存/磁盘缓存/取消请求/清 Router） |

**FAILED 后为什么必须 clear**：这是 `FlameSdk.m:422-430` 的实现选择（防失败风暴的显式锁定），**以 fail 回调的 desc 文本形式暴露给客户，公共头文件没有文档化**。属于"事实契约"：Demo 的用法是每次 initialize 前都先 `FlameSdk.clear()`，从而完全绕开该锁定。

## 4. 完整内部调用链

```
FlameSdk.initWithAppId:appKey:callback:
  → 状态机判定（@synchronized）
  → UpdateAppCallback 包装（hasCalled 防重复，@synchronized）
  → FlameConfigManager.updateAppWithAppId:appKey:callback:
      ├─ 读本地缓存完整性（pt+aId+aKey+pMap 全非空 → cacheComplete）
      ├─ 取消旧请求 + requestGeneration++（代际去重）
      ├─ sign = FlameMd5SignatureUtils.signWithParams:{appId,version,timestamp} appKey:
      ├─ FlameNetworkUtils.doPostJson → POST /api/v1/sdk/init（15s 超时，completion 强制主线程）
      ├─ 网络失败：cacheComplete ? 重建缓存实体+success : fail(error.code, desc)
      ├─ 网络成功：data.edata → FlameAesCryptoUtils.decrypt:rawKey:appKey → FlameAppEntity.fromJson
      │          → 内存 appEntity + FlameConfigLocalStorage 落盘
  → UpdateAppCallback.success（主线程）
      ├─ registerAllProvidersIfNeeded（兜底；正常由 +load 已注册）
      ├─ pt = config.getPt（空则默认 "tk"，仅日志）
      ├─ provider = Registry.providerForPlatformCode(pt)；无 → fail(14003)
      ├─ Router.activateProvider(provider)
      └─ provider.initializeWithAppId:aId appKey:aKey callback:AdapterInitCallback
           ├─ TK: NSClassFromString(@"ATAPI")==nil → fail("TK_PLATFORM_REQUIRES_ANYTHINK")
           │      否则 [ATAPI setLogEnabled:YES] + integrationChecking
           │      + [[ATAPI sharedInstance] startWithAppID:appKey:error:]（同步）
           └─ TB: [WindMillAds setupSDKWithAppId:appId completionHandler:]（异步块）
                  + [WindMillAds setDebugEnable:YES]
  → AdapterInitCallback（hasCalled 防重）→ 更新状态机
      → 通知当前 callback + pendingCallbacks（锁内 copy 清空、锁外回调防死锁）
```

## 5. Callback 线程语义

| 环节 | 线程 |
|---|---|
| Config 网络请求 completion | **主线程**（FlameNetworkUtils 强制 dispatch main） |
| UpdateAppCallback（配置阶段） | 主线程 |
| Adapter 初始化（TK） | 同步执行于调用线程 = 主线程 |
| Adapter 初始化（TB） | WindMill completionHandler 线程（**由三方决定，Flame 未归一**） |
| 最终 Public callback | TK 链路事实为主线程；**TB 链路未保证**，Demo 侧自行 `DispatchQueue.main.async` 防御 |

## 6. READY 语义（最关键兼容契约）

**INITIALIZATION_READY_SEMANTICS = B（配置拉取成功 且 聚合平台 SDK 初始化成功）**

- `success` 触发条件：`/sdk/init` 拉取解密成功（或缓存回退）**且** Router 按 pt 激活 Provider **且** Provider.initializeWithAppId 成功（TK: startWithAppID 无 error；TB: setupSDKWithAppId completion success==YES）。
- success **不代表已有任何广告填充**；但此后 `create*Ad / load` 即刻可用（isInitialized==YES 是 create 的唯一门槛）。
- 任何一环失败 → fail，状态机进 Failed。

## 7. 缓存回退是否 Public Contract

**无任何 callback 字段区分 REMOTE INIT vs CACHE FALLBACK**——两种情况都只触发 `success`，区别仅在 FlameLogger 控制台日志（"fallback to local cache"）。即**当前 Public Contract 把两者都视为成功**。注意：缓存回退的 success 依旧会继续走 Provider 初始化。

## 8. /sdk/init 请求与响应

- Method/Path：`POST https://api.adsurge.cn/api/v1/sdk/init`（硬编码 FlameConfigManager.m:139）
- Request DTO：`{appId, version, timestamp(ms), sign}`（Content-Type application/json，无自定义 header）
- Response envelope：`{ ..., data: { edata: "<base64>" } }`
- SDK 实际校验：根是 dict → data 非 NSNull 且是 dict → edata 非 NSNull、是 NSString、非空。**envelope 的 code/msg 字段不校验**。
- edata = Base64(IV 12B + Ciphertext + TAG 16B)，AES-GCM，key = appKey UTF-8 原始字节（无 KDF）
- 解密后 DTO（FlameAppEntity.fromJson 实际认识的字段）：

| 字段 | 认识? | 说明 |
|---|---|---|
| pt | ✅ | "tk"/"tb"，平台选择 |
| aId | ✅ | 聚合平台 AppId |
| aKey | ✅ | 聚合平台 AppKey（TK 用作 AnyThink appKey；TB 初始化不用） |
| pIds | ✅ | dict：Flame 广告位 → 平台广告位 |
| cv | ✅（可选） | 解析+落盘，但**从不回传、无 TTL 语义（死字段）** |
| scenePIds | ❌ 不认识 | 未解析 |
| content | ❌ 不认识 | 未解析 |

## 9. 前向兼容结论

**SDK_INIT_FORWARD_COMPATIBILITY = PASS**：解析用 NSJSONSerialization 整体反序列化 + 只按 key 取已知字段，未知字段（含后端新增 scenePIds / content）被静默忽略，旧 SDK 在新后端响应下工作正常。反向（SDK 认识字段而后端缺失）会退化为 nil/空并按不完整处理。

## 10. Provider 初始化差异备忘

| | TK (FlameTKProvider.m) | TB (FlameTBProvider.m) |
|---|---|---|
| 平台 SDK | AnyThink/TopOn 6.5.71 | ToBid/WindMill 5.5.6 |
| 初始化 API | `[[ATAPI sharedInstance] startWithAppID:appKey:error:]` 同步 | `[WindMillAds setupSDKWithAppId:completionHandler:]` 异步 |
| appKey | 用作 AnyThink appKey | **不使用**（仅接收） |
| 弱链接守卫 | NSClassFromString(@"ATAPI") | 无需（U 引用 lazy） |
| debug | `[ATAPI setLogEnabled:YES]`（硬编码 YES） | `[WindMillAds setDebugEnable:YES]`（硬编码 YES） |
| 失败码 | error.code 字符串 / "TK_PLATFORM_REQUIRES_ANYTHINK" | "14001" |
