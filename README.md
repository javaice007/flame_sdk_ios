# FlameSDK iOS 对接说明文档

## 概览

| 项目 | 内容 |
|------|------|
| SDK 版本 | flame_sdk_ios 0.1.3 |
| 最低部署版本 | iOS 13.0 |
| 语言 | Objective-C（Swift 通过 Bridging Header 调用） |
| 集成方式 | CocoaPods |

---

## 一、集成配置

### 1.1 CocoaPods 安装

在 `Podfile` 中配置以下内容：

```ruby
platform :ios, '13.0'

source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'
source 'https://github.com/CocoaPods/Specs.git'

target 'YourAppTarget' do
  use_frameworks!
  pod 'flame_sdk_ios', '0.1.3'
end

# Xcode 16 兼容性修复
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
```

执行安装：
```bash
pod install
```

### 1.2 Objective-C Bridging Header（Swift 项目）

在 Xcode 中创建 Bridging Header 文件（如 `AppName-Bridging-Header.h`），并在 Build Settings 中配置 `SWIFT_OBJC_BRIDGING_HEADER`：

```objc
#ifndef AppName_Bridging_Header_h
#define AppName_Bridging_Header_h

#import <flame_sdk_ios/FlameSdk.h>

#endif
```

### 1.3 Info.plist 配置

允许广告网络进行 HTTP 请求（ATS 豁免）：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## 二、SDK 初始化

### 2.1 初始化方法

SDK 初始化为同步调用，建议在后台线程执行，通过 Semaphore 控制超时：

```swift
func initSdk() {
    let semaphore = DispatchSemaphore(value: 0)
    var initSuccess = false

    DispatchQueue.global(qos: .background).async {
        defer { semaphore.signal() }
        FlameSdk.clear()                          // 清除缓存
        FlameSdk.setDebug(true)                   // 开启调试日志
        FlameSdk.initWithAppId(
            "YOUR_APP_ID",
            appKey: "YOUR_APP_KEY"
        )
        initSuccess = true
    }

    let timeout = semaphore.wait(timeout: .now() + 10.0)

    DispatchQueue.main.async {
        if timeout == .timedOut || !initSuccess {
            // 初始化失败处理
        } else {
            // 初始化成功，可以加载广告
        }
    }
}
```

### 2.2 带回调的初始化（可选）

```swift
FlameSdk.initWithAppId("YOUR_APP_ID", appKey: "YOUR_APP_KEY") { [weak self] in
    // success
} fail: { code, desc in
    // fail: code, desc
}
```

### 2.3 核心 API

| 方法 | 说明 |
|------|------|
| `FlameSdk.clear()` | 清除缓存数据，初始化前调用 |
| `FlameSdk.setDebug(true)` | 开启调试日志 |
| `FlameSdk.initWithAppId(_:appKey:)` | 同步初始化 |
| `FlameSdk.initWithAppId(_:appKey:callback:)` | 异步初始化（带回调） |
| `FlameSdk.isInitialized()` | 检查是否已初始化 |

> **注意**：必须在初始化成功后才能加载任何广告。

---

## 三、获取 UIViewController

全屏类广告（插屏、激励视频、开屏、信息流、视频流）需要传入 `UIViewController`。SwiftUI 项目推荐使用如下工具方法：

```swift
func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
    let keyWindow = scenes
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }
    var root = keyWindow?.rootViewController
    while let presented = root?.presentedViewController {
        root = presented
    }
    if let nav = root as? UINavigationController {
        return nav.visibleViewController
    }
    return root
}
```

---

## 四、广告格式对接

### 4.1 Banner 广告（横幅广告）

**适用场景**：固定位置展示，嵌入页面布局中。

**创建 & 加载**：
```swift
var bannerAd: (AnyObject & FlameBannerAd)?

func loadBanner() {
    bannerAd?.destroy()  // 先销毁旧实例
    bannerAd = FlameSdk.createBannerAd(
        withPlacementId: "YOUR_PLACEMENT_ID",
        listener: self
    )
    bannerAd?.load(
        withUserId: "user123",
        userCustomData: "custom_data",
        width: 320,
        height: 50
    )
}
```

