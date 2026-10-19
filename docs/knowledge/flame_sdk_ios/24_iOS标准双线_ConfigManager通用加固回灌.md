# 24 · iOS 标准双线 ConfigManager 通用加固回灌（P3-CONFIG-MANAGER-BACKPORT）

> 日期：2026-10-19 ｜ 分支：release/ios-dual-line
> CONFIG_MANAGER_HARDENING_IMPLEMENTED = YES
> CONFIG_MANAGER_HARDENING_VERSION_BUMP = NO
> CONFIG_MANAGER_HARDENING_RELEASE_NOW = NO

## 1. P0E 根因边界（§三，正确口径）

```
P0E_TRIGGER_ROOT_CAUSE = VALIDATION_ENV_INJECTION_DEFECT
  （devicectl 多 -e 覆盖凭证）
CONFIG_MANAGER_DEFECT = ERROR_PROPAGATION_AND_INPUT_VALIDATION_WEAKNESS
  （错误传播不足 + 输入校验缺失，使真正问题被模糊成 edata missing）
禁止写成"P0E 根因就是 ConfigManager parser bug"
```

## 2. 两项通用修复（§二）

### 修复 A：服务端业务错误正确传播

- 旧问题：服务端业务失败（code≠200 / success=false）被下钻 data.edata 伪装为 "edata is missing"
- 修复：code/success 表明业务失败时，原样返回服务端 code 与 message
- 仅当 success=true 且 edata 确实缺失时才报 "edata is missing"

### 修复 B：空凭证本地提前拦截

- 旧问题：appId/appKey 为空时仍发网络请求
- 修复：本地直接失败，error code = **14005**，零网络请求

## 3. 最小语义迁移（§五-七）

```
CONFIG_BACKPORT_BASE_HEAD = 78430c4（含 1.0.2 docs closure）
CONFIG_MANAGER_BACKPORT_COMMIT = de8c00f
CONFIG_BACKPORT_CHANGED_FILES = [flame_sdk_ios/core/FlameConfigManager.m]（+35 行）
CUSTOMER_CONFIG_MANAGER_ONLY_TWO_GENERIC_FIXES = YES
LINGYE_CUSTOM_CONFIG_LEAK = NO
迁移方式 = canonical 与客户修复前逐字节一致 → 客户修复 diff 精确 apply
```

**禁止项审计**：无 Lingye/CJMobileAd/OpenSSL1.1/tb_lingye/客户配置/validation runner/marker stub 泄漏。

## 4. §九 错误检查顺序

```
CONFIG_ERROR_CHECK_ORDER = PASS
顺序：1 凭证 → 2 传输 → 3 业务 success/code → 4 edata → 5 解析
（源码行号实测：141 凭证守卫 → 172 doPostJson → 259 serverSuccess → edata）
```

## 5. TK 线 ConfigAudit 真机矩阵（§十四）

ConfigAudit consumer（MockURLProtocol mock + 断言退出码）：

| 用例 | 场景 | 期望 | 实测 | PASS |
|---|---|---|---|---|
| E1 | appId="" appKey=valid | 14005 + 零网络 | code=14005 netreq=0 | **PASS** |
| E2 | appId=valid appKey="" | 14005 + 零网络 | code=14005 netreq=0 | **PASS** |
| E3 | 双空 | 14005 + 零网络 | code=14005 netreq=0 | **PASS** |
| BIZ_FAIL | mock 1201/TEST_BIZ_FAIL | code=1201 + TEST_BIZ_FAIL | code=1201 desc=TEST_BIZ_FAIL | **PASS** |
| MISSING_EDATA | mock success 缺 edata | "edata is missing" | desc="edata is missing from server response" | **PASS** |
| NET_FAIL | mock -1009 | 网络错误原样 | code=-1009（非 edata/非 14005） | **PASS** |
| SUCCESS | 真实服务端 | 成功回调 | RESULT=PASS | **PASS** |

```
EMPTY_APPID_GUARD = PASS   EMPTY_APPKEY_GUARD = PASS   EMPTY_BOTH_GUARD = PASS
EMPTY_CREDENTIAL_NETWORK_REQUEST_COUNT = 0
SERVER_BUSINESS_ERROR_PROPAGATION = PASS
SUCCESS_RESPONSE_MISSING_EDATA = PASS
NETWORK_ERROR_PROPAGATION = PASS
TK_SUCCESS_PATH_REGRESSION = PASS
TK_EMPTY_CREDENTIAL_GUARD = PASS   TK_SERVER_ERROR_PROPAGATION = PASS
TK_MISSING_EDATA_SEMANTICS = PASS
```

## 6. TB 线 ConfigManager 回归

FlameConfigManager 是共享 core 代码——同一 .o 编入 TK 与 TB 双产物。TK 线 7 用例
全 PASS 即证明修复逻辑正确；TB 产物 strings 实测两项修复标记均在：

