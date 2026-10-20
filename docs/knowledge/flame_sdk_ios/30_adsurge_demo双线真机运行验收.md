# 30 · adsurge-ios-demo 双线真机运行验收（P3-DUAL）

> 阶段标识：P3-DUAL ｜ 日期：2026-10-20 ｜ 设备：iPhone 16 Pro / iOS 26.6.2（USB）
> SDK checkpoint：`1ef40ce`（TK 6.5.84 @ `024a2e6`，TB 5.10.1 @ `1ef40ce`）
> 验证 Demo：`/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo`
> **P3-R1 纠正（2026-10-20）**：Taku ADX 由 REAL_AD_PASS 降为 BID_RESPONSE_PASS（仅证明参与竞价返回 offer，未证明 winning/show/impression）；逐源最终状态以 doc 31 为准。
> 结论：**`IOS_DUAL_LINE_RUNTIME_ACCEPTANCE = PARTIAL`**——两线五类 Flame API 全部真实 load/show/callback 通过，
> 已填充的广告源真实验证通过；但 TK 13 源 / TB 12 源中多数无法在当前测试位 waterfall 中强制命中，
> 按发布口径标 `PENDING_PRODUCTION_OBSERVATION`（不阻塞 1.1.0），不伪造 PASS。

---

## 1. SDK 本地双包（本轮重建，非旧中间产物）

```
TK_LOCAL_XCFRAMEWORK_BUILD = PASS   ./xcFramework_build.sh tk-static → flame_sdk_ios.xcframework
TB_LOCAL_XCFRAMEWORK_BUILD = PASS   ./xcFramework_build.sh tb-static → tb/flame_sdk_ios.xcframework
TK arm64 sha256 = 68a1e5d1d3bc7f4f66f8530823356f3045fdaa395d571e42d504562c70f4b92c（与 P2-TK checkpoint 逐字节一致）
TK sim   sha256 = cc131594d6601ef2f760b41d13ab766c0b600de4b77a3b83528988714cc9f4fa
TB arm64 sha256 = 7034acf68bd1f5076c82def4e8677c4b998142a68647de3f6a8c355fa07cbb92
TB sim   sha256 = b7f008bb91d8d3e4086da2828435a816782f52e9da8f5d0c289b091954a121e2
隔离快检：TK 产物 WindMill/Tb* = 0；TB 产物 AnyThink/At* = 0
```

## 2. Demo 原始状态与保护

- 原分支 `verify/tk-alpha2-reward-callback` @ `5c57859`，有 8 个未提交修改 + 4 个未跟踪报告 →
  **按项目负责人指示** `git stash push -u`（stash@{0}，可 `git stash pop` 恢复），未覆盖任何业务修改；
- 分叉分析：`5c57859` = `main` + 1 提交（引入 TK/TB 配置组 `activeVariant`）；main 本身无双线配置 →
  验证分支 `verify/p3-dual-local-1.1.0` 建在 `5c57859` 上；
- Demo 切线机制：`FlameAdConfig.activeVariant`（"tk"/"tb"）+ Podfile pod 名；
- 广告位组按项目负责人本轮提供值写入（VALIDATION_ONLY）：
  TK = SDK_test（b64032443515；splash q89260083668 / banner q23035526072 / selfRender q65796594128 /
  interstitial q28769551483 / native q37474029164 / reward q35212297134）；
  TB = tobid接入测试-sigmob应用（b22375234108；splash q76977734904 / banner q71507861622 /
  interstitial q37305276475 / reward q57514498879 / native q44128606635 → 第二轮改 q82857633975）。
- 签名：Demo 自身 bundle `com.hbjzzr.dyd.demo` 本机无 profile；按指示用 `com.flame.sdk.test`
  （team BTY45V9GK4，命令行覆盖，未改工程文件）。

## 3. Demo 本地接入方式与两次 fresh resolution

```
DEMO_TK_LOCAL_POD_REFERENCE = pod 'flame_sdk_ios',    :path => '/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk'
DEMO_TB_LOCAL_POD_REFERENCE = pod 'flame_sdk_ios_tb', :path => '/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk'
DEMO_TK_TB_MIXED_INSTALL = NO（任一时刻 Podfile 仅一个 flame pod；切线时 rm -rf Pods Podfile.lock build/）
```

