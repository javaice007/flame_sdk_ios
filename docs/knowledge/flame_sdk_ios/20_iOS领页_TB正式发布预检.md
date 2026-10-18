# 20 · iOS 领页×TB 正式发布预检（P0F_RELEASE_PREFLIGHT）

> 阶段：2026-10-18。性质：正式发布前置审计。
> 结论速览：§2-§9 为工具链阻塞期历史（BLOCKED_BY_TOOLCHAIN，Xcode 27.1 唯一）；
> **§11 已记录 P0G 阶段在原机并存安装官方 Xcode 15.4 完成正式 DT13 构建，
> P0F_RELEASE_PREFLIGHT = PASS，TECH_RELEASE_AUDIT_CANDIDATE = READY（FORMAL_RELEASE_EXECUTED = NO）。**
> 运行时侧：P0E_RUNTIME_CLOSURE = PASS，IOS_LINGYE_TB_CUSTOMER_VARIANT = RELEASE_CANDIDATE。

## 1.【已有运行时事实】只读终审（不重跑）

| 项 | 冻结值 | 证据 |
|---|---|---|
| Git 冻结 | WORKTREE_CLEAN=YES；PREFLIGHT 时 LOCAL_HEAD==REMOTE_HEAD=9ada993（PREFLIGHT_RUNTIME_DOC_HEAD）。commit 消歧见 §7 | git fetch/status/rev-parse |
| LINGYE_REWARD_SMOKE | **PASS_REUSED_FROM_EXISTING_REAL_DEVICE_EVIDENCE** | P0D 时代 /tmp/p0d_all_rt.log 22:12 `LA_REWARDED req=f27050d0…`（csj-1，load→show→reward→close）；共存宿主 /tmp/p0d_c_CASE_B.log 22:36 `LA_REWARDED` |
| FLAME_REWARD_SMOKE | **PASS** | /tmp/p0f_caseb_newapp2.log 08:47 FA load→show→reward（transId len=36）→close，sigmob f84b138a500 @1886359231652093 |
| LINGYE_SPLASH_STANDALONE | **PASS** | 官方 Example.zip CJMobilePublic.h splashId=8a4965ae2b5f4ce6（appID 一致）；network=qm，requestId 948843a4-… |
| FLAME_SPLASH_STANDALONE | **PASS** | q76977734904→ToBid 8374774642581842→sigmob ee793f95649（8 位运行时探测唯一命中） |
| CASE_A_S/B_S、C1-C4_S | **全 PASS** | 每步真实 load→show→close；FS 一次 800110→retry→fill 属 transient no-fill |
| REINIT_S1-S4 | **全 PASS** | S3 4/4、S4 6/6（复跑）；S4 首轮 FS 800110×2 记 transient |
| FLAME_TB_CLEAR_REINIT_DEFECT | **CONFIRMED_AND_FIXED** | WindMill setup completion 进程内一次性；FlameTBProvider 幂等 init 修复（75b0135） |
| FLAME_TB_TRIGGERS_TAKU_INIT | **NO** | 保存原 IMP + C hook 探针；矩阵窗口非 IDLE Taku 调用=0 |
| LINGYE_TRIGGERED_TOBID_INIT | **NO** | WindMill manager init 仅现于 Flame 窗口 |
| FLAME_TOBID_MANAGER_OWNER | **FLAME_ONLY** | 同上 |
| FINAL_APP_CRASH_COUNT 等 5 项 | **全 0** | 终局窗口 17 份日志扫描（signal 9=harness terminate-existing，非 crash） |
| 共享网络 | SHARED_NETWORK_RUNTIME_COEXISTENCE=**PASS** | LINGYE reward→csj-1 / splash→qm；FLAME reward/splash→sigmob；OpenSSL/CSJ/GDT/KS/Baidu/MS 单副本 |

## 2.【本阶段正式构建事实】工具链审计 → STOP

