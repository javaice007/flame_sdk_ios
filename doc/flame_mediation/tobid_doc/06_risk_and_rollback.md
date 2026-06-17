# 06 - 风险评估与回滚方案

## 一、风险评估矩阵

### 🔴 高风险

#### 1.1 多平台依赖冲突

| 项目 | 详情 |
|------|------|
| **风险** | TopOn/AnyThink 与 ToBid 可能共享子广告网络 SDK（如 GDT/穿山甲/百度），导致符号冲突、版本冲突 |
| **触发条件** | TB Pod 引入的子网络与 TK 已有的子网络版本不一致 |
| **影响** | 编译失败、运行时 crash、广告填充异常 |
| **预防** |
| 1. Podfile.lock 对比：检查两个平台的子网络依赖树是否有交集 |
| 2. CocoaPods `use_frameworks!` vs `use_modular_headers!` 配置确认 |
| 3. 如有冲突，需通过 Pod 子依赖排除或统一版本解决 |
| **回退** | 移除 ToBid Pod，回退到仅 TK 模式 |

#### 1.2 广告位 ID 映射错误

| 项目 | 详情 |
|------|------|
| **风险** | 后台为 TB 配置的广告位 ID 不正确，或映射逻辑有误 |
| **触发条件** | 后台 pIds 中 TB 的广告位 ID 配错，或 FlameConfigManager 解析 pIds 逻辑在平台切换后出 bug |
| **影响** | 广告加载失败、空填充 |
| **预防** |
| 1. FlameConfigManager.getPId: 方法逻辑不变（已验证） |
| 2. 后台配置需严格测试：每个 Flame 广告位对应的 TB 广告位 ID |
| **回退** | 修正后台配置 |

### 🟡 中风险

#### 2.1 初始化状态混乱

| 项目 | 详情 |
|------|------|
| **风险** | 改造后存在 FlameSdk.initState、Router.currentProvider、Provider.isInitialized 三层状态，可能失同步 |
| **触发条件** | 多线程并发 init、clear 与 init 交叉执行、网络回调时序异常 |
| **影响** | SDK 状态错误，广告请求被错误拒绝 |
| **预防** |
| 1. FlameSdk.initState 的 @synchronized 已提供基础保护 |
| 2. FlameMediationRouter 的 activateProviderForPlatform 应为线程安全 |
| 3. clear() 时重置所有三层状态 |
| **回退** | 在 clear() 中添加防御性重置逻辑 |

#### 2.2 缓存导致平台切换不生效

| 项目 | 详情 |
|------|------|
| **风险** | 后台将 App 从 tk 切到 tb 后，SDK 仍使用缓存的 tk 凭证 |
| **触发条件** | 网络请求失败且本地缓存完整时，SDK fallback 使用旧缓存 |
| **影响** | SDK 继续初始化 TK 而非 TB |
| **预防** |
| 1. **采用网络优先缓存策略**：每次冷启动优先请求后台，获取最新 pt |
| 2. 仅在**网络失败**时才 fallback 缓存（不是每次启动都用缓存） |
| 3. FlameSdk.clear() 让接入方手动强制刷新 |
| 4. 未来可增加后台异步验证（先缓存启动，后台异步验证 cv） |
| **缓解** | 缓存策略已改为网络优先，正常网络环境下平台切换即时生效。仅在完全离线时才会使用旧缓存。 |

#### 2.3 回调映射不一致

| 项目 | 详情 |
|------|------|
| **风险** | TB 的某些回调事件无法精确映射到 Flame Listener 的方法 |
| **触发条件** | TB 有 Flame 协议中不存在的回调类型 |
| **影响** | 回调事件丢失或错误归类 |
| **预防** |
| 1. 逐一对比 TB SDK 的回调协议与 Flame Listener 协议
| 2. TB 独有事件通过 userCustomData 透传 |
| 3. 编写回调对照表（见 04_tobid_integration_notes.md） |
| **回退** | 扩展 Flame Listener 协议（但这是对外 API，需评估影响） |

