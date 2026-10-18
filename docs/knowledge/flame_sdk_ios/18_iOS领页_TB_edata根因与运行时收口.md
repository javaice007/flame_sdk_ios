# 18 · iOS 领页 × Flame TB — edata 根因与运行时收口（P0E）

> 日期：2026-10-17/18 深夜
> 研究分支：`research/ios-lingye-edata-rootcause`（基 = 客户分支 46663e7）
> **结论速览：edata-missing 根因定案 = 测试驱动 env 注入缺陷 + SDK 错误传播缺陷的组合；
> 共存本身无网络层缺陷（FI 修复版 11/11 场景全 PASS）。最小正式修复（错误传播 + 入参防御）
> 已完成并重编产物验证。P0D 的"共存特有阻断"结论被推翻。唯一遗留 = Flame Reward 平台 no-fill
> （waterfall 待后台核对，疑与去 MS 相关）。**

## 1. §5 网络实现权威摘要（源码直读）

```
INIT_NETWORK_IMPLEMENTATION = FlameNetworkUtils doPostJson → [NSURLSession sharedSession]
INIT_REQUEST_ENCODING = JSON body {appId, version, timestamp, sign}（sign=MD5 排序拼接+&key=）
INIT_CONTENT_TYPE = application/json（Accept 同）
INIT_SESSION_TYPE = NSURLSession sharedSession（共享缓存/Cookie；无自定义 configuration）
INIT_RESPONSE_PARSE_PATH = dict → data → data.edata；FlameConfigManager.m:262 触发 "edata is missing"
SDK_PRESERVES_SERVER_ERROR_CODE/MESSAGE = NO → ERROR_PROPAGATION_DEFECT = CONFIRMED（修复前）
```

## 2. §8-13 四级探针证据（B/C 完全同代码探针，具体类 C-IMP 替换 __NSURLSessionLocal）

| 维度 | Host B（独立） | Host C（共存，坏例） | Host C（合并 env，好例） |
|---|---|---|---|
| body | `{"appId":"…","sign":"…","timestamp":…,"version":"…"}` len=118 | **`{"version":"…","timestamp":…}` len=53（appId+sign 丢失）** | len=118 完整 |
| 服务端 | 200 `{"code":200,…,"edata":"BDo1…"}` | 200 `{"code":400,"message":"缺少必需参数：appId","data":{}}` | 200 code=200 + edata |
| SDK 表现 | FI=1 | FI=0 "edata is missing" | **FI=1** |

**§16 隔离实验**：C0（纯链接不调 CJ）即可复现坏例、合并 env 后 C0 直接过 → 与 CJ 初始化/广告完全无关。

## 3. 根因分类（§13）

```
EDATA_ROOT_CAUSE_CLASS = SDK_RESPONSE_PARSE_BUG（叠加验证驱动缺陷）
链路：devicectl 多个 -e 后者覆盖前者 → 宿主 env P0D_FAPPID/KEY 丢失 → appId/appKey=nil
  → dictionary 下标赋 nil 键被静默丢弃（body 缺 appId/sign）→ 服务端正确回 400 参数缺失
  → SDK parser 不读 code/message → 业务错误伪装成 "edata is missing"
EDATA_MISSING_IS_COEXIST_SPECIFIC = NO（推翻 P0D 结论）
CJ_NETWORK_INTERFERENCE = NOT_GUILTY（C0/C1/C2/C3 全通；REQUEST_HEADER_DIFF=[]、无 Cookie/UA 污染）
REQUEST_MUTATED_BEFORE_SEND = NO（mutate 发生在参数构建层，非网络层）
HOST_B/C bundle id 相同（com.flame.sdk.test），无 bundle 混淆因素
```

## 4. 最小正式修复（Flame network/config 层，客户分支 Commit C）

`flame_sdk_ios/core/FlameConfigManager.m` 两处：
1. **错误传播**：parser 优先读 `code/success`——业务失败时原样返回服务端 `code/message`
   （"edata is missing" 仅在 code=200 且 data 存在而 edata 缺失时出现）。
2. **入参防御**：`appId/appKey` 为空 → 立即 `fail:14005`（不再静默发残缺请求）。

修复产物：tb-static 重编（验证口径 DT=15；AT 污染=0、TB 胶水齐全）→ 本地 pod
`1.0.1-lingye.2-local`。**FLAME_CORE_BINARY_CHANGED 由 NO 变为 YES（源码级）**：
正式发布需决策层重打分发仓 tag + iOS13 工具链复建（P0F）。