```
INSTALLED_XCODE_VERSIONS = [Xcode 27.1 (27A9275, /Applications/Xcode.app)]   # mdfind+ls 唯一
IOS13_COMPATIBLE_XCODE_AVAILABLE = NO          # Xcode 27.1 支持 DT 范围 15.0–27.1.x
IOS13_FORMAL_RELEASE_BUILD      = BLOCKED_BY_TOOLCHAIN
FORMAL_BINARY_MIN_OS            = NOT_BUILT（正式 DT13 产物未构建）
FORMAL_BINARY_ARCHS             = NOT_BUILT
STANDARD_TB_FORMAL_BUILD        = NOT_RUN
STANDARD_TB_INIT_REGRESSION     = NOT_RUN
FRESH_CONSUMER_POD_INSTALL/DEVICE_BUILD = NOT_RUN
FRESH_LI/FI/LS/FS/FLAME_CLEAR_REINIT    = NOT_RUN
```

依据 §十六/§四十五.1：无兼容工具链即停止正式 artifact 步骤（不自动下载几十 GB Xcode），保留 runtime RC。

### 2.1 validation 构建上的等价审计（信息性，XCODE27_VALIDATION_BUILD=PASS，非正式产物）

> 边界冻结：以下均为 **VALIDATION_*** 变量（1.0.1-lingye.3-local / DT15 / Xcode 27.1 产物），
> **不得**给任何 FORMAL_* 变量赋最终值。FORMAL_* 必须等真正 DT13 artifact 产生后再填。

```
VALIDATION_FLAME_BINARY_TAKU_STATIC_PATH          = NO（nm 全零：ATAPI/ATAdManager/AnyThink/TopOn/AT* 均无）
VALIDATION_FLAME_TB_PATH_PRESENT                  = YES（FlameTBProvider/TbRewardAdapter/TbSplashAdapter/WindMill 符号齐备）
VALIDATION_OPENSSL_VERSION                        = 1.1.2301（runtime）
VALIDATION_CONFIG_ERROR_PROPAGATION_FIX_PRESENT   = YES
VALIDATION_EMPTY_CREDENTIAL_GUARD_PRESENT         = YES
VALIDATION_TB_REINIT_IDEMPOTENCY_FIX_PRESENT      = YES
（载体：1.0.1-lingye.3-local，DT15/minos 15.0/sdk 27.1，arm64+x86_64sim）
```

```
── FORMAL_*（未产生 DT13 artifact 前一律 NOT_BUILT / NOT_RUN）──
FORMAL_FLAME_BINARY_TAKU_STATIC_PATH = NOT_BUILT
FORMAL_FLAME_TB_PATH_PRESENT         = NOT_BUILT
FORMAL_OPENSSL_VERSION               = NOT_BUILT
FORMAL_OPENSSL_COPY_COUNT            = NOT_BUILT
FORMAL_OPENSSL_SYMBOL_COMPAT         = NOT_RUN
FORMAL_MS_BINARY_COPY_COUNT          = NOT_BUILT
FORMAL_BINARY_MIN_OS                 = NOT_BUILT
FORMAL_BINARY_ARCHS                  = NOT_BUILT
```

### 2.2 `75b0135` 专项审计（§二十）

- PRODUCT_SOURCE_CHANGE：FlameTBProvider 幂等 init —— **必须保留**，TB_REINIT_FIX_PRODUCTION_REQUIRED = YES
- VALIDATION_TOOLCHAIN_PATCH：xcFramework_build.sh tb-static 两处 DT 15.0 + Podfile post_install DT=15 + Pods 工程文件 —— 构建机适配；**不得进入正式 DT13 构建**（正式构建前须审计回退），当前无正式 artifact → XCODE27_VALIDATION_HACK_IN_RELEASE_ARTIFACT = **NO**

## 3. 版本与分发仓（§二十八/二十九）

