# Changelog

## 1.0.1-alpha.4

- **发奖 transId 语义修正（按 Taku/ToBid 官方文档）**：transId 只回传平台真实交易号，
  平台未回传为空串，SDK 不本地伪造 id。
  - TK：取客户端"展示唯一ID"（`kATADDelegateExtraIDKey`，Taku 文档口径为服务端
    `trans_id` 的客户端对应物），优先发奖回调 extra、次选展示回调捕获；移除 alpha.3
    使用的 `third_trans_id`（官方文档无依据）与 UUID 兜底。
  - TB：仅取 ToBid `WindMillRewardInfo.transId`（与其服务端激励回传同源）；移除
    UUID 兜底与 `thirdTransId` 混用（三方广告源标识只进诊断日志）。
  - 双线增加来源诊断日志（`[TK_REWARD_DIAG]` / `[TB_REWARD_DIAG]`），标注实际取值来源。
- **TK userCustomData 补写官方服务端回传通道**：按 Taku《服务端激励》示例，load 时
  双写 `kATAdLoadingExtraUserDataKeywordKey`（三方网络透传，既有）与
  `kATAdLoadingExtraMediaExtraKey`（Taku 服务端激励回调 URL 回传，新增），依赖服务端
  激励回调做发奖关联的客户可拿到自定义数据。
- ⚠️ 接入方注意：本版起 transId 可能为空串（平台未回传时），服务端发奖逻辑需将
  空值视为合法输入。
- 产物结构与依赖不变；客户仅改 Podfile 版本号。

## 1.0.1-alpha.3

- **修复 TK 线发奖回调 `transId` 恒为空**（客户反馈，真机复现确认）：胶水层此前读
  `localExtra["transId"]`，该 key 全链路只读不写，对任何广告源恒为空，服务端发奖
  对账受损。现优先取 TopOn 发奖 `extra` 的三方交易号（`third_trans_id`），取不到由
  Flame 生成唯一事务号（UUID）兜底，保证恒非空且多次发奖互不相同。
- **修复 TB 线发奖回调 `userCustomData` 恒为空**（SDK 侧排查发现）：此前硬编码空串，
  load 入参只进 ToBid 服务端回传参数。现 load 入参快照回传，与 TK 线"传入即回传"
  语义对齐；`userId` 增加入参兜底；`transId` 增加 `thirdTransId` 与 Flame UUID 两级兜底。
- `userId` / `userCustomData` 既有回传行为不变（仅调用 `loadWithUserId:userCustomData:`
  时回传，无参 `load` 恒空）。
- 产物结构与依赖与 1.0.1-alpha.2 完全一致，客户仅改 Podfile 版本号。

## 1.0.1-alpha.2

- **修复 TB 包打包缺陷（alpha.1 引入）**：TB 产物外壳名
  `flame_sdk_ios_tb.xcframework` 与内部 framework 名 `flame_sdk_ios.framework`
  不一致，CocoaPods 生成 `-framework "flame_sdk_ios_tb"` → `ld: framework not found`，
  客户无法开箱构建（真机闪退本身已在 alpha.1 修复）。TB 产物现与 TK 同构
  （外壳与内部均为 flame_sdk_ios），移至 `tb/` 子目录以区分两线。
- 版本号：TK = TB = `1.0.1-alpha.2`；客户升级只改 Podfile 版本号。
- TK 产物内容不变（仅版本常量更新）；TB 产物符号内容与 alpha.1 相同（仅打包结构变化）。

## 1.0.1-alpha.1

- **修复 P0 严重问题：公开 Pod 1.0.0 接入即启动闪退。** 1.0.0 的动态 framework 对 ToBid 的
  8 个 WindMill 类符号使用扁平命名空间延迟解析，而 ToBid 仅有静态归档，App 启动时 dyld
  解析不到（`symbol not found in flat namespace '_OBJC_CLASS_$__TtC11WindMillSDK11WindMillAds'`），
  TK/TB 双线均受影响。请所有 1.0.0 用户立即升级。
- 发布形态由"单二进制（动态）"切换为**静态双线产物**，链接进客户主程序，
  全部跨平台符号在 App 链接期解析，dyld 阶段无跨库查找。
- TK 产物不再包含 ToBid 胶水（零 WindMill 符号引用）；TB 产物不再包含 TopOn 胶水
  （零 AnyThink 符号引用）。
- 客户升级仅需修改 Podfile 版本号，module/import/API 完全不变。
- 平台核心依赖版本不变（AnyThinkiOS 6.5.71 / ToBid-iOS-RC 5.5.6 / OpenSSL-Universal ~> 3.6）。
- ⚠️ 本版 TB 包存在打包缺陷（见 1.0.1-alpha.2），TB 客户请使用 1.0.1-alpha.2。

## 1.0.0-alpha.1

- 发布 iOS SDK 1.0.0-alpha.1 客户接入版本。
- 提供 TK / TB 两种接入方式，二选一接入。
- 统一接入 module name：`flame_sdk_ios`。
- TK 客户通过 `flame_sdk_ios` 接入。
- TB 客户通过 `flame_sdk_ios_tb` 接入。
- Flame SDK 本身不强制要求 `use_frameworks!`。