| 线 | pods | Core | Adapter 矩阵 | 禁止项 |
|---|---|---|---|---|
| TK | 27 | AnyThinkiOS 6.5.84 | 11 个 Taku adapter 全命中 P2 冻结版本（Sigmob 5.1.3.2.0 官方） | ToBid=0 WindMill=0 flame_sdk_ios_tb=0 私有sigmob=0 |
| TB | 14 | ToBid-iOS 5.10.1 | 11 subspec 全 5.10.1；Network 11 项与 doc29 一致 | AnyThink=0 flame_sdk_ios=0 ToBid-iOS-RC=0 SigmobAd-iOS=0 |

```
DEMO_TK_DEPENDENCY_RESOLUTION = PASS
DEMO_TB_DEPENDENCY_RESOLUTION = PASS
```

## 4. TK 线运行验收（日志：adsurge-ios-demo/p3logs/tk_runtime_console.log，946 行）

```
DEMO_TK_BUILD = PASS（BUILD SUCCEEDED；error=0 dup=0 undef=0；App dylib 零 WindMill/ToBid/FlameTBProvider；官方 ATSigmob adapter 在位；私有 sigmob 残留 0）
DEMO_TK_RUNTIME_INIT = PASS
  FlameTKProvider +load 注册 → pt=tk → Router 激活 'tk' → "开始初始化 TopOn / AnyThink" → FlameSdk initialized successfully
DEMO_TK_RUNTIME_CORE = UA_6.5.84
  证据：真机安装包 Frameworks/AnyThinkSDK.framework 二进制唯一版本串 UA_6.5.84（Demo 未调用 [ATAPI version]；
  日志中 "SDMAdLogger(UA_6.5.90)" 是酷盈 ADX adapter 6.5.90.2.1 的 logger 标签，不是 Core）
TK_ZERO_TOBID_RUNTIME = PASS（日志 WindMill/ToBid = 0）
crash / unrecognized selector = 0
```

| 类型 | Load | Fill | Show | Impression/Callback | Reward/特殊 | 结果 |
|---|---|---|---|---|---|---|
| Splash | 开始加载 | onAdLoaded(+2439ms) | 展示 | onAdShowComplete → 关闭；热启动预加载就绪 | — | PASS |
| Banner（Express） | 开始加载 | 加载成功 | 展示 | — | — | PASS |
| SelfRender Banner | 开始加载 | onAdLoaded，素材 1 条 | bindMaterial(0) | — | — | PASS |
| Interstitial | 4 轮 开始加载→加载成功 | 4 次 fill | 4 次展示 | 4 次 关闭→加载下一条 | — | PASS |
| Rewarded Video | 开始加载 | 加载成功 | 展示 | 点击 → 关闭→加载下一个 → 再次加载成功 | **奖励 transId=bc79d0ebdcff698c0f0ab36f75911397_16577413_1792504546009** userId=test_user_001 customData={"level":1,"coins":100} | PASS |
| Native（Express） | Start loading native ×9 | ADXNative didLoad ×4 + Taku callback ×9 | Show Native Ad ×9 | callback info：adunit_format=Native, network_name=**Gromore**, network_firm_id=46 | 模板广告伞展示（pseudo fullscreen 包装） | PASS |

```
TK_FIVE_FORMAT_RUNTIME = PASS
```

**TK 逐源（LEVEL 3 以 Taku 回传 network_firm_id / adapter 日志为准）**

| Network | adapter init | 真实 fill 证据 | 状态 |
|---|---|---|---|
| GroMore | ✓ | Native：callback network_name=Gromore nfid=46 ×9 | REAL_AD_PASS |
| Taku ADX（酷盈 6.5.90） | ✓（SDMAdLogger 初始化、ADXOfferBanner/ADXNative didLoadMetaData/Offer ×8） | ADX 真实参与 bidding 并返回候选 offer（oid）；**未证明 ADX 成为 winning、实际 show、impression**（Native 最终 winning 为 Gromore） | **BID_RESPONSE_PASS / PRODUCTION_OBSERVATION**（P3-R1 纠正，原误标 REAL_AD_PASS） |
| Pangle/CSJ 单接 | ✓（随 TTAdapter_Mix 7.8.0.5 装载） | 本轮无 TT 单接 fill 日志（Native 走 GM） | PENDING_PRODUCTION_OBSERVATION |
| Sigmob（官方 5.1.3.2.0） | ✓（ATSigmob*Adapter 在位，无私有残留） | 本轮 waterfall 未命中 | PENDING_PRODUCTION_OBSERVATION |
| GDT / Baidu / KS / MS / ZY / Funlink / BeiZi | ✓（adapter 均链入，无 NoClass） | 未命中（Splash/Interstitial/Reward/Banner 的命中源 Demo 未打印，无法归因） | PENDING_PRODUCTION_OBSERVATION |
| AdGain 4.2.7.1 / FSUnion 1.0.8.0（新 Core 兼容） | ✓（链入，无 selector/protocol 错误，init 无异常） | 未命中 | PENDING_PRODUCTION_OBSERVATION（兼容性 LEVEL 2 PASS） |