**展示广告 View**（在 `onAdLoaded` 回调后执行）：
```swift
func onAdLoaded() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        // 延迟 100ms 等待 SDK 内部 View 树构建完成
        let adView = self.bannerAd?.retrieveAdView()
        // 将 adView 添加到页面布局中
    }
}
```

**回调协议 `FlameBannerListener`**：

| 回调方法 | 说明 |
|---------|------|
| `onAdLoaded()` | 广告加载成功 |
| `onAdError(code:desc:)` | 加载失败 |
| `onAdShow()` | 广告展示 |
| `onAdClicked()` | 用户点击 |
| `onAdClosed()` | 广告关闭 |

**销毁**：
```swift
bannerAd?.destroy()
bannerAd = nil
```

---

### 4.2 插屏广告（Interstitial）

**适用场景**：页面跳转、关卡结束等时机展示全屏广告。

**创建 & 加载**：
```swift
var interstitialAd: (AnyObject & FlameInterstitialAd)?

func loadInterstitial() {
    guard let rootVC = topViewController() else { return }
    interstitialAd?.destroy()
    interstitialAd = FlameSdk.createInterstitialAd(
        with: rootVC,
        placementId: "YOUR_PLACEMENT_ID",
        listener: self
    )
    interstitialAd?.load(
        withUserId: "user123",
        userCustomData: "custom_data"
    )
}
```

**展示**（在 `onAdLoaded` 后调用）：
```swift
func showInterstitial() {
    if interstitialAd?.isReady() == true {
        interstitialAd?.show()
    }
}
```

**回调协议 `FlameInterstitialListener`**：

| 回调方法 | 说明 |
|---------|------|
| `onAdLoaded()` | 广告就绪 |
| `onAdError(code:desc:)` | 加载失败 |
| `onAdShow()` | 开始展示 |
| `onAdClicked()` | 用户点击 |
| `onAdClosed()` | 广告关闭 |
| `onAdReward(userId:userCustomData:)` | 奖励回调（部分场景） |

---

### 4.3 激励视频广告（Reward Video）

**适用场景**：用户主动选择观看视频换取游戏奖励、虚拟货币等。

**创建 & 加载**：
```swift
var rewardAd: (AnyObject & FlameRewardAd)?

func loadRewardAd() {
    guard let rootVC = topViewController() else { return }
    rewardAd?.destroy()
    rewardAd = FlameSdk.createRewardAd(
        with: rootVC,
        placementId: "YOUR_PLACEMENT_ID",
        listener: self
    )
    rewardAd?.load(
        withUserId: "user_123456",
        userCustomData: "reward_type_gold_coin"
    )
}
```

**展示**：
```swift
func showRewardAd() {
    if rewardAd?.isReady() == true {
        rewardAd?.show()
    }
}
```

**回调协议 `FlameRewardListener`**：

| 回调方法 | 说明 |
|---------|------|
| `onAdLoaded()` | 视频就绪 |
| `onAdError(code:desc:)` | 加载失败 |
| `onAdShow()` | 视频开始播放 |
| `onAdClicked()` | 用户点击 |
| `onAdReward(userId:userCustomData:transId:)` | **发放奖励（关键回调）** |
| `onAdPlayComplete()` | 视频播放完成 |
| `onAdClosed()` | 视频关闭 |

> **重要**：`onAdReward` 中的 `transId` 可用于服务端验证奖励合法性。

---

### 4.4 开屏广告（Splash Ad）

**适用场景**：App 启动时展示全屏品牌/广告。

