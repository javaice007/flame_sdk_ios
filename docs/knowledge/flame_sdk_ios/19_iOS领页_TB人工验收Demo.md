# 19 · iOS 领页×TB 人工验收 Demo 工作台（P0F MANUAL DEMO）

> 目标：产品负责人无需黑屏/自动脚本，拿起真机通过页面按钮独立完成领页×Flame 共存验收。
> 冻结：`MANUAL_DEMO_ACCEPTANCE_REQUIRED = YES`；`BLACK_SCREEN_AUTORUN_ONLY = NOT_ACCEPTABLE`；
> `AUTOMATED_RUNNER_REPLACES_MANUAL_ACCEPTANCE = NO`。
> 阶段：2026-10-18（P0F，承接 17/18 号文档）。

## 1. 基线与冻结（不变）

- 客户：CJMobileAd **2.4.32**（`CUSTOMER_SIDE_CODE_CHANGE = NO`）
- Flame：`flame_sdk_ios_tb_lingye`（TB/ToBid only，1.0.1-lingye.2-local 修复版二进制）
- 禁止：为 Demo 改客户版本/依赖/正式广告逻辑；回退 TK

## 2. 实现载体（validation host：LingyeFlameTBCoexist）

| 文件 | 职责 |
|---|---|
| `Sources/P0FTestCore.{h,m}` | 统一控制层：`LingyeTestController` / `FlameTestController` / `P0FAdEvent` / `P0FLogTap`。**人工与自动唯一 SDK 调用路径**（`MANUAL_AND_AUTO_SHARE_SAME_CODE_PATH = YES`） |
| `Sources/P0FConsoleViewController.{h,m}` | Coexist Test Console（四区域 UI，程序化布局） |
| `Sources/AppDelegate.m` | 默认 MANUAL_MODE；`env P0D_SEQ` 或 `--auto-sequence <SEQ>` 才进自动 runner；[P0D-C] 历史标记保留 |
| `Sources/P0FSecretConfig.h(.example)` | 本地凭证（**gitignored，不入 Git**）；AppKey 永不展示/不复制 |
| `Sources/P0DNetProbe.{h,m}` / P0DProbe | 保留（只读探针，自动+人工共用） |

## 3. 页面结构（§3/§4/§13/§16）

- **A 当前配置**：双 SDK 版本、Flame AppID、Reward/Splash Placement、Resolved ToBid AppID/Placement/NetworkPlacement（runtime 实时）、设备信息。AppKey 只显示 `••••••（已配置，不展示）`
- **LAST ACTION 卡**：OWNER / TYPE / RESULT / MEDIATION / NETWORK / PLACEMENT / LOAD·SHOW·REWARD·CLOSE / TRANS_ID·REQUEST_ID / TIME（截图留证）
- **B 领页区**：初始化 / 加载开屏 / 展示开屏 / 加载激励 / 展示激励 / 清理重置
- **C Flame 区**：初始化 / 加载开屏 / 展示开屏 / 加载激励 / 展示激励 / Flame Clear
- **快捷 Case A/B**（领页先 / Flame 先）与 **管理**（清空日志 / 重置测试状态 / 复制日志——复制已脱敏）
- **D 日志面板**：黑底滚动，`HH:mm:ss [OWNER-KIND] ACTION PASS/FAIL network=... code=...`
- 状态 badge：SDK 四态 `NOT_INITIALIZED/INITIALIZING/READY/ERROR`；广告 `IDLE/LOADING/READY/SHOWING/REWARDED/CLOSED/ERROR/TIMEOUT`（§14：load 期间页面持续可见，超时显示 TIMEOUT，45s 激励/20s Flame 开屏/30s 其余看门狗）

## 4. 归因与真实 runtime identity（§5/§6/§21）

- 领页：`OWNER=LINGYE`，network=`getAdType`（如 csj-1），requestId 发奖回调实参
- Flame：`OWNER=FLAME`，`MEDIATION=TOBID`，network / ToBid placement / network placement 全部来自 **本轮 runtime**：
  - `P0FLogTap`（dup2+pipe 旁路捕获 stdout/stderr，原样回写原 fd）解析 ToBid `[onReport] AdDidShow/AdDidReady` JSON（networkName/networkId→名称映射 22=csj 16=gdt 19=ks 21=baidu 9=sigmob、placementId、networkPlacementId）与 P0D 探针 `TOBID_INIT_CALLED appId=`
  - transId 来自 `FlameRewardListener onAdReward:...transId:` 实参
  - **拿不到显示 N/A，禁止伪造；不硬编码 Sigmob PASS**（800110 → NO_FILL 原样显示）