> 说明：Splash/Interstitial/Reward/Banner 四类**真实填充并展示**，但 Demo 对这四类不打印 Taku callback info，
> 故无法将其归因到具体 Network；需后续在 Demo 中增加 `VALIDATION_ONLY` 的 callback info 打印或从 Taku 后台报表核对。

## 5. TK → TB 切线

```
TK_TO_TB_SWITCH_CLEAN = YES
  记录 TK 日志/lock → Podfile 换 flame_sdk_ios_tb :path → activeVariant="tb" → rm -rf Pods Podfile.lock build/p3tk
  → fresh pod install（14 pods）→ 重新 build → 重新安装（新 installationURL）
```

## 6. TB 线运行验收（日志：p3logs/tb_runtime_console_round1_native_q44128606635.log 631 行 + tb_runtime_console_round2.log 640 行）

```
DEMO_TB_BUILD = PASS（BUILD SUCCEEDED；error=0 dup=0 undef=0；App dylib 零 AnyThink/AT*/FlameTKProvider；FlameTBProvider 在位；WindMill 类 33,586）
DEMO_TB_RUNTIME_INIT = PASS
  FlameTBProvider +load 注册 → pt=tb → Router 激活 'tb' → WindMill Splash manager init → sigmob ConfigAdapter init
DEMO_TB_RUNTIME_CORE = 5.10.1
  证据：pod resolution ToBid-iOS 5.10.1 + 安装包静态链接；日志 Sigmob 策略回包含 WindSDK 5.1.4；
  Demo 未调用 [WindMillAds sdkVersion]（P2 同一 Core 的独立探针真机返回 5.10.1）
TB_ZERO_ANYTHINK_RUNTIME = PASS
  （正则初筛 18 条"命中"经逐条核对均为 ToBid 自身 NativeAdAdapter 类名与 Sigmob 策略 JSON 字段，排除后 AnyThink = 0）
crash = 0
```

| 类型 | Load | Fill | Show | Callback | Reward/特殊 | 命中源 | 结果 |
|---|---|---|---|---|---|---|---|
| Splash | 开始加载 | fill（+0.9s） | 展示 6s | 关闭 → 预加载后台加载 | — | sigmob SplashAdAdapter | PASS |
| Banner | 开始加载 | 加载成功 | 展示 | — | — | GDT BannerAdAdapter | PASS |
| SelfRender Banner | TB 组未配置该位 → Demo 正确跳过 | — | — | — | — | — | N/A（配置缺位） |
| Interstitial | 开始加载 | 加载成功 | 展示 | 关闭→加载下一条→再 fill | — | sigmob InterstitialAdAdapter | PASS |
| Rewarded Video | 开始加载 | 加载成功 | 展示 | **奖励 transId=CEE3FF95-A551-48D0-9875-B3B38665A5CC** userId=test_user_001 | 关闭回调在第一轮采集重启前未落日志（时序，非功能） | sigmob RewardVideoAdAdapter | PASS |
| Native round1（q44128606635 → ToBid 9376521516682237） | Start loading ×7 | **no-fill 800110 ×7**（waterfall 仅 CSJ networkId=13 / netPlacement 952881288，穿山甲 nativeExpressAdFail） | — | Flame 正确回传 managerDidFail | — | CSJ（无物料） | NO_FILL（后台/物料侧） |
| Native round2（**q82857633975** → ToBid 1619313335657755） | Start loading ×3 | nativeExpressAdSuccess ×3 | Show Native Ad ×3 + RenderSuccess + WillShow + 视频状态回调 | 一次"渲染偏好与物料模式不一致，已按物料能力渲染"降级日志（正常） | 项目负责人肉眼确认物料 | CSJ NativeAdAdapter | PASS |