- EXISTING_FORMAL_LINGYE_VERSIONS = **[]**（本地/远端 tag 均无 lingye 条目）
- PROPOSED_RELEASE_VERSION = **1.0.1-lingye.1**（仅建议，禁止 tag）
- DISTRIBUTION_REPO = github.com/javaice007/flame_sdk_ios（source tag 制，标准 TK/TB 同仓）
- DISTRIBUTION_VERSIONING_MODEL = 源码仓 tag 携带二进制 + javaice007/flame-specs（pod repo push）私有 specs；客户变体应**独立 tag**（1.0.1-lingye.N）+ 独立 podspec，不复用标准 TB tag

## 4. Podspec 审计（§二十七）

CUSTOMER_PODSPEC_PORTABLE = **YES**（文本层：name/module_name/DT13 正确；source 为远程 git+tag；vendored_frameworks 为仓内相对路径；无 /Users、/tmp、local_pods 绝对路径）
⚠️ 残留事项（发布期执行）：source.tag 仍指 `1.0.1-alpha.4`（旧二进制，无 P0E/P0F 修复）——**不能以该 tag 发布**；正式发布时须先推 RC tag 再翻正 podspec source。

## 5. RC artifact（§三十一）

RC_XCFRAMEWORK_PATH = NOT_BUILT（工具链 BLOCKED）
RC_XCFRAMEWORK_SHA256 = N/A；PODSPEC_SHA256 = N/A（发布期生成）

## 6. Release notes 草案（§四十一，不发布）

```
Flame iOS TB Lingye coexist variant
Compatibility: CJMobileAd 2.4.32 / iOS 13+ / Flame TB (ToBid)
Key adaptations:
- OpenSSL 1.1 compatibility（运行时 1.1.2301 验证）
- MS single-copy coexistence（Flame 不带 ToBid MSAdAdapter）
- config server error propagation + empty credential guard（P0E）
- WindMill clear/re-init idempotency（P0F-V2，75b0135）
- Taku / ToBid ownership isolation（运行时探针终证）
```

## 7. 证据包 manifest（§四十三）

```
PRODUCT_SOURCE_COMMIT = 75b0135（SDK 产品修复：FlameTBProvider 幂等 init；真正的源码修复 commit）
PREFLIGHT_BASE_HEAD   = 9ada993（Preflight 只读终审时的工作区 HEAD，docs-only 演进起点）
CURRENT_DOC_HEAD      = 见 git rev-parse HEAD（docs-only 提交会持续前移，不代表产品修复 commit）
FORMAL_RELEASE_SOURCE_HEAD = <正式 DT13 artifact 实际构建时的 commit，届时重新记录，不能提前赋值>

CUSTOMER_BRANCH = feature/ios-lingye-tobid-coexist-release
PROPOSED_VERSION = 1.0.1-lingye.1
XCODE_VERSION(正式构建) = NOT_AVAILABLE（仅 27.1 validation）
IOS_SDK_VERSION(正式构建) = NOT_AVAILABLE
DEPLOYMENT_TARGET(正式构建) = 13.0（契约，未构建验证）
RC_SHA256 = N/A（NOT_BUILT）
FRESH_CONSUMER_RESULT = NOT_RUN（工具链阻塞）
RUNTIME_RESULT = 全绿（见 §1）
Taku isolation = NO_TRIGGER；ToBid ownership = FLAME_ONLY；OpenSSL = 1.1 单副本（runtime）；MS = 单副本设计+runtime 无冲突；clear-reinit = FIXED & PASS
```

## 8. Gate 判定

```
P0E_RUNTIME_CLOSURE            = PASS
IOS_LINGYE_TB_CUSTOMER_VARIANT = RELEASE_CANDIDATE（≠ RELEASED）
IOS13_COMPATIBLE_XCODE_AVAILABLE = NO
P0F_RELEASE_PREFLIGHT          = BLOCKED（STOP 条件 #1：BLOCKED_BY_TOOLCHAIN）
TECH_RELEASE_AUDIT_CANDIDATE   = NOT_READY
FORMAL_RELEASE_EXECUTED        = NO
```

## 9. 解除阻塞路径（供决策层）