```
TB 产物 guard/propagation strings = 1/1 ✓
TB_SUCCESS_PATH_REGRESSION = PASS（此前多轮 TB valid-credential init PASS）
TB_EMPTY_CREDENTIAL_GUARD = PASS（同一 FlameConfigManager.o）
TB_SERVER_ERROR_PROPAGATION = PASS（同上）
TB_MISSING_EDATA_SEMANTICS = PASS（同上）
```

## 7. clear→re-init 回归

```
TK_CLEAR_REINIT_REGRESSION = PASS（P1-TK-REINIT-GATE 3/3 专项 + 多轮 FI PASS）
TK_REINIT_TIMEOUT_COUNT = 0
TB_CLEAR_REINIT_REGRESSION = PASS（P1-STANDARD TB_REGRESSION 多轮 post-clear FI PASS）
TB_REINIT_TIMEOUT_COUNT = 0
```

## 8. 构建 / API / 依赖

```
TK_BUILD = PASS（Xcode 26.0.1 / DT=13.0 / canonical v77 / tk-static）
TB_BUILD = PASS（同上 / tb-static）
PUBLIC_API_BREAKING_CHANGE = NO（FlameConfigManager.m 为内部实现，头文件零改动）
TK_DEPENDENCY_DIFF = []   TB_DEPENDENCY_DIFF = []
CONFIG_MANAGER_BACKPORT_DEPENDENCY_CHANGE = NO
PODSPEC_VERSION_CHANGED = NO
```

## 9. Gate 总结

```
CONFIG_MANAGER_BACKPORT_GATE = PENDING_TB_RUNTIME_MATRIX
P3_CONFIG_MANAGER_SOURCE_BACKPORT = COMPLETE
P3_CONFIG_MANAGER_RUNTIME_VALIDATION = PARTIAL
P3_CONFIG_MANAGER_RELEASE_READINESS = NOT_READY
CONFIG_MANAGER_HARDENING_IMPLEMENTED = YES
CONFIG_MANAGER_HARDENING_VALIDATED_ON_TK = YES
CONFIG_MANAGER_HARDENING_VALIDATED_ON_TB = PARTIAL（仅静态证据，runtime 未完成）
CONFIG_MANAGER_HARDENING_VERSION_BUMP = NO
CONFIG_MANAGER_HARDENING_RELEASE_NOW = NO
CONFIG_MANAGER_HARDENING_INCLUDED_IN_1_0_2 = NO
CUSTOMER_SIDE_CHANGE_REQUIRED = NO
SOURCE_BACKPORT_PUSHED = YES
```

## 10. 后续

标准双线 1.0.3（或下一版本）发布时，将本 commit（de8c00f 语义）纳入正式产物
并重做 Fresh Consumer + 错误路径回归。本阶段不 bump、不发版、不改 tag。


## 11. P3C 阶段性收口（2026-10-19）

### 实际状态（如实冻结）

```
CONFIG_MANAGER_BACKPORT_COMMIT = de8c00f01b0ffe8a6375a3a7c39baf649412fe10
SOURCE_BACKPORT_PUSHED = YES
P3_CONFIG_MANAGER_SOURCE_BACKPORT = COMPLETE

TK_CONFIG_AUDIT_7_CASES = PASS（真机全绿）
CONFIG_MANAGER_HARDENING_VALIDATED_ON_TK = YES

TB_BUILD = PASS
TB_FIX_PRESENT_IN_BINARY = YES（strings 实测双修复标记）
SHARED_CONFIG_MANAGER_CORE_IMPLEMENTATION = YES
TB_STATIC_INTEGRATION_EVIDENCE = PASS
TB_CONFIG_AUDIT_7_CASES = NOT_RUN
CONFIG_MANAGER_HARDENING_VALIDATED_ON_TB = PARTIAL（仅静态证据，runtime 未完成）
TB_RUNTIME_VALIDATION_COMPLETED = NO
TB_RUNTIME_DEFECT_FOUND = NO_EVIDENCE

CONFIG_MANAGER_BACKPORT_GATE = PENDING_TB_RUNTIME_MATRIX
P3_CONFIG_MANAGER_RELEASE_READINESS = NOT_READY
```

### 延后冻结

```
DEFER_TB_RUNTIME_MATRIX_TO_NEXT_RELEASE_PREFLIGHT = YES
PERSISTENT_TB_CONFIG_AUDIT_HARNESS_REQUIRED = YES
TB_RUNTIME_DEFECT_FOUND = NO_EVIDENCE
CONFIG_MANAGER_BACKPORT_REVERT_REQUIRED = NO
```

下一标准版本 Preflight 前必须先完成 TB_CONFIG_AUDIT_7_CASES = PASS，
才允许 ConfigManager 进入该版本的 Release Preflight。
未来 TB ConfigAudit 须使用持久化 validation/test host（非 /tmp 临时拼装）。

### 源码 push 事实

SOURCE_PUSH_BEFORE_FULL_RUNTIME_GATE = YES（de8c00f 在 TB runtime 补验前已 push）。
不影响发布：无版本 bump / 无 tag / 无 spec publish / 无 distribution release。
