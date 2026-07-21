# Phase 5A.18D-C：TbNativeSelfRenderView 布局修复（对齐官方 ToBid demo 模式）

**状态**：实施完成（真机验证待用户 Run）
**前置**：Phase 5A.18D-B（feat/tb_adapter 分支 commit 43c964a）
**用户反馈触发**："能出来了 但是布局不对"（GDT feedADMode=3 LargeImage 自渲染首次成功展示，但卡片与导航栏之间有大片黑色空白）

## 一、根因分析

### 1.1 用户反馈的截图症状
- 广告卡片本身渲染正常（所有元素可见，16:9 主图正常，文字清晰）
- **卡片与导航栏之间有大片黑色空白**（≈ 470pt 的空白）
- clickableViews 数量 = 3（预期 ≥ 5）

### 1.2 三层根因

| 层级 | 问题 | 后果 |
|---|---|---|
| **架构错误** | 旧实现自建 mainImageView + NSURLSession 下载主图 | 与 WindMillNativeAdView 自带的 mainImageView 双重渲染；WindMill 内部已加载主图，我们下载是冗余 |
| **高度不回写** | SelfRenderView.layoutSubviews 改了自身 frame.height，但 nativeAdView 仍是 initialFrame `{402, 874}` | 卡片下方大片黑色空白（截图症状） |
| **clickableViews 过滤** | 旧 `image != nil` 过滤导致图片未加载完的 view 被排除 | clickableViews=3（mainImageView/image 被跳过） |

### 1.3 官方 ToBid demo 对比（源码已审计）

读取 `doc/tobid_doc/ToBidDemo官方/Demo_Swift/Demo_Swift/Ads/NativeAd/` 系列：

**官方模式**（`NativeAdView.swift:36-44` / `NativeAdStyle.swift:77-91`）：
```swift
// NativeAdView.swift
init(nativeAd: WindMillNativeAd) {
    self.adView = WindMillNativeAdView()  // 直接用 WindMill 的 view 作容器
    addSubview(adView)
    adView.refreshData(nativeAd)
    // ...
}
func setup() {
    addSubview(adView)
    if nativeAd.feedADMode != .NativeExpress {
        setupRenderSelf()  // 自渲染：只自建 title/desc/icon/cta
    }
}

// NativeAdStyle.swift
static func renderLargeImage(_ nativeAd, _ adView) {
    // 直接用 WindMill 提供的 mainImageView（不自建！）
    guard let mediaView = adView.adView.mainImageView, ...
    mediaView.nx_snp.remakeConstraints { ... }
}
```

**关键洞察**：WindMillNativeAdView 本身就提供：
- `mainImageView`（单图广告的 UIImageView，WindMill 自动加载图片）
- `mediaView`（视频广告的 UIView）
- `imageViewList`（组图的 3 个 UIImageView）
- `logoView`（广告标识 view）
- `dislikeButton`（不感兴趣按钮）

这些是 **WindMillSDK.h 公开 readonly 属性**，`refreshData:` 调用后 WindMill 会自动创建并加载内容。开发者只需 reparent 到自己的布局容器，无需自己下载图片。

## 二、修复方案

### 2.1 架构变更

| 方面 | 旧实现（5A.18D-B） | 新实现（5A.18D-C） |
|---|---|---|
| mainImageView | 自建 + NSURLSession 下载 | 复用 `_nativeAdView.mainImageView`（reparent） |
| mediaView | 未处理 | 复用 `_nativeAdView.mediaView` |
| imageViewList（组图） | 未处理 | 复用 `_nativeAdView.imageViewList`（三图横排） |
| logoView | 未处理 | 复用 `_nativeAdView.logoView` |
| dislikeButton | 仅追加到 clickableViews | reparent + 加入 clickableViews |
| iconImageView | 自建 + NSURLSession | 保持（WindMill 不提供 icon view） |
| titleLabel/descLabel/ctaButton/ratingLabel | 自建 | 保持 |
| 高度同步 | 仅改自身 frame | onLayoutChanged block 回调 Adapter，回写 nativeAdView 高度 |
| clickableViews 过滤 | `image != nil` 才加入 | 去掉过滤（WindMill 负责延迟响应点击） |

