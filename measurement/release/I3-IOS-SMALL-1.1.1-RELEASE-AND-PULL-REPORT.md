# I3 — FlameAd iOS 1.1.1.small.1 双线正式发布 + CocoaPods 远端拉取验收报告

日期：2026-11-05 ｜ 发布 worktree：`../flame_ios_sdk_small_release`（release/ios-1.1.1-small.1 @ f5dcca7）
基线：bf29abc（1.1.1 docs close）→ 发布提交 f5dcca7 → tag `1.1.1.small.1`（annotated e92020d1）

## 1. 门禁总表

| 门禁 | 值 | 关键证据 |
|---|---|---|
| IOS_TK_SMALL_PUBLISH_GATE | **PASS** | tag 双远端可访问（github e92020d1→f5dcca7119c66fb9a0297c49657bf79ac6351f43；gitee 同值）；远端 tag 克隆含 root xcframework（SHA fda79093…59543）；flame-specs 4db31a8 含双 spec |
| IOS_TK_SMALL_REMOTE_PULL_GATE | **PASS** | 全新消费者 `git clone --single-branch --depth 1 --branch 1.1.1.small.1`（缓存空→真远端）；Pods 内框架 SHA=fda79093… |
| IOS_TK_SMALL_DEPENDENCY_CLOSURE_GATE | **PASS** | 锁闭包 == I2 A2-TK（16 pods，逐字节 diff 通过） |
| IOS_TB_SMALL_PUBLISH_GATE | **PASS** | 同 tag 下 tb/ 产物 SHA bfbd044e…0040；spec 已发布 |
| IOS_TB_SMALL_REMOTE_PULL_GATE | **PASS** | 同上真远端克隆；Pods 内框架 SHA=bfbd044e… |
| IOS_TB_SMALL_DEPENDENCY_CLOSURE_GATE | **PASS** | 锁闭包 == I2 A2-TB（9 pods，逐字节 diff 通过） |
| IOS_SMALL_DOUBLE_LINE_RELEASE_GATE | **PASS** | 六项分线门禁全 PASS |
| RUNTIME_AD_SMOKE | NOT_RUN | 指令冻结 |
| BUSINESS_CODE_CHANGED | **NO** | 仅 podspec 依赖面/版本/注释 + 发布文档；SDK 源码/产物零改动 |

## 2. 发布事实清单

| 项 | 值 |
|---|---|
| 发布分支 | release/ios-1.1.1-small.1（本地+双远端新建，非 force） |
| 发布提交 | f5dcca7119c66fb9a0297c49657bf79ac6351f43（4 files, +60/−22） |
| Tag | `1.1.1.small.1`（annotated e92020d163a011c4df125ac2738e47139bb24466 → f5dcca7） |
| 远端 | github distribution javaice007/flame_sdk_ios + gitee origin toowe-admin/flame_ios_sdk（同值） |
| 推送方式 | 显式 refspec（branch+tag），无 --force、无 --tags 通配 |
| flame-specs | 50a9254 → **4db31a8**（纯增量 2 文件 +266 行；旧 spec 字节未动） |
| spec 文件 | flame_sdk_ios/1.1.1.small.1/flame_sdk_ios.podspec；flame_sdk_ios_tb/1.1.1.small.1/flame_sdk_ios_tb.podspec |
| podspec 版本 | 双 1.1.1.small.1；source tag = s.version（github distribution）；vendored 路径不变（root / tb/） |
| 二进制指纹 | TK fda790932f0b7f3163bd39abd44ab76cd6225c593ffcca4c07be2a9f9ca59543；TB bfbd044e561110247a5170cc5b2ef0dcb5a36392432d24c8e4a35a857d740040（=1.1.1 发布字节） |
| 旧 1.1.1 完好 | spec 文件 SHA（50a92542 时点）= 主仓 1.1.1 podspec（69cf93b5… / 53249529…）；tag 1.1.1→042bf2d 双远端复核；spec 提交 0 deletions |

## 3. 远端拉取验收（真远端证据链）

前置事实：CocoaPods Git 缓存 0 条目 → 任何 flame 源获取必命中远端。两消费者互不引用、均 `:path` 禁用、精确 pin `1.1.1.small.1`。
- consumer-tk：`$ /usr/bin/git clone https://github.com/javaice007/flame_sdk_ios.git … --single-branch --depth 1 --branch 1.1.1.small.1` → 缓存 1.1.1.small.1-3f091 → Pods/flame_sdk_ios；SHA=fda79093…；16 pods
- consumer-tb：同样真远端克隆 → 缓存 1.1.1.small.1-3fb57 → Pods/flame_sdk_ios_tb；SHA=bfbd044e…；9 pods
- 注：clone 时 git 提示 "annotated tag is not a commit" 为 annotated tag 正常告警（deref 后 checkout 成功，install exit=0）
- 其余 14/8 个 pod 来自本机 Release 缓存（非 flame 源；缓存命中情况已记录于完整日志，flame 源为本次唯一必走远端的源）
- 消费者仅做 pod install（未做 xcodebuild 链接编译，可选项目未执行 = COMPILE_CHECK=NOT_RUN；依赖闭包由 I2 A2 同构已链接验证过）

