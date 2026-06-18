# Phase 5A.10 Step 4 — 正式测试态清理报告

> **分支**：`research/thin-core-binary`
> **状态**：本地验证完成（未发布 / 未 tag / 未 push origin / 未进 Phase 6）
> **前置**：Step 3（方案 D 正式化）已通过
> **日期**：2026-06-18

---

## 一、24 项检查清单

### 分支与备份

| # | 检查项 | 结果 |
|---|--------|------|
| 1 | 当前分支 | ✅ `research/thin-core-binary` |
| 2 | 当前 HEAD | ✅ `d5eeba6`（Step 4 提交）← `4fddaf2`（Step 3 终态） |
| 3 | backup 分支保留 | ✅ `backup/phase-5a-dual-binary-stable` 在 |

### 清理动作

| # | 检查项 | 结果 |
|---|--------|------|
| 4 | 清理 `research/` | ✅ 25 个 tracked 文件全删（5 实验 podspec + 20 实验 wrappers）；untracked staging_* 一并清掉；`doc/flame_mediation/` 报告保留 |
| 5 | 删除旧 `build/core`、`build/tk`、`build/tb` | ✅ 全删（共 ~68M）；backup 分支仍可恢复 |
| 6 | 重新生成 `build/core_named/flame_sdk_ios_core.xcframework` | ✅ `./xcFramework_build.sh core-named` 成功 |
| 7 | `build/` 最终剩余内容 | ✅ 仅 `build/core_named/`（含 xcframework + 2 个 xcarchive 中间产物） |

### Core binary 完整性

| # | 检查项 | 结果 |
|---|--------|------|
| 8 | 零三方污染 | ✅ `nm -gU` 对 AnyThink/WindMill/Sigmob/AdGain/BUAd/CSJ/GDT/KSAd/Baidu/FSUnion/FlameTKProvider/FlameTBProvider/AtRewardAdapter/TbRewardAdapter 全部无输出 |
| | 体积 | 176K |
| | otool -L | 仅 `@rpath/OpenSSL.framework/OpenSSL` + 4 系统库 |
| | install_name | `@rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core` |
| | Headers | 22（10 公共 + 12 内部协议） |
| | 无三方 bundle/metallib | ✅ |

### Podspec 与目录结构

| # | 检查项 | 结果 |
|---|--------|------|
| 9 | 正式 podspec 不引用 `research/` | ✅ `grep research/` 两文件均无匹配 |
| 10 | 正式 podspec 只引用 `core_named` | ✅ 两 podspec 均为 `build/core_named/flame_sdk_ios_core.xcframework` |
| 11 | 正式 wrappers 保留 | ✅ `flame_sdk_ios/wrappers/{flame_sdk_ios,flame_sdk_ios_tb}/`（各 10 头） |

### TK 验证

| # | 检查项 | 结果 |
|---|--------|------|
| 12 | 单 pod 本地验证通过 | ✅ `pod 'flame_sdk_ios', :path => '../flame_ios_sdk'` |
| 13 | Podfile.lock 符合预期 | ✅ 无 ToBid-iOS-RC / 有 AnyThinkiOS(18) / 有 AnyThinkMediation(44) / 有 OpenSSL-Universal(4) |
| 14 | 真机 build 通过 | ✅ `** BUILD SUCCEEDED **`（康海军的iPhone, iOS 26.5, arm64） |
| | 运行时（符号层）| ✅ pod framework 含 `+[FlameTKProvider load]`；AtRewardAdapter(38 符号)；无 FlameTBProvider/TbRewardAdapter；App embed `flame_sdk_ios_core.framework` + `OpenSSL.framework` |

### TB 验证