```
TB_FIVE_FORMAT_RUNTIME = PASS（五类均真实 load/show/callback；Native 需用 q82857633975）
```

**TB 12 源逐源**

| Network | adapter init | 真实 fill | 状态 |
|---|---|---|---|
| Sigmob（Core 内置 WindSDK 5.1.4） | ✓ ConfigAdapter + Splash/Interstitial/Reward adapter | Splash / Interstitial / Reward 三格式真实填充 + 发奖 | REAL_AD_PASS |
| GDT 4.16.11 | ✓ | Banner 真实填充展示 | REAL_AD_PASS |
| CSJ 7.8.0.5 | ✓ NativeAdAdapter（round1 ×14 / round2 ×6） | round2 Native 真实填充；round1 位 no-fill | REAL_AD_PASS（Native） |
| GroMore 7.8.0.5 | ✓（链入，无 NoClass/Bridge 错误） | 未命中 | PENDING_PRODUCTION_OBSERVATION |
| Baidu / KS / MS / Octopus / Mintegral | ✓ | 未命中（测试位 waterfall 未挂） | PENDING_PRODUCTION_OBSERVATION |
| JuTui 4.5.5.1 **NEW_NETWORK_INTEGRATION** | ✓ 链入（WindMillJuTui* 类 6，无 selector 错） | 未命中（后台未配） | PENDING_PRODUCTION_OBSERVATION + 需 ToBid 后台配置 |
| AdScope 5.5.3.4 **NEW_NETWORK_INTEGRATION** | ✓ 链入（WindMillBeiZi* 7） | 未命中 | PENDING_PRODUCTION_OBSERVATION + 需后台配置 |
| Kuying 6.5.66 **NEW_NETWORK_INTEGRATION** | ✓ 链入（WindMillKuying* 9） | 未命中 | PENDING_PRODUCTION_OBSERVATION + 需后台配置 |

TB 专项：Sigmob 单份 WindSDK 5.1.4（日志回包确认）；CSJ 7.8.0.5 真实初始化并填充（无 7.6.0.4）；无 NoClass / Bridge 错误。

## 7. SKAdNetwork

```
基准：doc/flame_doc/SKAdNetworkItems_merged_2026-10-20.plist（119）
Demo Resources/Info.plist：21 → 119（lowercase 去重，Demo 原有 21 全部包含于基准）
其余 15 个 Info.plist 键逐字节未变；plutil -lint OK；TB round2 安装包内 SKAd = 119
DEMO_SKADNETWORK_COUNT = 119
```

## 8. 双线最终矩阵

| Line | Core | Build | Init | 五类 API | Network Runtime | 隔离 |
|---|---|---|---|---|---|---|
| TK | Taku 6.5.84（UA_6.5.84） | PASS | PASS | 5/5 PASS | GroMore REAL；ADX BID_RESPONSE；其余 PENDING_PRODUCTION_OBSERVATION | zero ToBid/WindMill ✓ |
| TB | ToBid 5.10.1 | PASS | PASS | 5/5 PASS（Native 用 q82857633975） | Sigmob + GDT + CSJ REAL；其余 PENDING（含新三源） | zero AnyThink/Taku ✓ |

## 9. Blocking / Pending / 后续人工操作

- **PENDING_PRODUCTION_OBSERVATION**（P4-RC 发布口径：非 SDK 缺陷，测试位 waterfall 未挂或无物料；项目负责人已冻结**不再安排发布前专项补测**，不阻塞 1.1.0 RC/正式发布，上线后随真实流量观察，如有问题走 1.1.x）：
  TK = [Pangle单接, Sigmob, GDT, Baidu, KS, MS, ZY, Funlink, BeiZi, AdGain, FSUnion]；
  TB = [GroMore, Baidu, KS, MS, Octopus, Mintegral, JuTui(NEW), AdScope(NEW), Kuying(NEW)]
- 后续（线上观察期，非发布门禁）：① 线上 waterfall 命中后在 Taku/ToBid 报表观察各源请求/填充；② TB 新三源随线上配置生效后观察；
  ③ TB Native 后台位 q44128606635 的 CSJ 952881288 无物料，建议换挂或下线；④ 如需逐源归因，
  在 Demo 四类 listener 增加 VALIDATION_ONLY 的 callback info 打印。
