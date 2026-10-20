# flame_sdk_ios 技术知识库索引

> 调研对象：`/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk`（产品名 flame_sdk_ios）
> 性质：现有实现的事实审计，供后续其它项目复用的技术知识资产。不含未来架构设计。
> 约束：所有文档不包含真实 platformAppkey / AppSecret / 生产凭证。

| 文档 | 主题 | 最后调研日期 | 主要代码证据入口 |
|---|---|---|---|
| 01_工程与技术栈.md | 语言/最低版本/产物形态/依赖管理 | 2026-08-18 | flame_sdk_ios.podspec、xcFramework_build.sh |
| 02_SDK初始化与配置.md | Init Public API / 状态机 / READY 语义 / 缓存回退 / 前向兼容 | 2026-08-18 | flame_sdk_ios/core/FlameSdk.{h,m}、FlameConfigManager.{h,m} |
| 03_网络签名与加密.md | /api/v1/sdk/init 协议 / MD5 签名 / AES-GCM | 2026-08-18 | flame_sdk_ios/utils/Flame{Network,Md5Signature,AesCrypto}*.m |
| 04_GroMore与聚合平台关系.md | TAKU/TOBID 双线、GroMore 间接集成事实 | 2026-08-18 | 两个 podspec、adapter/tk、adapter/tb |
| 05_广告位与对外API.md | Public Header 清单 / create API / placementId 语义 / pIds 映射 | 2026-08-18 | flame_sdk_ios/flame_sdk_ios.h、FlameSdk.m、FlameConfigManager.getPId |
| 06_激励广告与生命周期.md | Reward 方法级契约 / callback 矩阵 / 语义缺口 / 生命周期 | 2026-08-18 | ads/reward/、adapter/tk/AtRewardAdapter.m、adapter/tb/TbRewardAdapter.m |
| 07_线程日志缓存与错误模型.md | 线程语义 / Logger / UserDefaults / 错误码 | 2026-08-18 | core/FlameLogger.m、FlameErrorCode.{h,m}、utils/FlameConfigLocalStorage.m |
| 08_Demo测试与构建发布.md | Demo 使用证据 / 测试现状 / 构建发布链 | 2026-08-18 | ../adsurge-ios-demo/Sources/Ad/、xcFramework_build.sh、docs/releases/ |
| 09_可复用能力清单.md | REUSE_AS_IS / COPY_AND_ADAPT / REFERENCE_ONLY 分类 | 2026-08-18 | 全仓库 |
| 10_技术债务与注意事项.md | 带代码位置的债务清单 | 2026-08-18 | 全仓库 |
| 11_版本与发布契约.md | 版本矩阵 / Source of Truth / 发布流程 / 漂移 | 2026-08-18 | podspec ×2、FlameConfigManager.m:17、pbxproj、framework Info.plist |
| 12_Public_API兼容基线.md | 客户当前看到的完整 API 面 + 稳定性分类 | 2026-08-18 | 全部公共头文件（10 个） |
| 13_Funlink_Official_Network_Migration_Research.md | Funlink 官方 Network 迁移可行性调研（含版本矩阵/宿主契约/旧版本兼容/收益链路） | 2026-09-14 | flame_sdk_ios.podspec:72、flame-specs 全版本 podspec、docs/YfG41D3N、docs/2KR6QU、trunk podspec |
| 14_iOS双线基线冻结.md | P0A 双线基线冻结：唯一正式基线 / 双线架构 / Pod 模型 / 依赖边界 / Build Gate / 决策 D1-D4 / 分支治理 | 2026-10-17 | 全仓库 + 两 podspec + xcFramework_build.sh + build/{tk,tb}-static 产物审计 |
| 17-21号（iOS领页×TB 客户线文档） | Lingye 客户线：共存适配/edata 收口/人工 Demo/预检/1.0.2-lingye.1 发布记录——位于客户分支 feature/ios-lingye-tobid-coexist-release（1.0.2-lingye.1 已 CLOSED） | 2026-10-17/19 | 客户分支 docs/knowledge/flame_sdk_ios/ 17-21 号 |
| 22_iOS标准双线_1.0.2_WindMill回灌与发布预检.md | 标准双线 1.0.2：WindMill 幂等回灌 + 版本对齐 MANDATORY + clean-room 双构建 + 预检/技术终审 PASS | 2026-10-18 | release/ios-dual-line 22 号（本文件所在树） |
| 23_iOS标准双线_1.0.2正式发布记录.md | 标准双线 1.0.2 原子发布 CLOSED：tag 1.0.2 @ 8f42f92b（TK root + TB tb/）、flame-specs 双 spec、Published TK/TB 远端验收全绿 | 2026-10-18/19 | distribution commit 8f42f92b + flame-specs master |
| 24_iOS标准双线_ConfigManager通用加固回灌.md | P3：ConfigManager 加固回灌标准双线——SOURCE_BACKPORT=COMPLETE / TK runtime 7/7 PASS / TB runtime PARTIAL（Gate=PENDING_TB_RUNTIME_MATRIX）| 2026-10-19 | 源码 de8c00f + 文档 13168d9 |
| 25_FlameAd_iOS_Taku广告源与SDK版本盘点.md | P0 Taku iOS 升级：upgrade/ios-taku-6.5.84 分支建立 + TK 13 广告源盘点（Core 6.5.71→6.5.84）+ 官方下载清单 + 4 源 BLOCKED（官方表未覆盖）+ TB 隔离确认 | 2026-10-20 | flame_sdk_ios.podspec:66-82、Podfile:48、Podfile.lock、mediation/tk/FlameTKProvider.m、doc 04/13/14 |
| 26_Sigmob私有兼容Adapter退役与官方Adapter收口.md | P1-R1：私有 spec 审计（无源码 patch，仅依赖 workaround）→ 退役，TK 迁 AnyThinkMediationSigmobAdapter 5.1.3.2.0（SigmobAd-iOS 5.1.3 自带 WindSDK）+ 移除 TK 的 ToBid 依赖；fresh consumer 构建 PASS、ToBid 零符号；运行时验收 NOT_YET_EXECUTED | 2026-10-20 | flame_sdk_ios.podspec、flame-specs 私有 spec、validation/ios-taku-6.5.84-sigmob-migration/ |

## 一句话结论

Flame iOS SDK 是「轻核心 + 双聚合线（TAKU/TopOn=TK、TOBID/WindMill=TB）」的单二进制动态 XCFramework（纯 Objective-C，iOS 13+）：自身只做 init 配置拉取（MD5 签名 + AES-GCM 解密）、Flame 广告位→平台广告位映射、事件转发；广告全链路由 TopOn / ToBid 承担，GroMore 仅作为两线的间接广告源存在（**无 Direct GroMore**）。