**创建 & 加载**：
```swift
var splashAd: (AnyObject & FlameSplashAd)?

func loadSplashAd() {
    guard let rootVC = topViewController() else { return }
    splashAd?.destroy()
    splashAd = FlameSdk.createSplashAd(
        with: rootVC,
        placementId: "YOUR_PLACEMENT_ID",
        listener: self
    )
    splashAd?.load(
        withUserId: "user123",
        userCustomData: "splash_data"
    )
}
```

**展示**（注意：开屏广告传入 `UIWindow` 而非 `UIViewController`）：
```swift
func showSplashAd() {
    guard splashAd?.isReady() == true else { return }
    let window = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }
    if let window = window {
        splashAd?.show(window)  // 传 UIWindow！
    }
}
```

**回调协议 `FlameSplashListener`**：

| 回调方法 | 说明 |
|---------|------|
| `onAdLoaded()` | 广告就绪 |
| `onAdShow()` | 广告展示 |
| `onAdClicked()` | 用户点击 |
| `onAdError(code:desc:)` | 加载失败 |
| `onAdClosed()` | 广告关闭 |
| `onAdLoadTimeout()` | 加载超时（开屏专用） |
| `onAdReward(userId:userCustomData:)` | 奖励回调 |
| `onAdShowComplete(userId:userCustomData:)` | 展示完成 |

> **与其他广告的关键区别**：`show()` 方法接收 `UIWindow` 参数，而不是 `UIViewController`。

---

### 4.5 信息流广告（Native Ad）

**适用场景**：嵌入内容流中的原生广告，支持全屏容器展示。

**创建 & 加载**：
```swift
var nativeAd: (AnyObject & FlameNativeAd)?

func loadNativeAd() {
    guard let rootVC = topViewController() else { return }
    nativeAd?.destroy()
    nativeAd = FlameSdk.createNativeAd(
        with: rootVC,
        placementId: "YOUR_PLACEMENT_ID",
        listener: self
    )
    let screenSize = UIScreen.main.bounds.size
    nativeAd?.load(
        withUserId: "user123",
        userCustomData: "native_data",
        width: screenSize.width,
        height: screenSize.height
    )
}
```

**展示（在 UIView 容器中渲染）**：
```swift
func showNativeAd(in containerView: UIView) {
    if nativeAd?.isReady() == true {
        nativeAd?.show(inContainer: containerView)
    }
}
```

**回调协议 `FlameNativeListener`**：

| 回调方法 | 说明 |
|---------|------|
| `onAdLoaded()` | 广告缓存就绪 |
| `onAdError(code:desc:)` | 加载失败 |
| `onAdShow()` | 渲染到容器 |
| `onAdClicked()` | 用户点击 |
| `onAdClosed()` | 广告关闭 |

**推荐：加载失败自动重试（指数退避）**：
```swift
private var retryAttempt = 0
private let maxRetry = 3

func onAdError(_ code: String, desc: String) {
    guard retryAttempt < maxRetry else { return }
    retryAttempt += 1
    let delay = pow(2.0, Double(min(3, retryAttempt)))  // 2s, 4s, 8s
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.loadNativeAd()
    }
}
```

---

## 五、广告生命周期管理

所有广告格式遵循统一的生命周期：

```
创建(create) → 加载(load) → 就绪(isReady) → 展示(show) → 关闭(onAdClosed) → 销毁(destroy)
```

**最佳实践**：
- 每次 `load` 前先调用 `destroy()` 清理旧实例
- 在页面 `onDisappear` 时调用 `destroy()` 防止内存泄漏
- 所有 UI 更新必须在主线程执行

```swift
// 页面销毁时释放广告资源
.onDisappear {
    bannerAd?.destroy()
    bannerAd = nil
}
```

---

## 六、常见问题

### Q1：SDK 初始化超时（10秒）
可能原因：网络不通或 AppId/AppKey 错误。建议：
- 检查网络连接
- 确认 `NSAllowsArbitraryLoads` 已在 Info.plist 中配置
- 使用 `FlameSdk.setDebug(true)` 查看详细日志

