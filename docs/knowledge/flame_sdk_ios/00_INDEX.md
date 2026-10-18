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
| 15/16（P0B/P0C 研究文档） | 领页共存调研与依赖闭包/OpenSSL 研究（含口径修正）——位于 research 研究分支 | 2026-10-17 | research/ios-lingye-tobid-coexistence @0335b63、research/ios-lingye-tobid-dependency-closure @0d31655 |
| 17_iOS领页_TB客户共存适配.md | P0D 客户变体 flame_sdk_ios_tb_lingye：构建门禁全 PASS + 真机基线 A 全链/B init(OpenSSL1.1) PASS + 共存 edata-missing 阻断发现 | 2026-10-17 | validation/ios-lingye-customer-release/ 三 host + 真机日志/截图 + 交叉验证 |
| 18_iOS领页_TB_edata根因与运行时收口.md | P0E：edata 根因=驱动 env 缺陷+SDK 吞错（共存无罪，P0D 结论推翻）；双修复落地；共存 FI 11/11；遗留 Reward 平台 no-fill | 2026-10-18 | research/ios-lingye-edata-rootcause + NetProbe 证据 + 真机矩阵 |
| 20_iOS领页_TB正式发布预检.md | P0F_RELEASE_PREFLIGHT：runtime 全绿（P0E_RUNTIME_CLOSURE=PASS / RELEASE_CANDIDATE）；正式构建 BLOCKED_BY_TOOLCHAIN（仅 Xcode 27.1）；版本/分发仓/podspec/修复符号审计齐备 | 2026-10-18 | 20 号文档 + 75b0135 修复 + 全量矩阵日志 |
| 19_iOS领页_TB人工验收Demo.md | P0F 人工验收工作台：Coexist Test Console（默认 MANUAL_MODE，人工/自动共用控制层，runtime 归因不伪造）；V2 极简版 + Splash 主矩阵全绿 + clear→re-init SDK 缺陷修复（75b0135）；详见 18 号 §10；P0G：DT13 正式构建（20 号 §11）+ TA 终审 PASS（§12：垫片归属澄清/公开头修正/Final RC 6caf8dfe…/Fresh Clean 全绿/Standard TB 回归；待双重人工审批发布） | 2026-10-18 | LingyeFlameTBCoexist Sources/P0FTestCore·P0FConsoleViewController·AppDelegate + 新测试 App b22375234108 填充证据 |

## 一句话结论

Flame iOS SDK 是「轻核心 + 双聚合线（TAKU/TopOn=TK、TOBID/WindMill=TB）」的单二进制动态 XCFramework（纯 Objective-C，iOS 13+）：自身只做 init 配置拉取（MD5 签名 + AES-GCM 解密）、Flame 广告位→平台广告位映射、事件转发；广告全链路由 TopOn / ToBid 承担，GroMore 仅作为两线的间接广告源存在（**无 Direct GroMore**）。
