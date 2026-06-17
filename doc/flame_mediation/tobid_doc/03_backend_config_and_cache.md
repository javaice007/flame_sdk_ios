# 03 - 后台配置结构与缓存策略

## 一、当前后台配置结构

### 1.1 请求

```
POST https://api.adsurge.cn/api/v1/sdk/init
Content-Type: application/json

{
  "appId": "Flame平台AppId",
  "version": "1.0.0",
  "timestamp": 1718XXXXXXX,
  "sign": "<MD5签名>"
}
```

### 1.2 响应（加密前）

```json
{
  "pt": "tk",
  "aId": "当前聚合平台AppId",
  "aKey": "当前聚合平台AppKey",
  "pIds": {
    "flame_splash_001": "topon_splash_001",
    "flame_reward_001": "topon_reward_001"
  }
}
```

### 1.3 当前结构是否足够？

**基本够用，但建议增加 `configVersion` 字段以支持缓存失效检测。**

理由：
- `pt` + `aId` + `aKey` + `pIds` 已足够标识一个聚合平台的完整配置
- 后台只返回当前 App 启用的平台凭证，SDK 按需初始化即可
- 但缺少版本标识，SDK 无法判断缓存是否过期

## 二、建议的后台配置结构

### 2.1 推荐结构

```json
{
  "pt": "tb",
  "aId": "ToBid的AppId",
  "aKey": "ToBid的AppKey",
  "pIds": {
    "flame_splash_001": "tobid_slot_001",
    "flame_reward_001": "tobid_slot_001"
  },
  "cv": "2026061101"
}
```

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `pt` | string | ✅ | 聚合平台标识: "tk", "tb", "csj" 等 |
| `aId` | string | ✅ | 该平台的 App ID |
| `aKey` | string | ✅ | 该平台的 App Key |
| `pIds` | object | ✅ | 广告位映射: Flame ID → 平台广告位 ID（当前阶段只支持 `Dict<String, String>`） |
| `cv` | string | 推荐 | 配置版本号，用于缓存失效检测。**当前不强依赖，但推荐后台支持** |

### 2.2 当前阶段 pIds 约束

> **当前阶段只做 App 级平台路由。**

- `pIds` **只支持 `Dict<String, String>`**，即每个 Flame 广告位 ID 映射到当前平台的一个广告位 ID
- **不要求兼容 object 类型广告位配置**（如 `{"pt": "csj", "id": "xxx"}`）
- **不在当前阶段实现广告位级平台路由**
- 广告位级平台路由**只作为未来设计预留**，不影响当前实施

### 2.3 未来扩展预留：广告位级平台路由（仅设计，不实施）

当前阶段不需要，但为未来预留设计空间：

```json
{
  "pt": "tb",
  "aId": "ToBid_AppId",
  "aKey": "ToBid_AppKey",
  "pIds": {
    "flame_splash_001": "tobid_splash_001",
    "flame_reward_001": "tobid_reward_001",
    "flame_reward_002": {
      "pt": "csj",
      "id": "csj_reward_002"
    }
  },
  "cv": "2026061101"
}
```

**实现思路**（未来）：
- `pIds` 的值支持 `string`（使用默认平台）和 `object`（指定特定平台）
- `FlameConfigManager.getPId:` 扩展为 `getPId:platform:` 同时返回平台标识和广告位 ID
- 广告创建时先检查该广告位是否有特殊平台映射，无则使用默认 `pt`

**当前阶段明确不实施上述扩展。**

## 三、缓存策略设计

### 3.1 当前缓存机制的问题

| 问题 | 说明 |
|------|------|
| 无版本标识 | SDK 无法判断缓存是否过期 |
| 无过期时间 | 缓存永不过期，即使后台已切换平台 |
| 平台切换无法感知 | 后台从 tk 切到 tb 后，SDK 仍使用缓存的 tk 凭证 |
| 命中条件不严格 | 仅检查 aId/aKey/pMap 非空，缺少 pt 检查 |

### 3.2 新缓存策略：网络优先，失败 fallback 缓存

> **核心原则**：每次冷启动 `init` 优先请求后台配置，不依赖 TTL 作为主刷新策略。

```
App 冷启动 → FlameSdk.init
  │
  ├─ 【优先】发起后台网络请求
  │   │
  │   ├─ 网络成功 → 使用最新配置 → 更新本地缓存 → callback.success
  │   │
  │   └─ 网络失败 → 检查本地缓存完整性
  │       │
  │       ├─ 缓存完整（pt + aId + aKey + pMap 均存在）
  │       │   → fallback 使用缓存 → callback.success → warning 日志
  │       │
  │       └─ 缓存不完整
  │           → callback.fail（错误码 15000）
  │
  └─ 无网络且无缓存 → callback.fail（错误码 15000）
```

**为什么不采用 24 小时 TTL 作为主刷新策略**：
- 后台从 `tk` 切到 `tb` 后，如果 SDK 使用 TTL 策略，最长需要 24 小时才能感知切换
- 网络优先策略确保每次冷启动都能获取最新平台配置，平台切换即时生效
- `FlameSdk.clear()` 仍可强制清除缓存，作为手动兜底