### Q2：Swift 无法捕获 SDK Objective-C 异常
Swift 的 `do-catch` 无法捕获 `NSException`，若网络异常时 SDK 内部抛出 Objective-C 异常会导致 Crash。建议确保网络正常后再初始化，或使用异步回调版本的初始化接口。

### Q3：Banner 广告加载成功但 View 为空
`retrieveAdView()` 需在 `onAdLoaded` 回调后延迟约 100ms 调用，SDK 内部需要时间完成 View 树构建：
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    adView = bannerAd?.retrieveAdView()
}
```

### Q4：开屏广告 `show()` 参数类型
开屏广告的 `show()` 传入 `UIWindow`，而非 `UIViewController`，这与其他广告格式不同，请注意区分。

### Q5：Xcode 16 构建报错（Script Sandboxing）
在 `Podfile` 的 `post_install` hook 中设置 `ENABLE_USER_SCRIPT_SANDBOXING = 'NO'`（参考第一节配置）。

---

## 七、测试 AppId 与 AppKey

| 参数 | 值 |
|------|------|
| AppId | `b64032443515` |
| AppKey | `11710c8515a6f980bf9578572cdf4844` |

### 测试广告位 ID

| 广告格式 | Placement ID |
|---------|--------------|
| Banner | `q23035526072` |
| Interstitial | `q28769551483` |
| Native | `q80657462905` |
| Reward Video | `q86592937069` |
| Splash | `q89260083668` |

> 正式上线时请替换为媒体平台分配的真实 AppId、AppKey 及 Placement ID。

---

## 八、Info.plist 附加配置

### 8.1 SKAdNetwork IDs

苹果 SKAdNetwork 归因框架要求在 Info.plist 中声明所有合作广告网络的 ID。**缺少某个 ID 将导致该网络广告转化无法归因，广告主出价降低，进而影响 eCPM 和填充率。**

建议从 Flame ADX 获取最新列表，将以下代码添加到 Info.plist：

```xml
<key>SKAdNetworkItems</key>
  <array>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>kbd757ywx3.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>mls7yz5dvl.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>4fzdc2evr5.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>4pfyvq9l8r.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>ydx93a7ass.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>cg4yq2srnc.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>p78axxw29g.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>737z793b9f.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>v72qych5uu.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>6xzpu9s2p8.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>ludvb6z3bs.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>mlmmfzh3r3.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>c6k4g5qg8m.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>wg4vff78zm.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>523jb4fst2.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>ggvn48r87g.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>22mmun2rn5.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>3sh42y64q3.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>f38h382jlk.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>24t9a8vw3c.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>hs6bdukanm.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>prcb7njmu6.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>m8dbw4sv7c.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>9nlqeag3gk.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>cj5566h2ga.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>cstr6suwn9.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>w9q455wk68.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>wzmmz9fp6w.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>yclnxrl5pm.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>4468km3ulz.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>t38b2kh725.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>k674qkevps.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>7ug5zh24hu.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>5lm9lj6jb7.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>9rd848q2bz.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>7rz58n8ntl.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>4w7y6s5ca2.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>feyaarzu9v.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>ejvt5qm6ak.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>9t245vhmpl.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>n9x2a789qt.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>44jx6755aq.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>zmvfpc5aq8.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>tl55sbb4fm.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>2u9pt9hc89.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>5a6flpkh64.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>8s468mfl3y.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>glqzh8vgby.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>av6w8kgt66.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>klf5c3l5u5.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>dzg6xy7pwj.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>y45688jllp.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>hdw39hrw9y.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>ppxm28t8ap.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>424m5254lk.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>5l3tpt7t6e.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>uw77j35x4d.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>4dzt52r2t5.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>mtkv5xtk9e.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>gta9lk7p23.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>5tjdwbrq8w.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>3rd42ekr43.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>g28c52eehv.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>su67r6k2v3.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>rx5hdcabgc.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>2fnua5tdw4.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>32z4fx6l9h.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>xy9t38ct57.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>54nzkqm89y.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>9b89h5y424.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>pwa73g5rt2.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>79pbpufp6p.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>kbmxgpxpgc.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>275upjj5gd.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>rvh3l7un93.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>qqp299437r.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>294l99pt4k.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>74b6s63p6l.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>44n7hlldy6.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>6p4ks3rnbw.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>f73kdq92p3.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>e5fvkxwrpn.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>97r2b46745.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>3qcr597p9d.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>578prtvx9j.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>n6fk4nfna4.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>b9bk5wbcq9.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>84993kbrcf.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>24zw6aqk47.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>pwdxu55a5a.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>cs644xg564.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>6964rsfnh4.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>9vvzujtq5s.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>a7xqa6mtl2.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>r45fhb6rf7.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>c3frkrj4fj.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>6g9af3uyq4.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>u679fj5vs4.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>g2y4y55b64.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>zq492l623r.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>a8cz6cu7e5.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>s39g8k73mm.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>dbu4b84rxf.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>mj797d8u6f.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>v9wttpbfk9.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>ns5j362hk7.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>mqn7fxpca7.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>cp8zw746q7.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>3qy4746246.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>v4nxqhlyqp.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>vutu7akeur.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>y5ghdn5j9k.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>n38lu8286q.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>47vhws6wlr.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>a2p9lx4jpn.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>8c4e2ghe7u.skadnetwork</string>
    </dict>
    <dict>
      <key>SKAdNetworkIdentifier</key>
      <string>f7s53z58qe.skadnetwork</string>
    </dict>
  </array>