| # | 检查项 | 结果 |
|---|--------|------|
| 15 | 单 pod 本地验证通过 | ✅ `pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk'` |
| 16 | Podfile.lock 符合预期 | ✅ 无 AnyThinkiOS / 无 AnyThinkMediation / 有 ToBid-iOS-RC(6) / 有 OpenSSL-Universal(4) |
| 17 | 真机 build 通过 | ✅ `** BUILD SUCCEEDED **` |
| | 运行时（符号层）| ✅ pod framework 含 `+[FlameTBProvider load]`；TbRewardAdapter(43 符号)；无 FlameTKProvider/AtRewardAdapter；App embed `flame_sdk_ios_core.framework` + `OpenSSL.framework` |

### Crash 防护

| # | 检查项 | 结果 |
|---|--------|------|
| 18 | 无 duplicate class | ✅ TK/TB 互斥，符号边界清晰 |
| 19 | 无 dyld OpenSSL crash | ✅ 两 podspec 显式声明 OpenSSL，App/Frameworks/ 含 OpenSSL.framework |

### 红线

| # | 检查项 | 结果 |
|---|--------|------|
| 20 | 未发布 / 未 tag / 未 push origin | ✅ 无新 tag（仅历史 `v0.1.1`）；无 `origin/research/thin-core-binary` |
| 21 | 未进入 Phase 6 | ✅ TB Splash/Interstitial/Banner/Native 仍 nil 占位 |

### 提交

| # | 检查项 | 结果 |
|---|--------|------|
| 22 | 本阶段 commit hash | ✅ `d5eeba6`（`chore: clean thin-core formalization workspace`） |

### 测试指南与上下文

| # | 检查项 | 结果 |
|---|--------|------|
| 23 | 我自己接下来怎么测试 | 见下文「二、测试清单」 |
| 24 | 更新后的 /compact | 见下文「三、更新后的 /compact」 |

---

## 二、我自己接下来怎么测试

### 前置：确保 core binary 存在

```bash
cd /Users/khj/Documents/code/97_ad/ios/flame_ios_sdk
ls build/core_named/flame_sdk_ios_core.xcframework
# 若缺失：./xcFramework_build.sh core-named
```

### 测试 TK 变体

1. **Demo Podfile**（`/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo/Podfile`）：
   ```ruby
   pod 'flame_sdk_ios', :path => '../flame_ios_sdk'
   ```
2. **FlameAdConfig**：取消「配置组 2 TK」注释，注释「配置组 1 TB」（appId=b68450787849）
3. **重装 + 构建**：
   ```bash
   cd /Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo
   pod deintegrate && rm -rf Pods Podfile.lock *.xcworkspace
   pod install
   xcodebuild -workspace adshurge-ios-demo.xcworkspace -scheme adshurge-ios-demo \
     -configuration Debug -destination "id=00008140-0011491102C2801C" build
   ```
4. **运行时观察 Console**（康海军的iPhone）：
   - `FlameTKProvider: +load 自动注册完成`
   - `FlameMediationRouter` 激活 `FlameTKProvider`
   - AnyTalkSDK 初始化成功
   - Splash/Interstitial/Reward 加载日志

### 测试 TB 变体

1. **Demo Podfile**：
   ```ruby
   pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk'
   ```
2. **FlameAdConfig**：取消「配置组 1 TB」注释，注释「配置组 2 TK」（appId=b22375234108, rewardVideo=q57514498879）
3. **重装 + 构建**：同上命令
4. **运行时观察 Console**：
   - `FlameTBProvider: +load 自动注册完成`
   - `FlameMediationRouter` 激活 `FlameTBProvider`
   - WindMill 初始化成功
   - Reward 加载走 TbRewardAdapter
   - （TB Splash/Interstitial/Banner/Native 仍 nil 占位，Phase 6）

### 验证清单（每次切换后必查）

| 项 | TK 预期 | TB 预期 |
|----|---------|---------|
| Podfile.lock ToBid-iOS-RC | 无 | 有 |
| Podfile.lock AnyThinkiOS | 有 | 无 |
| Podfile.lock OpenSSL-Universal | 有 | 有 |
| 真机 BUILD | SUCCEEDED | SUCCEEDED |
| pod framework `+load` | FlameTKProvider | FlameTBProvider |
| 反向 Provider 污染 | 无 FlameTBProvider | 无 FlameTKProvider |
| Reward adapter | AtRewardAdapter | TbRewardAdapter |
| App/Frameworks/ OpenSSL.framework | 有 | 有 |
| App/Frameworks/ flame_sdk_ios_core.framework | 有 | 有 |