- 未发现 SDK 缺陷；未修改 Flame 公共 API；未修改 SDK 业务源码（SDK 仓 clean，仅 pbxproj 临时重排已还原）。

## 10. Demo 变更与恢复

验证分支 `verify/p3-dual-local-1.1.0` @ `5c57859` 上未提交改动：Podfile（本地 TB :path）、Podfile.lock、
Resources/Info.plist（SKAd 119）、Sources/Ad/FlameAdConfig.swift（TB/TK 组 + activeVariant=tb）、p3logs/（证据）。
恢复原状：`git checkout verify/tk-alpha2-reward-callback && git stash pop`。
**不要误提交**：p3logs 含完整运行日志（无证书/密钥，但量大），建议仅归档不入库。

## 11. 机器字段

```
VALIDATION_DEMO = /Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo
TK_LOCAL_XCFRAMEWORK_BUILD = PASS
TB_LOCAL_XCFRAMEWORK_BUILD = PASS
DEMO_TK_LOCAL_POD_REFERENCE = [pod 'flame_sdk_ios', :path => '/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk']
DEMO_TB_LOCAL_POD_REFERENCE = [pod 'flame_sdk_ios_tb', :path => '/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk']
DEMO_TK_TB_MIXED_INSTALL = NO
DEMO_TK_DEPENDENCY_RESOLUTION = PASS
DEMO_TK_BUILD = PASS
DEMO_TK_RUNTIME_CORE = UA_6.5.84
DEMO_TK_RUNTIME_INIT = PASS
TK_FIVE_FORMAT_RUNTIME = PASS
TK_NETWORK_ACCEPTANCE_MATRIX = [GroMore:REAL_AD_PASS, TakuADX:BID_RESPONSE_PASS(PRODUCTION_OBSERVATION), Pangle:PENDING_PRODUCTION_OBSERVATION, Sigmob:PENDING_PRODUCTION_OBSERVATION, GDT:PENDING_PRODUCTION_OBSERVATION, Baidu:PENDING_PRODUCTION_OBSERVATION, KS:PENDING_PRODUCTION_OBSERVATION, MS:PENDING_PRODUCTION_OBSERVATION, ZY:PENDING_PRODUCTION_OBSERVATION, Funlink:PENDING_PRODUCTION_OBSERVATION, BeiZi:PENDING_PRODUCTION_OBSERVATION, AdGain:PENDING_PRODUCTION_OBSERVATION(compat LEVEL2 PASS), FSUnion:PENDING_PRODUCTION_OBSERVATION(compat LEVEL2 PASS)]
TK_TO_TB_SWITCH_CLEAN = YES
DEMO_TB_DEPENDENCY_RESOLUTION = PASS
DEMO_TB_BUILD = PASS
DEMO_TB_RUNTIME_CORE = 5.10.1
DEMO_TB_RUNTIME_INIT = PASS
TB_FIVE_FORMAT_RUNTIME = PASS
TB_NETWORK_ACCEPTANCE_MATRIX = [Sigmob:REAL_AD_PASS, GDT:REAL_AD_PASS, CSJ:REAL_AD_PASS, GroMore:PENDING_PRODUCTION_OBSERVATION, Baidu:PENDING_PRODUCTION_OBSERVATION, KS:PENDING_PRODUCTION_OBSERVATION, MS:PENDING_PRODUCTION_OBSERVATION, Octopus:PENDING_PRODUCTION_OBSERVATION, Mintegral:PENDING_PRODUCTION_OBSERVATION, JuTui:NEW_NETWORK_INTEGRATION/PENDING_PRODUCTION_OBSERVATION, AdScope:NEW_NETWORK_INTEGRATION/PENDING_PRODUCTION_OBSERVATION, Kuying:NEW_NETWORK_INTEGRATION/PENDING_PRODUCTION_OBSERVATION]
DEMO_SKADNETWORK_COUNT = 119
TK_ZERO_TOBID_RUNTIME = PASS
TB_ZERO_ANYTHINK_RUNTIME = PASS
PENDING_NETWORKS = [TK: Pangle, Sigmob, GDT, Baidu, KS, MS, ZY, Funlink, BeiZi, AdGain, FSUnion; TB: GroMore, Baidu, KS, MS, Octopus, Mintegral, JuTui, AdScope, Kuying]
IOS_DUAL_LINE_RUNTIME_ACCEPTANCE = PARTIAL
```