## 5. 修复后终局回归（真机，合并 env）

```
COEXIST_INIT_FIXED = PASS：FI 11/11 场景 PASS
  （C0 裸链接 / CJLOG 后 / LI 后 / LI+LA 后 / CASE_A / CASE_B / C4 /
   REINIT_FI: FI→FI 双成功 / REINIT_MIX1: LI→FI→LI / REINIT_MIX2: FI→LI→FI）
EDATA_FIX_REPEAT_COUNT/PASS_COUNT = 11/11（≥5/5 门槛）
LINGYE（共存中）：LI 恒 OK、LA 恒 OK（含激励 show/reward/close 全链，channel=csj 共享单副本）
LINGYE_REINIT_SAFE = YES（LI×2）；FLAME_CLEAR_REINIT_SAFE = YES（成功态 FI×2 直接成功；
  失败态 14000 保护符合契约）
APP_CRASH/FATAL/DYLD/DUPLICATE_CLASS = 0/0/0/0（全轮日志）
FLAME_TB_TRIGGERS_TAKU_INIT = 行为级 NO（Flame init 前后领页广告全链不受影响；
  swizzle 级终证未完成——ATAPI/WindMillAds 探针在 didFinishLaunching 时仍未挂上目标 selector
  （私有类时序），probe v2 留 P0F；静态零路径结论维持）
LINGYE_TRIGGERED_TOBID_INIT = 行为级 NO（探针 0 触发但探针自身未挂上，同上保留）
STANDARD_TB_INIT_REGRESSION = PASS（标准 TB host 与客户变体共用同一网络层修复；
  修复对成功路径零改动——仅在业务失败分支改变错误文案）
CUSTOM_TB_RUNTIME_INIT = PASS（独立+共存双证）
CUSTOM_TB_REWARD_COMPLETE = FAIL（800110 no-fill 恒定，平台侧——见 §6）
CASE_A/CASE_B/C1-C4 = FAIL（全部因 FA no-fill 传导；除 FA 外所有步骤 OK）
```

设备锁屏导致 Baseline A/B 独立复验未跑（等效证据：共存矩阵中 LA 全链 OK×8、FI 11/11；
解锁后可按仓内 runner 补跑）。

## 6. Reward no-fill（唯一遗留，平台侧）

```
FLAME_TB_TEST_PLACEMENT_HAS_MS = UNKNOWN（需 Flame 后台核对 q96839761612 waterfall；
  客户变体已去 MSAdAdapter——若 waterfall 只配/优先配 MS 即无填充）
FLAME_TB_TEST_PLACEMENT_HAS_NON_MS_ACTIVE_SOURCE = UNKNOWN
FLAME_TB_MS_NETWORK_REQUIRED_FOR_CUSTOMER = UNKNOWN → CUSTOMER_TB_NETWORK_PROFILE_EXCLUDES_MS = NOT_REQUIRED
处置：Flame 平台内部为该客户 placement 配置非 MS 源（允许，非客户操作）；
若 MS 必需 → 另开 ToBid 新版 MS adapter × MSMobAdSDKv3 专项（禁止偷偷恢复旧 MSMobAdSDK）
```

## 7. 判定

```
P0E_RUNTIME_CLOSURE = PARTIAL_PASS
  已收口：edata 根因（非共存缺陷）+ SDK 双修复 + 共存 init 11/11 + 领页全链 + reinit + 零异常
  未收口：Flame Reward 真实广告链（平台 no-fill，待后台配置）→ Case 矩阵按真实广告标准判 FAIL
IOS_LINGYE_TB_CUSTOMER_VARIANT = RELEASE_CANDIDATE（P0E_RUNTIME_CLOSURE=PASS，2026-10-18 P0F-V2 终局收口；
  正式发布构建另受工具链门禁约束，见 20 号文档 P0F_RELEASE_PREFLIGHT=BLOCKED_BY_TOOLCHAIN）
RELEASE_GATE 剩余输入：
  1) Flame 后台为测试 placement 配置非 MS 源 → 重跑 FA 链与 Case 矩阵
  2) P0F：DT13 工具链复建产物、分发仓 tag 1.0.1-lingye.1、flame-specs（均待决策层批准）
```

## 8. 复现资产（本分支）

- `P0DNetProbe.{h,m}`：NSURLSession 具体类 C-IMP 探针（B/C 同代码，请求/响应全记录）
- C0/CJLOG/C2 隔离序列 + 合并 env runner 修正（**devicectl 多 -e 会覆盖——须合并单 JSON**）
- 修复版本地 pod：`validation/.../local_pods/flame_sdk_ios_tb_lingye-fixed`（产物 gitignored）
- 关键日志：/tmp/p0e_*.log、/tmp/p0f_*.log（证据摘要见 §2/§5；AppKey 未入任何提交）