### 3.3 缓存完整性条件

缓存必须同时包含以下字段才视为**完整**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `pt` | string | **必须** 平台标识 |
| `aId` | string | **必须** 平台 App ID |
| `aKey` | string | **必须** 平台 App Key |
| `pMap` | string | **必须** 广告位映射序列化 |
| `cv` | string | 可选，推荐后台支持，用于日志和未来版本比较 |
| `cachedAt` | double | 可选，用于日志和兜底判断，不作为主刷新依据 |

```objc
BOOL cacheComplete =
    cached.pt.length > 0 &&
    cached.aId.length > 0 &&
    cached.aKey.length > 0 &&
    cached.pIds.count > 0;
```

### 3.4 cv / configVersion 的定位

- `cv` / `configVersion` 是**推荐后台支持的字段**，但当前阶段**不强依赖**
- 当前主要用途：日志记录、辅助调试
- 未来可扩展为：异步后台验证（先缓存启动，后台异步验证 cv 是否一致）
- **不采用 cv 作为主刷新判断依据**，主策略始终是"每次冷启动网络优先"

### 3.5 cachedAt 的定位

- `cachedAt` 可用于日志记录和兜底判断
- **不作为主刷新依据**（不使用 `cachedAt + TTL` 作为决定是否使用缓存的条件）
- 未来可考虑：如果 `cachedAt` 过于久远（如超过 7 天），记录 warning 日志

### 3.6 新缓存数据结构

`FlameConfigLocalStorage` 新增缓存键：

| 键 | 类型 | 说明 |
|----|------|------|
| `pt` | string | 平台标识（已有） |
| `aId` | string | 平台 App ID（已有） |
| `aKey` | string | 平台 App Key（已有） |
| `pMap` | string | 广告位映射序列化（已有） |
| `cv` | string | **新增** 配置版本号（可选） |
| `cachedAt` | double | **新增** 缓存写入时间戳（秒，可选） |

### 3.7 缓存写入时机

```objc
// FlameConfigManager 网络请求成功后
FlameAppEntity *entity = /* 从解密 JSON 解析 */;

[FlameConfigLocalStorage putWithPt:entity.pt
                              aId:entity.aId
                             aKey:entity.aKey
                              pMap:serializedPIds
                                cv:entity.cv  // 可选，后台支持时写入
                           cachedAt:@([[NSDate date] timeIntervalSince1970])]; // 可选
```

### 3.8 缓存读取逻辑（fallback 时使用）

```objc
+ (FlameAppEntity *)getCachedEntity {
    NSString *pt    = [defaults objectForKey:@"pt"];
    NSString *aId   = [defaults objectForKey:@"aId"];
    NSString *aKey  = [defaults objectForKey:@"aKey"];
    NSString *pMap  = [defaults objectForKey:@"pMap"];
    NSString *cv    = [defaults objectForKey:@"cv"];
    double cachedAt = [defaults doubleForKey:@"cachedAt"];

    // 缓存完整性必须包含 pt + aId + aKey + pMap
    if (pt.length == 0 || aId.length == 0 || aKey.length == 0 || pMap.length == 0) {
        return nil;  // 缓存不完整，不可用
    }

    FlameAppEntity *entity = [[FlameAppEntity alloc] init];
    entity.pt = pt;
    entity.aId = aId;
    entity.aKey = aKey;
    entity.pIds = /* 反序列化 pMap */;
    entity.cv = cv;
    entity.cachedAt = [NSDate dateWithTimeIntervalSince1970:cachedAt];
    return entity;
}
```

### 3.9 边缘场景处理

| 场景 | 处理策略 |
|------|----------|
| **网络成功** | 使用最新配置，更新缓存 |
| **网络失败 + 缓存完整** | fallback 使用缓存，记录 warning 日志，SDK 正常工作 |
| **网络失败 + 缓存不完整** | callback.fail，错误码 15000 |
| **网络失败 + 无缓存** | callback.fail，错误码 15000 |
| **App 更新 + SDK 版本升级** | 不清除缓存（向后兼容），下次冷启动自动请求最新配置 |
| **后台 pt 变化**（tk→tb） | 下次冷启动网络请求自动获取新 pt，即时切换 |
| **后台返回未知 pt** | Registry 查找失败 → callback.fail，错误码 14003 |
| **FlameSdk.clear()** | 清除所有缓存 + 重置状态，下次 init 强制网络请求 |

### 3.10 FlameAppEntity 扩展

```objc
@interface FlameAppEntity : NSObject

@property (nonatomic, copy) NSString *pt;         // 平台标识
@property (nonatomic, copy) NSString *aId;        // 平台 App ID
@property (nonatomic, copy) NSString *aKey;       // 平台 App Key
@property (nonatomic, strong) NSDictionary *pIds;  // 广告位映射
@property (nonatomic, copy) NSString *cv;         // 【新增】配置版本
@property (nonatomic, strong) NSDate *cachedAt;   // 【新增】缓存时间

@end
```