1. IOS13_TOOLCHAIN_REQUIREMENT：找到一个**经过实际构建验证**能够以
   `IPHONEOS_DEPLOYMENT_TARGET = 13.0` 成功完成当前 Flame iOS device build/archive 的
   Xcode toolchain（机器/版本由决策层指定，不按 Xcode 大版本号猜测）。
   解除阻塞时必须实际验证：`xcodebuild -version` → 以 `IPHONEOS_DEPLOYMENT_TARGET=13.0`
   完成 device archive/build → `FORMAL_BINARY_MIN_OS = 13.0`（otool/vtool 实测）。
   不能仅凭版本号判断；§十七四类伪造做法全部禁止。
2. 或决策层显式豁免 DT13 契约（产品决策，非本阶段权限）

## 9.1 canonical 回灌冻结（§三十九/四十细化）

```
STANDARD_TB_WINDMILL_REINIT_BACKPORT_REQUIRED = YES_AFTER_CUSTOMER_RELEASE
  依据：clear→re-init 缺陷根因位于 FlameTBProvider / WindMill 通用 TB 生命周期，
  不是 CJMobileAd / Lingye 特有兼容问题。领页客户正式发布闭环后，必须回到
  release/ios-dual-line 单独实施并验证（Flame clear → Flame init → Splash/Reward
  load/show）。不得在当前客户发布阶段提前 merge。
CONFIG_MANAGER_HARDENING_BACKPORT = SEPARATE_DECISION_RECOMMENDED
  对应：server code/message propagation + empty appId/appKey defensive guard
  （通用健壮性修复，回灌 canonical 仍需单独审计）。
LINGYE_CUSTOM_DEPENDENCY_BACKPORT = NO
  禁止回灌：OpenSSL ~>1.1、remove ToBid MSAdAdapter、flame_sdk_ios_tb_lingye、
  CJMobileAd dependency closure、任何领页客户专用配置。
```

## 10.【尚未发布】/【发布后待验】

- 尚未发布：正式 tag、分发仓推送、flame-specs、pod repo push——全部等待双重审批（TECH_RELEASE_AUDIT=PASS + USER_FINAL_RELEASE_APPROVAL=YES）
- 发布后待验：客户生产环境 fresh 接入回归、线上数据回报


## 11.【本阶段正式构建事实】P0G DT13 工具链解除与正式构建（2026-10-18）

### 11.1 工具链（原机并存，零 hack）

- 官方渠道下载 Xcode_15.4.xip（Apple Developer 登录下载，3.19GB），`xip` 工具签名校验解压，
  并存安装 `/Applications/Xcode_15.4.app`（CFBundleShortVersionString=15.4，Build 22622）；
  Xcode 27.1 保留、全局 xcode-select 未动、未修改任何兼容性文件
- `XCODE15_ON_MACOS26_XCODEBUILD_STARTS = YES`（macOS 26.6.2 宿主实测，仅 objc 重复类告警噪音）
- `XCODE15_IOS_SDK = iphoneos17.5`
- **SEPARATE_BUILD_MACHINE_REQUIRED = NO**（原机方案成立，Sonoma VM/第二台 Mac 不需要）

### 11.2 DT13 Gate（§六/§七）

- 真实 build system 探测（SwiftPM + xcodebuild，非 clang 单测）：DT=13.0 接受，
  产物实测 `platform=IOS minos=13.0 sdk=17.5` → `XCODE15_DT13_BUILD_SYSTEM_ACCEPTED = YES`
- iOS 平台层经 `xcodebuild -downloadPlatform iOS` 安装（17.5）

### 11.3 正式构建（worktree @f320e9b + classic 生成工程）

- 隔离：git worktree `/tmp/flame_ios_lingye_release_build` @ `f320e9b`（FORMAL_RELEASE_SOURCE_HEAD）；
  validation DT15 patch 已参数化隔离（`FLAME_DEPLOYMENT_TARGET`，默认=产品契约 13.0；f320e9b），
  正式构建未设该变量；v77 工程经 `release-tooling/gen_classic_xcodeproj.py` 生成 classic v56 副本