## 9. 人工 Demo 验收工作台（P0F 后续，2026-10-18）

- 遗留 FA no-fill 已由新测试 App（b22375234108 / q57514498879 → ToBid 1886359231652093，Sigmob 单源）真实填充闭环：load→show→reward（transId 36 位）→close 全链 PASS；旧 App no-fill 根因盖棺=旧瀑布流源自身问题（GDT/KS/Baidu 包名+CSJ 代码位），与 MSAdAdapter 移除/SDK/共存无关
- 验收工作台见 **19 号文档**：MANUAL_DEMO_IMPLEMENTED=YES / BUILD=PASS；INSTALL/LAUNCH 待真机解锁

## 10. P0F-V2 终局：Splash 主矩阵 + clear→re-init 缺陷修复（2026-10-18）

- 测试配置切换：Flame 新 App `b22375234108`（Reward q57514498879→ToBid 1886359231652093→sigmob f84b138a500；Splash q76977734904→ToBid 8374774642581842→sigmob ee793f95649，开屏位经 8 位运行时探测唯一命中）。旧 App b58225548566 的 no-fill 定性 TEST_CONFIG_SPECIFIC，FLAME_SDK_REWARD_CAPABILITY=PROVEN
- 领页开屏位：自官方 Example.zip `CJMobilePublic.h` 恢复 `splashId=8a4965ae2b5f4ce6`（appID 96ff49947661db62 与现用一致），LS standalone PASS（network=qm，requestId 948843a4-…）
- Splash 主矩阵全绿：CASE_A_S 6/6、CASE_B_S 6/6、C1/C2_S 4/4、C3/C4_S 6/6；REINIT_S1 3/3、S2 3/3、S3 4/4、S4 6/6（S4 首轮 FS 两次 800110 瞬时 no-fill，复跑全绿）
- **新 SDK 缺陷闭环（REINIT 首次被矩阵覆盖即命中）**：`[FlameSdk clear]`→re-init 永久挂死。根因=WindMill `setupSDKWithAppId:completionHandler:` 进程内一次性，二次 setup 不回调。最小修复=FlameTBProvider 幂等 init（进程内 setup 完成后直接 success；失败保持可重试）。修复后 S3/S4 全绿。提交 75b0135（feature/ios-lingye-tobid-coexist-release）
- 探针终证（保存原 IMP + C hook，观测不改行为）：Taku 三入口（handleAppLaunch/tryCheckADXConfigIfNeeded/ATAdManager sharedManager）在全部矩阵窗口零调用（仅启动期 AnyThink +load 自init，action=IDLE）→ FLAME_TB_TRIGGERS_TAKU_INIT=NO；WindMill 管理器 init 全部落在 Flame 加载窗口 → LINGYE_TRIGGERED_TOBID_INIT=NO、FLAME_TOBID_MANAGER_OWNER=FLAME_ONLY
- 异常扫描（探针修复后终局窗口 17 份日志）：crash/EXC/NSException/unrecognized selector/dyld/duplicate class = 0（仅存 signal 9 = harness terminate-existing 正常行为）
- 共享网络归属表：LINGYE reward→csj-1｜LINGYE splash→qm｜FLAME reward→sigmob(f84b138a500)｜FLAME splash→sigmob(ee793f95649)——同 App 双方各走各源，互不污染
- 遗留：LINGYE_REWARD_SMOKE 需一次完整看完视频（已两次被提前关闭）；FLAME_REWARD_SMOKE=PASS（既有 08:47 全链证据）

## 11. P0E_RUNTIME_CLOSURE 正式收口（P0F Release Preflight 只读终审，2026-10-18）

- 依据 20 号文档 §1 只读终审（不重跑）：runtime 全部 Gate 满足 → **P0E_RUNTIME_CLOSURE = PASS**
- LINGYE_REWARD_SMOKE = PASS_REUSED_FROM_EXISTING_REAL_DEVICE_EVIDENCE（P0D /tmp/p0d_all_rt.log LA_REWARDED req=f27050d0… + 共存宿主 p0d_c_CASE_B LA_REWARDED）
- 正式 iOS13 构建 = BLOCKED_BY_TOOLCHAIN（本机唯一 Xcode 27.1，min DT 15.0）；不改变 runtime RC 状态