## 4. 依赖闭包（消费者锁文件摘要）

TK（16 pods，完整清单见 consumer-tk.Podfile.lock）：flame_sdk_ios 1.1.1.small.1 → AnyThinkiOS 6.5.84 + OpenSSL 3.6.2000 + 酷盈(AdxSmartdigimktCN 6.5.90.2.1→SmartdigimktCNSDK 6.5.90) + CSJ(TTAdapter_Mix 7.8.0.5.2.1)+GroMore(GromoreAdapter 7.8.0.5.2.1) 共享 Ads-CN 7.8.0.5 单份 + GDT 4.16.10.2.0→GDTMobSDK 4.16.10 + KS 5.9.10.1.2.0→KSAdSDK 5.9.10.1 + 章鱼(ZY 2.6.10.7.2.0→OctopusSDK 2.6.10.7) + 倍孜 5.5.6.0.2.0→BeiZiSDK-iOS 5.5.6.0；非目标零混入（Baidu/Funlink/AdGain/FSUnion/SigmobAd-iOS = 0 命中）；零 ToBid/零跨线。
TB（9 pods）：flame_sdk_ios_tb 1.1.1.small.1 → ToBid-iOS 5.10.3 Core（内置 Sigmob）+ CSJ/GDT/KS/Octopus/Gromore(Full)/AdScope 六 subspec → Ads-CN 7.8.0.7(含 BUAdLive+BUTTSDK 火山栈)、GDTMobSDK 4.16.11、KSAdSDK 5.9.10.1、OctopusSDK 2.6.10.7、BeiZiSDK-iOS 5.5.6.0；非目标零混入（Baidu/MS/MTG/JTAd/Smartdigimkt/AnyThink = 0 命中）；零 AnyThink/零跨线。

## 5. 体积口径（引用，非本轮重测）

I2 隔离最小宿主历史测量：TK ΔTOTAL=29,416,834 bytes（30MB 十进制 PASS，余量 583,166 B）；
TB ΔTOTAL=38,323,715 bytes（30MB 十进制 **FAIL，超出 8,323,715 B**；GroMore Full→CSJMediation→BUAdLive→火山栈）。
本轮零重测、零瘦身变更；TB 不达标状态随发布如实呈报（podspec 注释与 release notes 均已明示）。

## 6. Git 远端写入台账

| # | 操作 | 对象 | 结果 |
|---|---|---|---|
| 1 | git push origin | release/ios-1.1.1-small.1 + tag 1.1.1.small.1（gitee） | new branch + new tag ✓ |
| 2 | git push distribution | 同 refs（github，proxy 7897） | new branch + new tag ✓ |
| 3 | flame-specs commit+push | 4db31a8（2 spec 文件，纯增量） | 50a9254..4db31a8 main→main ✓ |
| — | 未执行 | force push / --tags 通配 / reset / 清理 | 均 NO |

## 7. 剩余风险与 OPEN

1. TB 30MB 门槛 FAIL（超 8.32MB）——GromoreAdapterLite 备选未启用（冻结口径），如需达标须负责人批准后另轮实测。
2. TK 余量仅 0.58MB（1.9%）——后续任一依赖升级可能越线。
3. 章鱼业务映射 OPEN（TK=ZYAdapter 形态；依赖同源≠后台配置等价）。
4. RUNTIME_AD_SMOKE=NOT_RUN；COMPILE_CHECK=NOT_RUN（可选项，未执行；依赖闭包已由 I2 A2 同构闭包+真机同构矩阵背书）。
5. 版本串 `1.1.1.small.1` 为 prerelease 类字串（Gem 语义）：精确 pin 可解析（消费者实测）；无版本/`>=`/`~>` 要求不命中本版本——不污染主线默认解析，但客户必须显式 pin。
6. 原 1.1.1 spec/tag/二进制零改动（已复核）。

## 8. 结论

IOS_SMALL_DOUBLE_LINE_RELEASE_GATE = **PASS**。两份 Podspec 已在私有 specs 远端可见（flame-specs @ 4db31a8）、共同指向新 Tag `1.1.1.small.1`（双远端）的两套 1.1.1 发布字节二进制；TK/TB 各有独立全新消费者从远端真克隆拉取成功，版本、依赖闭包、二进制指纹全部正确。执行完毕，停止。