## 5. 开屏支持核实（§10/§11）

- `LINGYE_SPLASH_SUPPORTED = YES`（`CJSplashAd`：initWithResourceId:rootViewController:customLogoView: + loadAdData + showSplashAdToWindow:，load/show 可分离）
- `FLAME_TB_SPLASH_SUPPORTED = YES`（`FlameSplashAd` 协议：load + show:(UIWindow*)，含 onAdLoadTimeout）
- 两侧 Splash **按钮已实现真实调用**；因测试 App 未配置开屏广告位 ID（`P0F_FLAME_SPLASH_PLACEMENT`/`P0F_LINGYE_SPLASH_ID` 为空），按钮禁用并注明「未配置」——配置 ID 后即启用，无需改代码逻辑
- 未使用 Reward 冒充 Splash

## 6. 初始化人工可控（§8）与 no-fill 体验（§22）

- 启动即 `LINGYE_STATE=NOT_INITIALIZED`、`FLAME_STATE=NOT_INITIALIZED`，无自动 init
- 顺序 A/B 无需改代码重编译：直接按按钮顺序即可；快捷 Case 覆盖 M3/M4
- Flame 800110：页面如实显示 ERROR/NO_FILL + ATTEMPT #n；再点【加载 Flame 激励】即重试（无静默自动重试）；show 成功后 attempt 归零

## 7. 构建与 Gate（§24/§29/§30）

```
MANUAL_DEMO_IMPLEMENTED = YES
MANUAL_DEMO_BUILD       = PASS（xcodebuild Debug-iphoneos，DT=15 覆盖，2026-10-18）
MANUAL_DEMO_INSTALL     = PASS（2026-10-18 真机覆盖安装）
MANUAL_DEMO_LAUNCH      = PASS（无 env 直启，截图 /tmp/p0f_console_1.png 存档）
HOME_SCREEN_VISIBLE     = YES（BLACK_SCREEN = NO；四区域/badge/LAST ACTION 卡全部可见）
LINGYE_INIT_BUTTON / FLAME_INIT_BUTTON / LINGYE_REWARD_BUTTON / FLAME_REWARD_BUTTON = YES（UI 已含）
LINGYE_SPLASH_BUTTON / FLAME_SPLASH_BUTTON = YES|DISABLED_UNCONFIGURED（实现真实，缺 placement ID 时禁用）
VISIBLE_RUNTIME_LOG / OWNER / NETWORK / PLACEMENT / ERROR / REWARD_RESULT = YES（页面直接可见）
MANUAL_MODE_DEFAULT     = YES
AUTO_RUNNER_PRESERVED   = YES（C0-C4/CASE_A/B/C1/C2/C3/C4/REINIT_* 全保留；历史 [P0D-C] 标记兼容）
```

> 注意：重装会再次重置「无线数据」权限，首次启动还会弹 ATT——均需人工点允许（与 17/18 号文档一致）。

## 8. 人工验收剧本（§20，产品负责人执行）

- **M1 领页 standalone**：初始化领页 → 加载领页激励 → 展示领页激励（确认广告真实出现→reward→close→页面 PASS）
- **M2 Flame standalone**：重置 → 初始化 Flame → 加载 Flame 激励 → 展示 Flame 激励（确认 OWNER=FLAME / TOBID / network）
- **M3 领页先**：重置 → LI→LA→FI→FA→LA
- **M4 Flame 先**：重置 → FI→FA→LI→LA→FA
- 当前测试凭证：Flame AppID `b22375234108`（tobid接入测试-sigmob应用），Reward `q57514498879` → ToBid `1886359231652093`；已知行为：Sigmob 单源偶发 no-fill（200000/800110），重试即可（官方口径「偶发无填充属正常」）
- M1-M4 完成后再跑自动矩阵（§26）：`--auto-sequence CASE_A|CASE_B|C0|C1|C2|C3|C4|REINIT_*`

## 9. Git 边界（§28）

- 提交：`test(ios): add manual Lingye Flame coexistence console`（validation host + controllers + UI + docs）
- `P0FSecretConfig.h` 已 gitignore（`.gitignore: validation/**/Sources/P0FSecretConfig.h`），AppKey 未入任何提交
- 正式 SDK 公共 API 零改动（`git diff flame_sdk_ios/` 为空）