### 排错速查

| 现象 | 原因 | 解决 |
|------|------|------|
| `transitive dependencies include statically linked binaries` | Podfile 缺 static linkage | 加 `use_frameworks! :linkage => :static` |
| `dyld: Library not loaded: @rpath/OpenSSL.framework/OpenSSL` | OpenSSL 未 embed | podspec 已显式声明 OpenSSL，检查 Podfile.lock 是否含 OpenSSL-Universal |
| `duplicate class` | 同时接入两个 pod | Podfile 只保留一个（flame_sdk_ios 或 flame_sdk_ios_tb） |
| 找不到 core binary | build/core_named 缺失 | `./xcFramework_build.sh core-named` |

---

## 三、更新后的 /compact

```
Phase 5A.10 Step 4 完成（正式测试态清理）。

分支：research/thin-core-binary @ d5eeba6（Step 4）← 4fddaf2（Step 3）← 8995484（Step 2B）
工作区：SDK repo 干净；Demo repo 工作树保留 TB 验证状态（Podfile: pod 'flame_sdk_ios_tb', FlameAdConfig: TB 配置组）

本阶段完成：
1. 删除 research/ 实验目录（25 tracked 文件 + untracked staging_*）
2. 清理旧 build/{core,tk,tb}（~68M）+ Pods/Podfile.lock/xcworkspace/DerivedData
3. 重新构建唯一正式 core_named 二进制：./xcFramework_build.sh core-named
   → build/core_named/flame_sdk_ios_core.xcframework (176K, 零三方污染, 22 headers)
4. TK/TB 单 pod 本地 path 验证全部通过（pod install + 真机 arm64 BUILD SUCCEEDED + 符号链正确）

正式结构（清爽）：
- flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec（方案 D, 不引用 research/）
- flame_sdk_ios/wrappers/{flame_sdk_ios, flame_sdk_ios_tb}/（各 10 转发头）
- build/core_named/flame_sdk_ios_core.xcframework（gitignored, 唯一正式二进制）
- doc/flame_mediation/（保留所有阶段报告 + integration-thin-core-draft.md）

测试方法（详见 step4 报告第二节）：
- TK: Demo Podfile 写 pod 'flame_sdk_ios', :path => '../flame_ios_sdk'
- TB: Demo Podfile 写 pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk'
- 切换后 pod deintegrate && rm -rf Pods Podfile.lock *.xcworkspace && pod install
- 真机 build: xcodebuild -destination "id=00008140-0011491102C2801C"

红线遵守：
- 不发布/tag/push origin/进 Phase 6 ✅
- backup/phase-5a-dual-binary-stable 保留 ✅
- 正式 podspec 不指向 build/tk、build/tb ✅（已删除）
- 不改 SDK 对外 API ✅

下一步可选（待用户决策）：
1. 合并 research/thin-core-binary → feat/tb_adapter
2. Phase 6：实现 TB Splash/Interstitial/Banner/Native
3. 发布准备：确认 s.source zip 包含 build/core_named/flame_sdk_ios_core.xcframework

注意：build/core_named 不在 git（gitignored），换机器或 CI 需先跑 ./xcFramework_build.sh core-named 生成。
```

---

## 四、结论

正式测试态清理完成。SDK repo 目录结构清爽：

- 正式 podspec（2 个）+ 正式 wrappers（20 头）+ 唯一正式 core binary（176K）
- `research/` 已删，旧 `build/{core,tk,tb}` 已删（backup 分支可恢复）
- TK/TB 单 pod 接入从正式 podspec 路径（`../flame_ios_sdk`）验证全部通过

仍停在本地验证阶段，未发布 / 未 tag / 未 push origin / 未进 Phase 6。