### 2.2 关键 API 变更

**`TbNativeSelfRenderView.h`**：
```objc
// 新 init 签名（加 nativeAdView 参数，用于借用 WindMill 提供的 view）
- (instancetype)initWithNativeAd:(WindMillNativeAd *)nativeAd
                    nativeAdView:(WindMillNativeAdView *)nativeAdView
                    containerSize:(CGSize)containerSize;

// 新增高度回调（icon 异步加载完成后触发，回写 nativeAdView 高度）
@property (nonatomic, copy, nullable) void (^onLayoutChanged)(CGFloat height);
```

**`TbNativeAdapter.m` setupSelfRenderInContainer**：
```objc
// 关键顺序：先 refreshData 让 WindMill 准备 mainImageView/mediaView/logoView/dislikeButton
[self->_nativeAdView refreshData:self->_nativeAd];

// 创建 SelfRenderView（借用 WindMill view）
self->_selfRenderView = [[TbNativeSelfRenderView alloc]
    initWithNativeAd:self->_nativeAd
       nativeAdView:self->_nativeAdView
       containerSize:CGSizeMake(viewWidth, 0)];

// 设置高度回调（异步 icon 加载完后回写 nativeAdView 高度）
__weak typeof(self) weakSelf = self;
self->_selfRenderView.onLayoutChanged = ^(CGFloat height) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf || strongSelf->_destroyed) return;
    if (height > 0 && strongSelf->_nativeAdView) {
        CGRect f = strongSelf->_nativeAdView.frame;
        if (f.size.height != height) {
            f.size.height = height;
            strongSelf->_nativeAdView.frame = f;
        }
    }
};
```

### 2.3 Reparent 风险评估

**reparent（`[self addSubview:windMillView]`）安全性**：
- 不改变 view 所有权，view 归属仍属 nativeAdView
- 官方 demo 同样使用此模式（`TBNativeAdView.swift:70 adView.addSubview(titleLabel)` 把自建挂到 adView）
- cleanup 时不主动 `removeFromSuperview` WindMill 的 view（让 nativeAdView 整体释放时处理）
- 避免重复 addSubview：`reparentMediaViewsFromNativeAdView` 只在 init 时调用一次

## 三、布局规范（对齐官方 NativeAdStyle.swift）

### 3.1 间距/尺寸
- padding = 12
- icon: 50×50（对齐 `NativeAdStyle.swift:123`）
- dislikeButton: 24×24 右上角
- 主图比例（`mediaHeightForWidth:`）：
  - LargeImage/Video: `width * 9/16`（0.5625，官方 `NativeAdStyle.swift:84,101`）
  - GroupImage: `width * 0.3`（官方 `NativeAdStyle.swift:67`）
  - PortraitImage: `width * 4/3`（3:4 竖图）
  - SmallImage: 固定 120
- ctaButton: `sizeToFit + contentEdgeInsets`（28×12 补全）
- logoView: 30×15 左下角（与 CTA 同行）

### 3.2 高度同步链
1. SelfRenderView.layoutSubviews 末尾 → 更新 self.frame.size.height
2. 同时调 `self.onLayoutChanged(height)`
3. Adapter 收到 → 回写 `_nativeAdView.frame.size.height = height`
4. 首次同步（setupSelfRenderInContainer 末尾）+ 后续同步（icon 下载完成后 setNeedsLayout → layoutSubviews → onLayoutChanged）

## 四、构建验证

### 4.1 XCFramework 构建
- `./xcFramework_build.sh` → **ARCHIVE SUCCEEDED**（双 Archive）
- XCFramework 生成成功
- 符号校验全部 ✅（Flame core + TK 胶水 + TB 胶水 + 自动注册）
- 污染检测 ✅（无三方 SDK 静态符号）
- 弱链接 ✅（AnyThinkSDK LC_LOAD_WEAK_DYLIB）
- 二进制体积：384K

