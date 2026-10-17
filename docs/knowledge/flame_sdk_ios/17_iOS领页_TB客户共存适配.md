# 17 · iOS 领页 × Flame TB 客户共存适配（P0D）

> 日期：2026-10-17（夜间真机验证）
> 分支：`feature/ios-lingye-tobid-coexist-release`（基 = canonical c1b1c04，merge-base 已验证）
> 真机：康海军的 iPhone（iPhone17,1），签名 com.flame.sdk.test（本机既有含设备描述文件）
> 结论速览：**客户变体（flame_sdk_ios_tb_lingye）构建门禁全 PASS；领页独立基线全链 PASS（含发奖）；
> OpenSSL 1.1 运行时 init 实证 PASS；共存环境发现一个真实阻断：Flame init 在共存 App 中稳定
> `edata is missing`（独立 App 同凭证同时刻成功——共存特有）→ 技术验收 = BLOCKED（发现即价值，
> 未伪造任何 PASS）**。

## 1. 产品契约（冻结执行）

```
CUSTOMER_LINGYE_SDK = CJMobileAd 2.4.32（不升级、不换版本、不改依赖、不改初始化与业务代码）
LINGYE_CUSTOMER_FLAME_LINE = TB（FLAME_TK_IN_CUSTOMER_VARIANT = FORBIDDEN）
ADAPTATION_OWNER = FLAME_SDK
CUSTOMER_SIDE_CODE_CHANGE = NO
CUSTOMER_INIT_ORDER_REQUIREMENT = NONE
```

## 2. 客户变体实现（Commit A）

新增 `flame_sdk_ios_tb_lingye.podspec`（版本 1.0.1-lingye.1-local，正式候选 1.0.1-lingye.1）：

```
CUSTOMER_POD_NAME = flame_sdk_ios_tb_lingye
CUSTOMER_VARIANT_MODULE = flame_sdk_ios（import/公共 API/初始化契约零变化）
FLAME_CORE_BINARY_CHANGED = NO（vendored tb/ 产物 = 标准 TB 1.0.1-alpha.4 同一冻结二进制；
  正式发布时由决策层在分发仓打 1.0.1-lingye.1 tag 并翻 source）
CUSTOM_VARIANT_OPENSSL_CONSTRAINT = ~> 1.1（P0C：Flame 面仅 12 个高层 EVP 符号，1.1 全导出，链/运行时均证）
FLAME_TOBID_MS_ADAPTER_INCLUDED = NO（P0C：MSMobAdSDKv3 × MSMobAdSDK 同名 xcframework 冲突 CONFIRMED；
  LINGYE_MS_OWNER = CUSTOMER_EXISTING_SDK）
ToBid adapters = CSJ/GDT/Baidu/KS/Mintegral/Octopus/Gromore（7 个，无 MS）
红线复核：AnyThink/TK adapter/AdGain/FSUnion/独立 Sigmob = 全部 absent（Podfile.lock + 二进制 nm 双证）
REMOTE_LINGYE_VERSION_EXISTS = NO（本仓 tag / flame-specs / 分发仓三处核查）
STANDARD_TK_CHANGED = NO；STANDARD_TB_BEHAVIOR_CHANGED = NO（正式产品文件 vs canonical diff = 0 行）
CUSTOM_VARIANT_ISOLATED = YES
```

CJMobileToBidAdapter 未接入（§15 冻结：保持领页与 Flame 双 manager 独立）。

## 3. 三正式验证 host 与构建门禁（全 PASS）

```
A. LingyeStandalone（领页 2.4.32 + link-complete 客户环境，不接 Flame）
B. FlameTBLingyeStandalone（只接 flame_sdk_ios_tb_lingye）
C. LingyeFlameTBCoexist（A 闭包 + flame_sdk_ios_tb_lingye）

LINGYE_STANDALONE_POD_INSTALL/DEVICE_BUILD = PASS/PASS（undefined/duplicate = 0）
CUSTOM_TB_POD_INSTALL/DEVICE_BUILD = PASS/PASS（OpenSSL resolved = 1.1.2301；MS/AnyThink absent；
  TB 二进制 0 AT 污染、FlameTBProvider 胶水齐全）
CUSTOM_COEXIST_POD_INSTALL/DEVICE_BUILD = PASS/PASS（此前 P0C 主口径的 MS 冲突已由变体消除）

单副本计数（§23 实测）：OpenSSL=1（1.1.2301）、CSJ=1（Ads-CN/BUAdSDK 7.6.0.4）、GDT=1（4.15.90）、
KS=1（5.4.10.1）、Baidu=1（10.050）、MS=1（客户 MSMobAdSDKv3 3.0.10.2）
ACTUAL_DUPLICATE_FRAMEWORKS/SYMBOLS/OBJC_CLASSES = []；ACTUAL_UNDEFINED_SYMBOLS = []
```

运行期补齐（用户真机反馈驱动）：**酷鹰 ADX 组件缺失告警**（CJ 弹窗"AnyThink Adx SDK 重要组件缺失，
Taku ADX 业务无法正常运行"）→ 补 `AnyThinkMediationAdxSmartdigimktCNAdapter 6.5.63.2.0`
（厂商 2.4.32 注释 pin = 2.4.33.10 活动 pin，双证据）至 Host A/C → 重装后告警消失（截图前后对照）。
**教训入档：领页完整闭包 = P0C 清单 + ADX 适配器**（正式客户文档/后端 onboarding 需含此项）。

## 4. 真机 Runtime 结果

### Baseline A：领页独立 —— **全链 PASS**