#### 2.4 OpenSSL 依赖冲突

| 项目 | 详情 |
|------|------|
| **风险** | 当前 SDK 依赖 OpenSSL-Universal 3.x，ToBid SDK 可能也依赖 OpenSSL（可能是不同版本） |
| **触发条件** | ToBid Pod 依赖 OpenSSL 且版本不兼容 |
| **影响** | 编译失败或运行时符号找不到 |
| **预防** |
| 1. 检查 ToBid Pod 的依赖树是否有 OpenSSL |
| 2. 如有冲突，统一到同一版本 |
| **回退** | 使用 `pod 'OpenSSL-Universal', '3.0'` 锁定版本 |

### 🟢 低风险

#### 3.1 最低 iOS 版本

| 项目 | 详情 |
|------|------|
| **风险** | ToBid SDK 最低 iOS 版本高于当前 SDK 的 13.0 |
| **预防** | 检查 ToBid Podspec 的 platform :ios 版本 |
| **回退** | 升高 Flame SDK 的最低 iOS 版本 |

#### 3.2 对现有 TK 接入方的影响

| 项目 | 详情 |
|------|------|
| **风险** | 改造后，已接入 TK 的 App 功能异常 |
| **影响评估** |
| 1. 对外 API 完全不变 ✅ |
| 2. TK 适配器代码不变 ✅ |
| 3. FlameAdapterManager 保留 ✅ |
| 4. 唯一变化：FlameSdk init 链路多了 Provider 注册和 Router 激活 |
| **预防** |
| 1. Phase 1-3 完成后必须进行 TK 全量回归测试 |
| 2. 确保 pt="tk" 时走 TKProvider → FlameAdapterManager → At*Adapter，行为与改造前一致 |
| 3. 保留 FlameAdapterManager 作为 TK 初始化的直接入口（TKProvider 内部调用） |

## 二、回滚方案

### 2.1 代码回滚

改造基于 Git 分支 `feat/tb_adapter`，回滚步骤：

```bash
# 方案 A：完全回滚（放弃全部改造）
git checkout master -- flame_sdk_ios/
git checkout master -- flame_sdk_ios.podspec
git stash  # 或 git reset --hard HEAD~

# 方案 B：部分回滚（仅回滚 TB 相关，保留架构层）
git checkout feat/tb_adapter~N -- adapter/tb/
git checkout feat/tb_adapter~N -- mediation/tb/
# 保留 mediation/ 核心架构和 TKProvider
```

### 2.2 功能回滚（不停代码回滚）

如果线上出现 TB 问题，需要紧急切回 TK：

1. **后台回滚**：将 App 的 `pt` 从 `tb` 改回 `tk`，SDK 自动使用 TK
2. **接入方回滚**：调用 `FlameSdk.clear()` 后重新 `init`，清除可能残留的 TB 缓存
3. **依赖回滚**：从 Podfile 中移除 ToBid Pod，重新 `pod install`

### 2.3 渐进式发布

建议采用灰度发布策略：
1. 仅在后台为少量 App 配置 `pt: "tb"`，观察线上行为
2. 确认稳定后再扩大 TB 覆盖范围
3. TK 接入方不受影响（除非后台修改了它们的 `pt` 值）

## 三、已存在的技术债（与本次改造无关，但需关注）

| 问题 | 说明 | 建议处理时机 |
|------|------|-------------|
| 版本号不一致 | `FLAME_SDK_VERSION = "1.0.0"` vs podspec `0.1.8.4` | 本次改造统一 |
| 日志始终开启 | `setDebug:` 忽略传入参数 | 本次改造修复 |
| API 端点硬编码 | 无可配置端点、无重试 | 未来优化 |
| 无 ATT 代码 | 完全依赖接入方 | 未来增强 |
| 无 SKAdNetworkItems 声明 | 依赖聚合平台 Pod | TB Pod 引入后评估 |
| TOCTOU 竞态 | isInitialized 检查非原子 | 本次改造在 Router 中处理 |