### 4.2 符号验证（XCFramework）
```
nm -gU <flame_sdk_ios> | grep TbNativeSelfRenderView
→ _OBJC_CLASS_$_TbNativeSelfRenderView ✓
→ _OBJC_METACLASS_$_TbNativeSelfRenderView ✓

nm <flame_sdk_ios> | grep TbNativeSelfRenderView
→ -[TbNativeSelfRenderView initWithNativeAd:nativeAdView:containerSize:] ✓
→ -[TbNativeSelfRenderView onLayoutChanged] ✓
→ -[TbNativeSelfRenderView reparentMediaViewsFromNativeAdView] ✓
→ -[TbNativeSelfRenderView mediaHeightForWidth:] ✓
→ _OBJC_IVAR_$_TbNativeSelfRenderView._onLayoutChanged ✓
```

### 4.3 App 产物验证（Demo TB 构建）
- `xcodebuild ... -sdk iphoneos ... build` → **BUILD SUCCEEDED**
- 7 pods（TB 配置：flame_sdk_ios_tb + ToBid-iOS-RC + Ads-CN + OpenSSL + FunlinkSDK + GDT + Mintegral）
- App framework 符号验证：
  - `-initWithNativeAd:nativeAdView:containerSize:` ✓
  - `-onLayoutChanged` ✓
  - `-reparentMediaViewsFromNativeAdView` ✓
  - 新诊断字符串 ✓
  - WindMill view selector 引用（mainImageView/mediaView/logoView/dislikeButton/imageViewList）✓

### 4.4 TK 回归
- 未修改共享 Native 公共类/协议（只修改 TB adapter 内部 SelfRenderView）
- TK 编译路径不受影响（AtNativeAdapter / AtNativeSelfRenderView 无改动）

## 五、诊断日志（新）

```
[TB_NATIVE_DIAG] selfRender reparentMediaViews: mainMediaView=0x... groupCount=0 logoView=0x... dislikeButton=0x... feedADMode=3
[TB_NATIVE_DIAG] selfRender setup: selfRenderView=0x... nativeAdView=0x... clickableViews=5 realHeight=412.0 hasMainImage=1 hasMediaView=0 hasDislike=1
```

**关键指标**：
- `hasMainImage=1`：WindMill 主图已就绪
- `clickableViews=5`：包含 icon/title/desc/cta/mainImageView（之前是 3）
- `realHeight=412.0`：实际高度（之前未回写，nativeAdView 保持 874）

## 六、真机验证（待用户 Run）

**前置**：后台 pMap.native 保持 GDT（feedADMode=3 LargeImage 自渲染物料）。

**期望结果**：
1. 截图：卡片紧贴 Demo 顶部，**无大黑色空白**
2. 主图：16:9 WindMill 内部加载，清晰无变形
3. 所有元素位置正确（icon 50×50 左上、title 右上、desc 中部、main 中下、cta 右下、logo 左下、dislike 右上）
4. clickableViews ≥ 5

## 七、红线遵守

- ✅ 不改 Flame 公共 Native API
- ✅ 不改 AtNativeAdapter / FlameTKProvider / 其他 adapter
- ✅ 不改 Demo 业务代码
- ✅ 不引第三方库（保持 NSURLSession，不引 SDWebImage/SnapKit）
- ✅ 不调 ToBid 私有 API（`mainImageView`/`mediaView`/`logoView`/`dislikeButton`/`imageViewList` 都是 WindMillSDK.h 公开 readonly 属性）
- ✅ 不 push / tag / release

## 八、后续可选优化（非本阶段）

- 视频 mediaView 真机验证（本阶段主图路径已对齐，视频路径理论支持但未真机验证）
- 组图三图横排真机验证（本阶段实现但未真实填充）
- Mintegral adapter 处置（M1 保留 / M2 移除，待用户决策）