```
LI_RESULT=1 → LA_LOAD_OK(channel=csj-1) → SHOW → LA_REWARDED(req=26be0b2d…) → LA_CLOSED
SEQ_RESULT BASELINE_A PASS(load-show-reward/close)
cj-log 网络版本自证：csj 7.6.0.4 / gdt 4.15.90 / qm 1.6.0 / zf 1.10.10.1 / wm 7.9.4.36 …
（激励填充走 csj——即 Flame 同代单副本 CSJ 在为领页供数：共享网络单副本运行时佐证）
LINGYE_RUNTIME_INIT/LOAD/SHOW/COMPLETE_CHAIN = PASS
```

### Baseline B：Flame 客户变体独立 —— init PASS，Reward no-fill

```
FI_RESULT=1 → OPENSSL_1_1_RUNTIME_INIT=OK（配置拉取 + AES-GCM 解密(OpenSSL 1.1.2301) + ToBid init）
FA_LOAD ×4 = 800110 无广告返回（请求到达平台、平台正式响应无填充——平台侧问题，非 SDK 链路故障）
CUSTOM_TB_RUNTIME_INIT = PASS；CUSTOM_TB_REWARD_COMPLETE = FAIL(no-fill 800110)
OPENSSL_1_1_RUNTIME_COMPAT = PASS（init/解密链实证；Reward 展示因平台 no-fill 未覆盖）
```

### Coexist（Host C）—— **发现共存特有阻断**

```
LI/LA 在共存 App 中 OK（多序列复现，含 LI×2 重复初始化）
FI = FAIL 稳定复现：code=-1 "edata is missing from server response"
  交叉验证：同设备/同凭证/同时刻 Host B（独立 App）FI=1 成功 → 共存环境特有
  （怀疑方向：CJ/JY/HX 栈对 Flame /sdk/init 请求路径的全局干扰——网络层 hook/头改写致服务端不下发 edata；
   精确根因需抓包级实验，本轮未做）
二次 FI = 14000（Flame 契约保护：失败后须 clear 再试——非 crash，符合已知语义）
CASE_A/CASE_B/C1：LI/LA 步 OK、FI/FA 步 FAIL（edata 阻断传导）→ 判 FAIL（如实）
C2-C4：未单独重跑（阻断已由 CASE_A/B/C1+REINIT 系列充分表征）
LINGYE_REINIT_SAFE = YES（LI×2 无 crash、状态正常）
FLAME_TB_REINIT_SAFE = N/A（首次 init 即败，14000 保护符合契约）
```

### Taku 探针（§31）

```
AnyThink 6.5.60 的 ATAPI 类方法表（运行时 dump，19 个）：无 startWithAppID:* —— 该版本为
+load 自动初始化模式（load/handleAppLaunch/tryCheckADXConfigIfNeeded 一族；头文件与二进制不同步）。
→ swizzle 探针未挂上目标 selector，FLAME_TB_TRIGGERED_ANYTHINK_INIT 运行时判定未成立。
FLAME_TB_HAS_TAKU_STATIC_PATH = NO（静态：零依赖+零符号，15 号文档口径维持）
FLAME_TB_TRIGGERS_TAKU_INIT = UNPROVEN_RUNTIME（下轮改挂 load/handleAppLaunch/ATAdManager 再证）
LINGYE_TRIGGERED_TOBID_INIT = 观察中未见 WindMill setup（探针已挂但 0 触发）→ NO（初证）
FLAME_TOBID_MANAGER_OWNER = FLAME_ONLY（待 FI 修复后终证）
```

### 异常扫描（§40）

```
全部 runtime 日志（3,860 行）：EXC_BAD_ACCESS=0、NSInvalidArgumentException=0、
NSInternalInconsistencyException=0、dyld error=0、unrecognized selector=0、
duplicate-class runtime warning=0、crash=0
```

## 5. MS 网络运营约束（§38/39）

```
FLAME_TB_MS_NETWORK_REQUIRED_FOR_CUSTOMER = UNKNOWN
  （Reward no-fill 800110 无法排除"waterfall 含 MS 档位"因素——需 Flame 后台核对 q96839761612 的投放配置；
    若 YES：去 MS adapter 方案需重评估（ToBid 新版 MS adapter × MSMobAdSDKv3 兼容性另研））
CUSTOMER_TB_NETWORK_PROFILE_EXCLUDES_MS = NOT_REQUIRED（待后台核对后定；为 Flame 平台内部配置，不需客户操作）
```

## 6. 判定（§46）

```
P0D_CUSTOMER_VARIANT_BUILD = PASS（三 host 构建门禁 + 单副本 + 零 duplicate/undefined）
P0D_RUNTIME_ACCEPTANCE = BLOCKED
  阻断点：共存环境 Flame init edata-missing（真实共存缺陷，待定位修复后重跑矩阵）
IOS_LINGYE_TB_CUSTOMER_VARIANT = NOT_RELEASE_READY
已证可用性：客户侧零改动成立（领页环境原样 + 换 Flame 依赖行）；
  领页在共存中不受 Flame 影响（LI/LA 恒 OK）；OpenSSL 1.1 运行时链实证 PASS。
```

## 7. 下一步建议（P0E 输入，均需决策层审批）

1. **定位 edata-missing**：在 Host C 抓包/ NSURLSession 钩子对比 Flame /sdk/init 请求（头/UA/cookie/DNS）在独立 vs 共存环境的差异；重点排查 CJ/JY/HX 的全局网络 hook 与共享 NSURLCache。
2. Flame 后台核对 TB 测试位 waterfall 是否含 MS（§38）。
3. Taku 探针 v2：挂 ATAPI load/handleAppLaunch + ATAdManager 初始化面。
4. 正式发布路径（全部前置满足后）：分发仓打 1.0.1-lingye.1 tag → 翻 podspec source → iOS13 工具链复建 → flame-specs 推送（本轮全部禁止项未触碰）。