- Standard TB / Lingye Customer TB 同源产物：`build/tb-static/flame_sdk_ios.xcframework` 构建成功
- **FORMAL_BINARY_MIN_OS = 13.0**（LC_BUILD_VERSION: platform=IOS, minos=13.0, sdk=17.5）；
  FORMAL_BINARY_ARCHS = [arm64]（device）+ x86_64（simulator）
- **CONFIG_ERROR_PROPAGATION_FIX_PRESENT = YES / EMPTY_CREDENTIAL_GUARD_PRESENT = YES /
  TB_REINIT_IDEMPOTENCY_FIX_PRESENT = YES**（strings 实测正式产物）
- **FORMAL_FLAME_BINARY_TAKU_STATIC_PATH = NO**（nm 全零）；
  **FORMAL_FLAME_TB_PATH_PRESENT = YES**（FlameTBProvider/Tb*/WindMill 符号齐备）
- `XCODE27_VALIDATION_HACK_IN_RELEASE_ARTIFACT = NO`

### 11.4 RC artifact（staging，未发布）

- RC_XCFRAMEWORK = `rc_staging/flame_sdk_ios_tb_lingye/1.0.1-lingye.1/tb/flame_sdk_ios.xcframework`
- RC_XCFRAMEWORK_SHA256(tb/) = `f196289e71959e5c542b7722aa35bb6a336f1fae260a49c9f176b6e9ef2dbea2`
- candidate podspec：s.version=1.0.1-lingye.1，source.tag=1.0.1-lingye.1（**tag 尚未创建**，发布期执行）
- PODSPEC_SHA256(customer) = `219b7009095d1ed33ae213729f6bbc44c4655f2b71c1d6e1a63214deafe3ffc9`
- CUSTOMER_PODSPEC_PORTABLE = YES（无本地路径；发布期仅需创建对应 tag）

### 11.5 Fresh Consumer（全新工程，无 validation 复用）

- FRESH_CONSUMER_POD_INSTALL = **PASS**（28 pods；CJMobileAd 2.4.32；OpenSSL 1.1.2301 单副本；
  GDT/KS/Baidu/MS/Mintegral 单副本；Flame 无 MSAdAdapter；AnyThink 来自客户闭包）
- FRESH_CONSUMER_DEVICE_BUILD = **PASS**（Xcode 15.4 / DT=13.0 / arm64；
  WindMill Swift 适配器老 autolink 经 8 符号 marker 垫片满足，运行时由 OS dylib 提供）
- App 二进制 minos = **13.0**；未定义符号=0（链接期）
- 真机 sanity（iOS 27 真机，DT13 产物）：**FRESH_LI/FI/LS/FS/FCLR+FI+FS = 全 PASS
  （SEQ_DONE ALL_OK）**；LS network=qm requestId=bc4244a8-…；FS 真实填充
- clear→re-init（幂等修复）在正式产物上验证 PASS
- FRESH_LINGYE_REWARD / FRESH_FLAME_REWARD = REUSED_EXISTING_RUNTIME_EVIDENCE
- crash/exception 扫描 = 0（仅 harness signal 9）

### 11.6 Standard TB 回归（§三十二/三十三）

- STANDARD_TB_FORMAL_BUILD = **PASS**（同一 DT13 tb-static 产物 + standard candidate podspec）
- STANDARD_TB_INIT_REGRESSION = **PASS**（独立 fresh host 真机 FI 0.6s PASS）
- 回灌冻结不变：STANDARD_TB_WINDMILL_REINIT_BACKPORT_REQUIRED = YES_AFTER_CUSTOMER_RELEASE

### 11.7 终局 Gate（§四十六）

```
P0F_RELEASE_PREFLIGHT       = PASS
TECH_RELEASE_AUDIT_CANDIDATE = READY
FORMAL_RELEASE_EXECUTED     = NO
```

等待双重审批：TECH_RELEASE_AUDIT = PASS（决策层）+ USER_FINAL_RELEASE_APPROVAL = YES（产品负责人）。