```

> 建议定期从 Flame ADX 获取最新列表，以确保新接入广告网络的归因数据完整。

---

### 8.2 LSApplicationQueriesSchemes

为提高 Flame ADX 的广告收益效果，需声明可查询的第三方 App scheme，用于广告点击 DeepLink 跳转及用户人群定向，**有助于提升电商类高价广告的填充率和 eCPM**。

将以下代码添加到 Info.plist：

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>taobao</string>
  <string>pinduoduo</string>
  <string>openapp.jdmobile</string>
  <string>imeituan</string>
  <string>iosamap</string>
  <string>alipay</string>
  <string>baiduboxapp</string>
  <string>vipshop</string>
  <string>tmall</string>
  <string>meituanwaimai</string>
  <string>kwai</string>
  <string>eleme</string>
  <string>xhsdiscover</string>
  <string>ksnebula</string>
  <string>sinaweibo</string>
  <string>fleamarket</string>
  <string>bilibili</string>
  <string>quark</string>
  <string>com.sy.dldllhsj</string>
  <string>com.yunkai.xianyu</string>
  <string>com.netease.nshm</string>
  <string>com.lilithgames.solarland.ios.cnnew</string>
  <string>com.netease.yyslscn</string>
  <string>infinitynikkicn</string>
  <string>mdd</string>
  <string>moyi</string>
  <string>glg136c4b5fbccab</string>
  <string>guazi</string>
  <string>momochat</string>
  <string>comdzhongfhjc</string>
  <string>hmjc</string>
  <string>com.aio.fasting</string>
  <string>com.pwrd.zhuxian2.zs</string>
  <string>com.khorgas.hsdj</string>
  <string>com.gof.china</string>
  <string>openjdjrapp</string>
  <string>xtlqabroad</string>
  <string>com.netease.stzb</string>
  <string>com.gf.cxswz</string>
  <string>SilverandBlood</string>
  <string>stbnt</string>
  <string>1235601864</string>
  <string>1001394201</string>
  <string>tbopen</string>
  <string>pddopen</string>
  <string>baiduboxlite</string>
  <string>wireless1688</string>
  <string>iqiyi</string>
  <string>weixin</string>
  <string>taobaotravel</string>
  <string>alipays</string>
  <string>youku</string>
  <string>taobaolive</string>
  <string>tongyi</string>
</array>
```

