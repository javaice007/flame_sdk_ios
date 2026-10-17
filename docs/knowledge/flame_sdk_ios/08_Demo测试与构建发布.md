# 08 · Demo / 测试 / 构建发布

> 代码证据：`../adsurge-ios-demo/`（只读）、`flame_sdk_iosTests/`、`xcFramework_build.sh`、`docs/releases/`、README.md

## Demo 使用证据（PUBLIC_API_USAGE_EVIDENCE）

Demo 仓库：`/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo`（Swift 工程，Podfile 依赖 `flame_sdk_ios_tb 1.0.0`，source = javaice007/flame-specs）。

**1. SDK init 实际调用**（Sources/Ad/FlameSDKManager.swift）：

```
FlameSdk.clear()            // Demo 固定在每次 initialize 前清缓存（SDK 文档要求）
FlameSdk.setDebug(false)
FlameSdk.initWithAppId(appId, appKey: appKey, callback: callback)
// callback 内自行 DispatchQueue.main.async 归一 + didNotify 防重
```

appId/appKey 来自 FlameAdConfig.swift 的 TK/TB 双变体常量（**值不写入本知识库**）。

**2. placementId 传什么**：FlameAdConfig.PlacementId 枚举——按 TK/TB 变体维护 **Flame 平台广告位字符串常量**（banner/bannerSelfRender/splash/interstitial/native/rewardVideo 六类），load 前仅做非空 isConfigured 检查。

**3. Reward create/load/show**（RewardVideoAdManager.swift）：

```
guard SDK 已初始化、placementId 已配置、rewardAd == nil
let created = FlameSdk.createRewardAd(with: vc, placementId: …, listener: listener)
rewardAd = created as AnyObject & FlameRewardAd   // Swift 导入 ObjC 协议的标准写法
rewardAd?.load(withUserId: "…", userCustomData: "…")
show: if ad.isReady() { ad.show() } else { load(); notReady?() }
onClosed → rewardAd = nil → load() 下一条（自动预加载循环）
onError  → RetryScheduler（max 5 次退避重试；14003/14004/14002 短路不重试）
```

**4. listener 实现**：`RewardVideoListener: NSObject, FlameRewardListener` 实现**全部 7 个方法**，桥接为 Swift 闭包，回调内自行 dispatch main。

**5. SDK version 展示**：Demo 未调用 getVersion 展示（grep 无命中）；版本锁定在 Podfile `pod 'flame_sdk_ios_tb', '1.0.0'`。

## 测试现状

- `flame_sdk_iosTests/flame_sdk_iosTests.m`：Xcode 模板空壳（testExample/testPerformanceExample 零断言）
- 无 Mock/Stub/Fake network/Ad mock、无 UI Test target
- 实际质量保障：**手工真机回归**，验收记录在 README + doc/flame_mediation/phase-5a.*.md（含 TK/TB 各广告类型闭环、三次冷启动、坐标审计等）

## 构建链（xcFramework_build.sh，唯一变体 single-binary）

```
pod deintegrate + 干净 pod install（OpenSSL + AnyThinkiOS + ToBid-iOS-RC）
→ AnyThinkSDK 弱链接 patch（xcconfig sed，幂等 + fail-fast）
→ ToBid 静态归档隔离（剔除 -framework Wind* + -undefined dynamic_lookup + 临时隐藏归档，trap 恢复）
→ xcodebuild archive 真机（generic/iOS，BUILD_LIBRARY_FOR_DISTRIBUTION=YES，deployment 13.0）
→ xcodebuild archive 模拟器（ARCHS=x86_64）
→ xcodebuild -create-xcframework → build/flame_sdk_ios.xcframework
→ 清 .sh/.podspec、剥 bitcode
→ 符号自检：nm 校验 Flame/TK/TB/+load 符号；三方污染检测=0；
  otool 断言 LC_LOAD_WEAK_DYLIB / 无 Wind* 动态依赖 / 有 OpenSSL；bundle 污染检查
→ 复制到仓库根目录（本地 :path=> 验证用）
```

## 发布链（人工流程，无 CI）

```
改两个 podspec s.version + FlameConfigManager.m 的 FLAME_SDK_VERSION
→ ./xcFramework_build.sh
→ 人工同步 xcframework 到 GitHub binary repo（javaice007/flame_sdk_ios）根目录
→ binary repo 打 tag = 版本号
→ podspec 推送到私有 spec repo（javaice007/flame-specs）
→ dev 仓库 release commit + docs/releases/<ver>.md 快照 + README 版本更新
```

- 无 GitHub Actions / Jenkins / fastlane / Gitee Pipeline
- README 引用的 `./scripts/preflight_release.sh` **不存在**（文档漂移）
- 发布规范（README）：alpha 必须带序号、禁止跳号/覆盖/重复发布
