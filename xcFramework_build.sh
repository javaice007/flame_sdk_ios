#!/bin/bash
set -e

# ============================================================
# xcFramework_build.sh — 单二进制构建脚本（Phase 5A.12 mainline）
# ------------------------------------------------------------
# 本分支（research/single-binary-mainline）只支持单二进制构建。
#
# 一个对外二进制包：
#   build/flame_sdk_ios.xcframework
#
# 该二进制同时内置：
#   - Flame SDK 自有 core / ads / utils / mediation 骨架
#   - TK 平台胶水：FlameTKProvider + 6 个 At*Adapter + AtNativeSelfRenderView
#   - TB 平台胶水：FlameTBProvider + TbRewardAdapter
#   - 两个 +load 自动注册（FlameTKProvider 注册 tk / FlameTBProvider 注册 tb）
#
# 不内置（由 podspec dependency 提供）：
#   - AnyThinkSDK（TK 平台核心，动态依赖 LC_LOAD_DYLIB）
#   - ToBid / WindMill（TB 平台核心，U 引用 lazy binding）
#   - 任何广告源 SDK 与 Adapter
#
# 用法：
#   ./xcFramework_build.sh                 # 默认 = single-binary
#   ./xcFramework_build.sh single-binary   # 显式写法（等价默认）
#   ./xcFramework_build.sh tb-static       # TB 静态双线产物 → build/tb-static/flame_sdk_ios.xcframework
#   ./xcFramework_build.sh tk-static       # TK 静态双线产物 → build/tk-static/flame_sdk_ios.xcframework
#
# 静态双线变体（release/ios-dual-line，修复 TB 客户 1.0.0 dyld 闪退）：
#   背景：single-binary 动态产物对 ToBid（WindMill 静态归档）使用
#   -undefined dynamic_lookup 扁平命名空间延迟解析，TB 客户 App 启动时 dyld
#   解析不到 8 个 WindMill 类符号（如 _OBJC_CLASS_$__TtC11WindMillSDK11WindMillAds）
#   → 必崩。客户端无法绕过（导出符号表 / force_load 均无效），必须改产物形态。
#   静态双线产物：
#     - flame 以 static framework（ar 归档）交付，WindMill 符号留为未定义，
#       由 ToBid-iOS-RC 静态归档在客户 App 链接期解析（链接期全解析，无 dyld 查找）
#     - 按线排除另一线胶水（tb-static 排除 At*/FlameTKProvider；tk-static 排除
#       Tb*/FlameTBProvider），保证 TB 产物零 AnyThink 符号引用（TB 客户不接
#       AnyThinkiOS，静态链接期出现 AT* 未定义符号会直接链接失败）
#     - source 层配套隔离：FlameAdapterManager.m 遗留 TK init（ATAPI）与
#       FlameSdk.m 防御性补注册均按 FLAME_BUILD_TB / FLAME_BUILD_TK 宏隔离
#     - +load 自动注册依赖 podspec 的 -ObjC（接入期 OTHER_LDFLAGS，已有）
#
# 不再支持的历史入口（已废弃，报错退出）：
#   ./xcFramework_build.sh tk              # ❌ 已删除（双二进制互斥分发）
#   ./xcFramework_build.sh tb              # ❌ 已删除（双二进制互斥分发）
#   ./xcFramework_build.sh core            # ❌ 已删除（Phase 5A.10 thin core）
#   ./xcFramework_build.sh core-named      # ❌ 已删除
#   ./xcFramework_build.sh tk-plugin       # ❌ 已删除（Phase 5A.11 三包方案）
#   ./xcFramework_build.sh tb-plugin       # ❌ 已删除（Phase 5A.11 三包方案）
#   ./xcFramework_build.sh release         # ❌ 已删除（Phase 5A.11 三包方案）
#   ./xcFramework_build.sh nosdk           # ❌ 已删除（曾作为 single-binary 别名，统一为 single-binary）
#   ./xcFramework_build.sh dual            # ❌ 已删除（Podfile 内部别名）
#
# 平台选择机制：
#   编译期：不再使用 FLAME_BUILD_TK / FLAME_BUILD_TB / FLAME_PLUGIN_TK / FLAME_PLUGIN_TB / HAS_TOBID 等宏
#           TK/TB Provider/Adapter 胶水始终全部编进同一个 Mach-O
#   运行期：Router 根据服务端下发的 pt=tk / pt=tb 激活对应 Provider
#           Provider 注册由 +load 自动完成（dyld 加载 binary 时触发）
#
# 兜底：双二进制互斥分发方案保留在 backup/phase-5a-dual-binary-stable 分支
#       三包方案保留在 research/thin-core-binary 分支（Phase 5A.11 文档）
# ============================================================

# =========================
# Deployment target（P0G §七：显式参数，默认=产品契约 13.0，禁止硬编码 15.0）
# Xcode 27.1 validation 机器请显式：FLAME_DEPLOYMENT_TARGET=15 ./xcFramework_build.sh ...
# Podfile post_install 读取同一变量；正式 DT13 构建一律不设该变量或设 13.0
# =========================
FLAME_DEPLOYMENT_TARGET="${FLAME_DEPLOYMENT_TARGET:-13.0}"
MIN_IOS_VERSION="${FLAME_DEPLOYMENT_TARGET}"

# =========================
# 变体解析（single-binary / tb-static / tk-static）
# =========================
VARIANT="${1:-single-binary}"

case "$VARIANT" in
  single-binary|tb-static|tk-static) ;;
  *)
  echo "❌ 未知变体: $VARIANT（只支持 single-binary / tb-static / tk-static）"
  echo ""
  echo "   用法："
  echo "     ./xcFramework_build.sh                 # 默认 = single-binary（动态单二进制）"
  echo "     ./xcFramework_build.sh single-binary   # 显式写法（等价默认）"
  echo "     ./xcFramework_build.sh tb-static       # TB 静态双线产物（1.0.1-alpha.1 起 TB 线发布形态）"
  echo "     ./xcFramework_build.sh tk-static       # TK 静态双线产物（待真机验证后启用）"
  echo ""
  echo "   历史入口已废弃（tk/tb/core/core-named/tk-plugin/tb-plugin/release/nosdk/dual）。"
  exit 1
  ;;
esac

# ============================================================
# 静态双线变体（tb-static / tk-static）独立流程，构建完成后 exit。
# 与 single-binary 流程互不干扰；single-binary 原有 xcconfig patch
# （AnyThinkSDK 弱链接 / ToBid 归档隔离 / dynamic_lookup）在静态产物下
# 均不适用（static framework 无 load command、无链接步骤），全部跳过。
# ============================================================
if [ "$VARIANT" = "tb-static" ] || [ "$VARIANT" = "tk-static" ]; then
  echo "=========================================="
  echo "  📦 构建 Flame SDK 静态双线 — ${VARIANT}"
  echo "=========================================="

  if [ "$VARIANT" = "tb-static" ]; then
    LINE_MACRO="FLAME_BUILD_TB=1"
    # 排除 TK 线胶水：adapter/tk/At*Adapter、AtNativeSelfRenderView、mediation/tk/FlameTKProvider
    EXCLUDE_PATTERN="At*.* FlameTKProvider.*"
    STATIC_SUBDIR="tb-static"
    # 外壳名必须与内部 framework 名一致（flame_sdk_ios.framework）：
    # CocoaPods 按 xcframework 外壳名生成 -framework 链接 flag，外壳叫
    # flame_sdk_ios_tb 而内部是 flame_sdk_ios.framework 时，客户工程会生成
    # -framework "flame_sdk_ios_tb" → ld: framework not found（1.0.1-alpha.1
    # TB 包即此缺陷，真机已验证闪退修复但无法开箱构建）。
    # 与 TK 产物的同名冲突通过目录区分：dist 仓库放 tb/ 子目录，TB podspec
    # 引用 'tb/flame_sdk_ios.xcframework'。
    XCFRAMEWORK_NAME="flame_sdk_ios.xcframework"
    OTHER_LINE_SYMBOLS='FlameTKProvider|AtRewardAdapter|AtSplashAdapter|AtInterstitialAdapter|AtBannerAdapter|AtNativeAdapter|AtNativeSelfRenderView|ATAPI'
    OTHER_LINE_LABEL="TK/AnyThink"
    EXPECT_GLUE_SYMBOLS="FlameTBProvider TbRewardAdapter TbSplashAdapter TbInterstitialAdapter TbBannerAdapter TbNativeAdapter TbNativeSelfRenderView"
  else
    LINE_MACRO="FLAME_BUILD_TK=1"
    # 排除 TB 线胶水：adapter/tb/Tb*Adapter、TbNativeSelfRenderView、mediation/tb/FlameTBProvider
    EXCLUDE_PATTERN="Tb*.* FlameTBProvider.*"
    STATIC_SUBDIR="tk-static"
    XCFRAMEWORK_NAME="flame_sdk_ios.xcframework"
    OTHER_LINE_SYMBOLS='FlameTBProvider|TbRewardAdapter|TbSplashAdapter|TbInterstitialAdapter|TbBannerAdapter|TbNativeAdapter|TbNativeSelfRenderView|WindMill'
    OTHER_LINE_LABEL="TB/WindMill"
    EXPECT_GLUE_SYMBOLS="FlameTKProvider AtRewardAdapter AtSplashAdapter AtInterstitialAdapter AtBannerAdapter AtNativeAdapter AtNativeSelfRenderView"
  fi

  OUTPUT_DIR="./build/${STATIC_SUBDIR}"
  DERIVED_DATA="${OUTPUT_DIR}/ddata"
  XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/${XCFRAMEWORK_NAME}"

  # 干净 pod install（静态双线与 single-binary 共用同一依赖环境：
  # 两线胶水的头文件都在 Pods 里，编译期按需 import；libtool 打归档不链接任何 pod）
  echo "🧹 清理旧 Pods 安装..."
  pod deintegrate >/dev/null 2>&1 || true
  rm -rf Pods Podfile.lock

  echo "📦 pod install（${VARIANT}：OpenSSL + AnyThinkiOS + ToBid-iOS-RC，仅编译期用）..."
  pod install

  rm -rf ~/Library/Developer/Xcode/DerivedData/flame_sdk_ios-*
  rm -rf "${OUTPUT_DIR}"

  # =========================
  # 构建（staticlib 用 build 而非 archive：静态 framework 不需要签名/嵌入，
  # 直接从 Build/Products 取 .framework 即可，规避 archive 对 staticlib 的兼容问题）
  # =========================
  echo "📦 构建 ${VARIANT} 真机切片（${LINE_MACRO}，MACH_O_TYPE=staticlib）..."
  xcodebuild build \
    -workspace flame_sdk_ios.xcworkspace \
    -scheme flame_sdk_ios \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "${DERIVED_DATA}" \
    IPHONEOS_DEPLOYMENT_TARGET="${MIN_IOS_VERSION}" \
    MACH_O_TYPE="staticlib" \
    BUILD_LIBRARY_FOR_DISTRIBUTION="YES" \
    CODE_SIGNING_ALLOWED="NO" \
    GCC_PREPROCESSOR_DEFINITIONS="\$(inherited) COCOAPODS=1 ${LINE_MACRO}" \
    EXCLUDED_SOURCE_FILE_NAMES="${EXCLUDE_PATTERN}"

  echo "📦 构建 ${VARIANT} 模拟器切片（x86_64，与现有分发口径一致）..."
  xcodebuild build \
    -workspace flame_sdk_ios.xcworkspace \
    -scheme flame_sdk_ios \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "${DERIVED_DATA}" \
    ARCHS="x86_64" \
    IPHONEOS_DEPLOYMENT_TARGET="${MIN_IOS_VERSION}" \
    MACH_O_TYPE="staticlib" \
    BUILD_LIBRARY_FOR_DISTRIBUTION="YES" \
    CODE_SIGNING_ALLOWED="NO" \
    GCC_PREPROCESSOR_DEFINITIONS="\$(inherited) COCOAPODS=1 ${LINE_MACRO}" \
    EXCLUDED_SOURCE_FILE_NAMES="${EXCLUDE_PATTERN}"

  DEVICE_FW="${DERIVED_DATA}/Build/Products/Release-iphoneos/flame_sdk_ios.framework"
  SIM_FW="${DERIVED_DATA}/Build/Products/Release-iphonesimulator/flame_sdk_ios.framework"
  for FW in "${DEVICE_FW}" "${SIM_FW}"; do
    if [ ! -d "$FW" ]; then
      echo "❌ 构建产物缺失：$FW"
      exit 1
    fi
  done

  echo "🛠️ 合并 XCFramework（static framework slices）..."
  xcodebuild -create-xcframework \
    -framework "${DEVICE_FW}" \
    -framework "${SIM_FW}" \
    -output "${XCFRAMEWORK_OUTPUT}"

  # 删除 .framework 内部不该存在的文件（.sh 会导致 codesign 失败，.podspec 是冗余文件）
  find "${XCFRAMEWORK_OUTPUT}" -type f \( -name "*.sh" -o -name "*.podspec" \) -delete

  # =========================
  # 符号校验（静态双线专属断言，任一失败即构建中止）
  # =========================
  CHECK_BINARY=$(find "${XCFRAMEWORK_OUTPUT}" -path "*ios-arm64*/flame_sdk_ios" -type f | head -1)
  if [ -z "$CHECK_BINARY" ]; then
    echo "❌ 未找到 ios-arm64 切片二进制"
    exit 1
  fi
  echo ""
  echo "🔍 符号校验（${VARIANT}）..."
  echo "   二进制体积: $(du -h "$CHECK_BINARY" | cut -f1)"

  # 1) 必须是静态归档（ar archive），不再是 MH_DYLIB
  if file "$CHECK_BINARY" | grep -q "current ar archive"; then
    echo "   ✅ 产物为静态归档（current ar archive）"
  else
    echo "❌ 产物不是静态归档：$(file "$CHECK_BINARY")"
    echo "   → MACH_O_TYPE=staticlib 未生效，静态双线发布中止"
    exit 1
  fi

  # 2) Flame core 符号齐全
  for sym in FlameSdk FlameLogger FlameMediationRouter FlameMediationRegistry FlameAdapterManager FlameConfigManager; do
    cnt=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_${sym}" || true)
    if [ "${cnt:-0}" -gt 0 ]; then
      echo "   ✅ ${sym}"
    else
      echo "❌ Flame core 符号缺失：${sym}"
      exit 1
    fi
  done

  # 3) 本线胶水符号齐全
  for sym in ${EXPECT_GLUE_SYMBOLS}; do
    cnt=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_${sym}" || true)
    if [ "${cnt:-0}" -gt 0 ]; then
      echo "   ✅ ${sym}"
    else
      echo "❌ 本线胶水符号缺失：${sym}"
      exit 1
    fi
  done

  # 4) 隔离断言：另一线符号（含其平台 SDK 引用）在归档里必须为 0（定义与未定义都算）
  #    这是静态双线能发布的关键：TB 产物含任何 AT* 引用都会让 TB 客户链接失败，反之亦然。
  POLL_OTHER=$(nm -a "$CHECK_BINARY" 2>/dev/null | grep -cE "${OTHER_LINE_SYMBOLS}" || true)
  if [ "${POLL_OTHER:-0}" -eq 0 ]; then
    echo "   ✅ 零 ${OTHER_LINE_LABEL} 符号污染（定义+未定义均无）"
  else
    echo "❌ 发现 ${OTHER_LINE_LABEL} 符号污染 ${POLL_OTHER} 处（EXCLUDED_SOURCE_FILE_NAMES 未生效？）"
    nm -a "$CHECK_BINARY" 2>/dev/null | grep -E "${OTHER_LINE_SYMBOLS}" | head -20 | sed 's/^/      /'
    exit 1
  fi

  # 5) 跨线符号（本线平台 SDK 的未定义引用，接入期由对应 pod 解析）
  if [ "$VARIANT" = "tb-static" ]; then
    UNDEF_WIND=$(nm -u "$CHECK_BINARY" 2>/dev/null | grep -cE "WindMill|WindSDK|WindFoundation" || true)
    echo "   （参考）WindMill 未定义符号: ${UNDEF_WIND:-0} 个（客户 App 链接期由 ToBid-iOS-RC 归档解析）"
    UNDEF_OPENSSL=$(nm -u "$CHECK_BINARY" 2>/dev/null | grep -cE "SSL_|EVP_|AES_" || true)
    echo "   （参考）OpenSSL 未定义符号: ${UNDEF_OPENSSL:-0} 个（由 OpenSSL-Universal 动态 framework 解析）"
  else
    UNDEF_AT=$(nm -u "$CHECK_BINARY" 2>/dev/null | grep -cE "ATAPI|ATSDK|ATAdManager" || true)
    echo "   （参考）AnyThink 未定义符号: ${UNDEF_AT:-0} 个（客户 App 链接期由 AnyThinkSDK.framework 解析）"
  fi

  # 6) module / headers 完整性（接入方 import flame_sdk_ios 依赖）
  MODULE_MAP=$(find "${XCFRAMEWORK_OUTPUT}" -name "module.modulemap" | head -1)
  if [ -n "$MODULE_MAP" ]; then
    echo "   ✅ Modules/module.modulemap 存在"
  else
    echo "❌ module.modulemap 缺失（import flame_sdk_ios 会失败）"
    exit 1
  fi

  echo ""
  echo "✅ XCFramework 构建完成（${VARIANT}）：${XCFRAMEWORK_OUTPUT}"

  # 静态双线产物均复制到开发仓库根目录（podspec vendored_frameworks 引用
  # 根目录相对路径，本地 :path 集成需要；不进 git，与历史根目录副本同理）。
  # TK → 根目录 flame_sdk_ios.xcframework；TB → tb/ 子目录（同名文件靠目录区分）。
  ROOT_XCFW_PATH="flame_sdk_ios.xcframework"
  if [ "$VARIANT" = "tb-static" ]; then
    ROOT_XCFW_PATH="tb/flame_sdk_ios.xcframework"
  fi
  rm -rf "${ROOT_XCFW_PATH}"
  mkdir -p "$(dirname "${ROOT_XCFW_PATH}")"
  cp -R "${XCFRAMEWORK_OUTPUT}" "${ROOT_XCFW_PATH}"
  echo "📦 已复制到开发仓库：${ROOT_XCFW_PATH}（本地开发用，不进 git）"

  exit 0
fi

echo "=========================================="
echo "  📦 构建 Flame SDK 单二进制 — single-binary"
echo "=========================================="

# =========================
# 基础配置
# =========================
WORKSPACE_NAME="flame_sdk_ios.xcworkspace"
SCHEME_NAME="flame_sdk_ios"
FRAMEWORK_NAME="flame_sdk_ios"

# single-binary 正式输出到 build/ 顶层（无子目录）
# 中间 xcarchive 放 Archives/single_binary/（构建后清理）
OUTPUT_DIR="./build"
ARCHIVE_DIR="./Archives/single_binary"
rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

IOS_ARCHIVE_PATH="${ARCHIVE_DIR}/${FRAMEWORK_NAME}_ios"
SIM_ARCHIVE_PATH="${ARCHIVE_DIR}/${FRAMEWORK_NAME}_sim"
XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"

# =========================
# 干净 pod install（single-binary 唯一依赖环境）
# 避免上一个构建的 Pods 残留污染本次构建
# =========================
echo "🧹 清理旧 Pods 安装..."
pod deintegrate >/dev/null 2>&1 || true
rm -rf Pods Podfile.lock

echo "📦 pod install（single-binary：OpenSSL + AnyThinkiOS + ToBid-iOS-RC）..."
pod install

# =========================
# 深度清理缓存 + 旧产物
# =========================
rm -rf ~/Library/Developer/Xcode/DerivedData/${FRAMEWORK_NAME}-*
rm -rf "${OUTPUT_DIR}"

# =========================
# AnyThinkSDK 弱链接（Phase 5A.13 Step 1.2B）
# ----------------------------
# 根本问题：single-binary 同时内置 TK/TB 胶水，binary 对 AnyThinkSDK 有 LC_LOAD_DYLIB 硬依赖。
# 即使 pt=tb 永不调用 TK 代码，TB App 启动时 dyld 仍会加载 AnyThinkSDK.framework，
# 触发其内部 ADX 完整性检测弹窗（"AnyThink Adx SDK 重要组件缺失"）。
#
# 解决：在 SDK 自身构建期，把对 AnyThinkSDK 的链接从 -framework（强）改为 -weak_framework（弱），
# 生成 LC_LOAD_WEAK_DYLIB 而非 LC_LOAD_DYLIB。
#   - TK podspec：通过 s.dependency 'AnyThinkiOS' 带入 AnyThinkSDK.framework → TK App 仍能强加载
#   - TB podspec：不依赖 AnyThinkiOS → TB App 不携带 AnyThinkSDK.framework → dyld 跳过弱链接，正常运行
# 弱链接后 AnyThink 类引用在 framework 缺失时返回 nil，TK Provider 入口已做 NSClassFromString 守卫（见 FlameTKProvider.m）。
#
# 设计要求（Phase 5A.13 Step 1.2B 收口）：
#   - 幂等：重复运行不会重复替换（已是 -weak_framework 时跳过）
#   - fail-fast：xcconfig 既不含 -framework 也不含 -weak_framework 时直接退出（Pods 结构异常）
#   - 后置 otool 自动断言：见脚本末尾"AnyThinkSDK 弱链接产物断言"
# =========================
echo "🧩 single-binary: AnyThinkSDK 改为弱链接（-weak_framework）"
PODS_XCCONFIG_DIR="./Pods/Target Support Files/Pods-flame_sdk_ios"
if [ ! -d "$PODS_XCCONFIG_DIR" ]; then
  echo "❌ Pods xcconfig 目录不存在：$PODS_XCCONFIG_DIR（pod install 失败？）"
  exit 1
fi
WEAK_PATCHED_COUNT=0      # 本次实际从 -framework 改为 -weak_framework 的文件数
WEAK_ALREADY_COUNT=0      # 已经是 -weak_framework 的文件数（幂等跳过）
WEAK_MISSING_COUNT=0      # 既无 -framework 也无 -weak_framework 的文件数（异常）
for XC in "$PODS_XCCONFIG_DIR"/*.xcconfig; do
  [ -f "$XC" ] || continue
  # 必须是 Pods-flame_sdk_ios 主 target 的 xcconfig（debug/release），跳过 ack/modulemap 等
  base=$(basename "$XC")
  case "$base" in
    Pods-flame_sdk_ios.debug.xcconfig|Pods-flame_sdk_ios.release.xcconfig) ;;
    *) continue ;;
  esac
  # 幂等：若已是 -weak_framework AnyThinkSDK，直接跳过
  if grep -qE -- '-weak_framework[[:space:]]+"?AnyThinkSDK"?' "$XC"; then
    WEAK_ALREADY_COUNT=$((WEAK_ALREADY_COUNT + 1))
    echo "   ⏭️  $(basename "$XC")：已是 -weak_framework AnyThinkSDK（幂等跳过）"
    continue
  fi
  # 正常路径：把 -framework "AnyThinkSDK" / -framework AnyThinkSDK 替换为 -weak_framework AnyThinkSDK
  if grep -qE -- '-framework[[:space:]]+"?AnyThinkSDK"?' "$XC"; then
    sed -i '' -E 's/-framework[[:space:]]+"?AnyThinkSDK"?/-weak_framework AnyThinkSDK/g' "$XC"
    # 替换后再校验一次（fail-fast：替换失败立即退出）
    if ! grep -qE -- '-weak_framework[[:space:]]+"?AnyThinkSDK"?' "$XC"; then
      echo "❌ 替换后校验失败：$(basename "$XC") 仍未变成 -weak_framework AnyThinkSDK"
      exit 1
    fi
    # 再次确认没有残留 -framework "AnyThinkSDK"（避免 sed 正则未全覆盖）
    if grep -qE -- '-framework[[:space:]]+"?AnyThinkSDK"?' "$XC"; then
      echo "❌ 替换后仍残留 -framework AnyThinkSDK：$(basename "$XC")"
      grep -nE -- '-framework[[:space:]]+"?AnyThinkSDK"?' "$XC" | sed 's/^/      /'
      exit 1
    fi
    WEAK_PATCHED_COUNT=$((WEAK_PATCHED_COUNT + 1))
    echo "   ✏️  patched $(basename "$XC")"
    continue
  fi
  # 既不是 -framework 也不是 -weak_framework：Pods 结构异常，fail-fast
  WEAK_MISSING_COUNT=$((WEAK_MISSING_COUNT + 1))
  echo "❌ xcconfig 既不含 -framework AnyThinkSDK 也不含 -weak_framework AnyThinkSDK：$(basename "$XC")"
  echo "   （CocoaPods 生成的 OTHER_LDFLAGS 应该包含 -framework \"AnyThinkSDK\"，结构异常请检查 Podfile）"
done
# fail-fast：核心 target xcconfig 任一缺失 AnyThinkSDK 链接条目都说明 Pods 出问题
if [ "${WEAK_MISSING_COUNT}" -gt 0 ]; then
  exit 1
fi
echo "   ✅ AnyThinkSDK 弱链接 patch 完成（本次替换 ${WEAK_PATCHED_COUNT}，幂等跳过 ${WEAK_ALREADY_COUNT}）"

# =========================
# ToBid 静态归档隔离（关键步骤）
# ----------------------------
# 根本问题：ToBid-iOS-RC 内的 WindMillSDK / WindSDK / WindFoundation 都是 static archive
# （伪装成 framework 的 .a，filetype=MH_OBJECT）。构建期 use_frameworks! :linkage => :static
# 会让 CocoaPods 把 -framework "WindMillSDK" 等写进 OTHER_LDFLAGS，ld 会把全部对象文件
# （3600+）合并进 flame_sdk_ios.framework binary（9.4 MB 污染）。
#
# 解决（两步）：
#   1) pod install 完成后，从 Pods/Target Support Files 下的 xcconfig 中剔除
#      -framework "WindMillSDK|WindSDK|WindFoundation"，并追加 -undefined dynamic_lookup，
#      让 WindMill 符号留为未定义，运行期由 ToBid-iOS-RC pod 解析。
#   2) 临时隐藏 ToBid 三个静态归档二进制（加 .flame_hidden 后缀），让 ld 找不到归档文件，
#      但 Headers/Modules 仍在（编译期 #import <WindMillSDK/WindMillSDK.h> 仍可解析）。
#      构建结束后恢复原名。
# =========================
echo "🧩 single-binary: 隔离 ToBid 静态归档（防止 -ObjC 自动加载 WindMill 全部符号）"
PATCHED_COUNT=0
if [ -d "$PODS_XCCONFIG_DIR" ]; then
  for XC in "$PODS_XCCONFIG_DIR"/*.xcconfig; do
    [ -f "$XC" ] || continue
    if grep -qE 'WindMillSDK|WindSDK|WindFoundation|ToBid-iOS-RC' "$XC"; then
      # 1) 从 OTHER_LDFLAGS 剔除 -framework "WindMillSDK|WindSDK|WindFoundation"
      sed -i '' -E 's/-framework "(WindMillSDK|WindSDK|WindFoundation)"[[:space:]]*//g' "$XC"
      # 2) 追加 -undefined dynamic_lookup（让 WindMill 符号留为未定义，运行期由 ToBid pod 解析）
      if ! grep -q 'dynamic_lookup' "$XC"; then
        sed -i '' -E 's|^(OTHER_LDFLAGS[[:space:]]*=[[:space:]]*.*)$|\1 -undefined dynamic_lookup|' "$XC"
      fi
      PATCHED_COUNT=$((PATCHED_COUNT + 1))
      echo "   ✏️  patched $(basename "$XC")"
    fi
  done
fi
if [ "${PATCHED_COUNT}" -eq 0 ]; then
  echo "   ⚠️  未找到含 Wind*/ToBid flag 的 xcconfig（可能 Pods 结构变化），请检查"
else
  echo "   ✅ 已 patch ${PATCHED_COUNT} 个 xcconfig"
fi

# 临时隐藏 ToBid 静态归档二进制（保留 Headers/Modules 供编译）
TOBID_CORE="./Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core"
HIDDEN_MARKER=".flame_hidden_single_binary"
HIDDEN_LIST=()
if [ -d "$TOBID_CORE" ]; then
  echo "   🫥  临时隐藏 ToBid 静态归档二进制（保留 Headers/Modules 供编译）..."
  while IFS= read -r -d '' bin; do
    if file "$bin" 2>/dev/null | grep -qE "current ar archive|Mach-O.*object"; then
      mv "$bin" "${bin}${HIDDEN_MARKER}"
      HIDDEN_LIST+=("${bin}${HIDDEN_MARKER}")
      echo "      hidden: $(echo "$bin" | sed "s|$TOBID_CORE/||")"
    fi
  done < <(find "$TOBID_CORE" -type f -not -name ".*" -not -name "*.plist" -not -name "*.h" \
                -not -name "*.swiftmodule" -not -name "*.swiftinterface" \
                -not -name "*.json" -not -name "module.modulemap" \
                -not -path "*_CodeSignature*" -not -path "*/dSYMs/*" -print0 2>/dev/null)
  echo "   ✅ 隐藏 ${#HIDDEN_LIST[@]} 个 ToBid 静态归档二进制"
else
  echo "   ⚠️  ToBid Core 目录不存在：$TOBID_CORE"
fi

# 注册退出时恢复钩子（无论构建成功/失败都恢复）
restore_tobid_binaries() {
  if [ "${#HIDDEN_LIST[@]}" -gt 0 ]; then
    echo ""
    echo "🧩 single-binary: 恢复 ToBid 静态归档二进制原名..."
    for hidden in "${HIDDEN_LIST[@]}"; do
      orig="${hidden%${HIDDEN_MARKER}}"
      if [ -f "$hidden" ]; then
        mv "$hidden" "$orig"
      fi
    done
    echo "✅ 恢复完成"
  fi
}
trap restore_tobid_binaries EXIT

# =========================
# 真机 Archive
# 不再注入 FLAME_BUILD_* 宏（Phase 5A.12 mainline：TK/TB 始终全部编译）
# =========================
echo "📦 正在归档真机..."
xcodebuild archive \
  -workspace "${WORKSPACE_NAME}" \
  -scheme "${SCHEME_NAME}" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "${IOS_ARCHIVE_PATH}" \
  SKIP_INSTALL=NO \
  IPHONEOS_DEPLOYMENT_TARGET="${MIN_IOS_VERSION}" \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) COCOAPODS=1'

# =========================
# 模拟器 Archive
# 注意：AnyThinkBeiZiAdapter / AnyThinkSigmobAdapter 等国产广告 adapter 的
# xcframework 只提供 x86_64 模拟器切片（无 arm64 模拟器），因此模拟器产物
# 只归档 x86_64 架构。
# =========================
echo "📦 正在归档模拟器..."
xcodebuild archive \
  -workspace "${WORKSPACE_NAME}" \
  -scheme "${SCHEME_NAME}" \
  -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "${SIM_ARCHIVE_PATH}" \
  ARCHS="x86_64" \
  SKIP_INSTALL=NO \
  IPHONEOS_DEPLOYMENT_TARGET="${MIN_IOS_VERSION}" \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) COCOAPODS=1'

# =========================
# 合并 XCFramework
# =========================
echo "🛠️ 合并 XCFramework..."
xcodebuild -create-xcframework \
  -framework "${IOS_ARCHIVE_PATH}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -framework "${SIM_ARCHIVE_PATH}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -output "${XCFRAMEWORK_OUTPUT}"

# =========================
# 构建完成后清理
# =========================
# 删除 .framework 内部不该存在的文件（.sh 会导致 codesign 失败，.podspec 是冗余文件）
find "${XCFRAMEWORK_OUTPUT}" -type f \( -name "*.sh" -o -name "*.podspec" \) -delete

# 中间 xcarchive 清理：正式产物已在 xcframework 内
echo "🧹 清理中间 xcarchive..."
rm -rf ./Archives

# 剥离所有 framework 内嵌的 bitcode（Apple 已废弃 bitcode，App Store 不接受含 bitcode 的二进制）
echo "🧹 剥离 bitcode..."
while IFS= read -r -d '' binary; do
  echo "  stripping bitcode: $(basename "$(dirname "$binary")")"
  xcrun bitcode_strip "$binary" -r -o "$binary"
done < <(find "${XCFRAMEWORK_OUTPUT}" -type f -perm +111 \
  ! -name "*.dsym" ! -name "*.plist" ! -name "Info.plist" \
  -path "*/Frameworks/*.framework/*" -print0 2>/dev/null)
echo "✅ bitcode 剥离完成"

# =========================
# 符号校验：确认 single-binary 纯净
# =========================
CHECK_BINARY=$(find "${XCFRAMEWORK_OUTPUT}" -path "*ios-arm64*/${FRAMEWORK_NAME}" -type f 2>/dev/null | head -1)
if [ -n "$CHECK_BINARY" ]; then
  echo ""
  echo "🔍 符号校验（single-binary）..."
  BIN_SIZE=$(du -h "$CHECK_BINARY" | cut -f1)
  echo "   二进制体积: ${BIN_SIZE}"

  # 1) 期望符号：Flame core 全套
  echo "   --- 期望符号（Flame core）---"
  for sym in FlameSdk FlameLogger FlameMediationRouter FlameMediationRegistry FlameAdapterManager FlameConfigManager; do
    cnt=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_${sym}")
    cnt=${cnt:-0}
    if [ "${cnt}" -gt 0 ]; then
      echo "   ✅ ${sym}: ${cnt} 个"
    else
      echo "   ❌ ${sym}: 缺失"
    fi
  done

  # 2) 期望符号：TK 平台胶水（始终编译）
  echo "   --- 期望符号（TK 平台胶水）---"
  for sym in FlameTKProvider AtRewardAdapter AtSplashAdapter AtInterstitialAdapter AtBannerAdapter AtNativeAdapter AtNativeSelfRenderView; do
    cnt=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_${sym}")
    cnt=${cnt:-0}
    if [ "${cnt}" -gt 0 ]; then
      echo "   ✅ ${sym}: ${cnt} 个"
    else
      echo "   ❌ ${sym}: 缺失"
    fi
  done

  # 3) 期望符号：TB 平台胶水（始终编译）
  echo "   --- 期望符号（TB 平台胶水）---"
  for sym in FlameTBProvider TbRewardAdapter; do
    cnt=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_${sym}")
    cnt=${cnt:-0}
    if [ "${cnt}" -gt 0 ]; then
      echo "   ✅ ${sym}: ${cnt} 个"
    else
      echo "   ❌ ${sym}: 缺失"
    fi
  done

  # 4) +load 符号（两个 Provider 都应自动注册）
  echo "   --- +load 自动注册符号 ---"
  TK_LOAD=$(nm "$CHECK_BINARY" 2>/dev/null | grep -cE "\+\[FlameTKProvider load\]")
  TB_LOAD=$(nm "$CHECK_BINARY" 2>/dev/null | grep -cE "\+\[FlameTBProvider load\]")
  echo "   +[FlameTKProvider load]: ${TK_LOAD:-0}"
  echo "   +[FlameTBProvider load]: ${TB_LOAD:-0}"

  # 5) 污染检测：三方广告源 SDK 静态符号（应全 0）
  echo "   --- 污染检测（应全部为 0）---"
  # 注意：grep -c 在 0 匹配时返回 exit 1，在 set -e 下会中止脚本。
  # 用 `|| true` 让管道 exit 0，再统一用 ${VAR:-0} 兜底（grep -c 输出本身已是数字 0）。
  POLL_ADCS=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AdGain|_OBJC_CLASS_\\\$_BU|_OBJC_CLASS_\\\$_CSJ|_OBJC_CLASS_\\\$_BaiduMob|_OBJC_CLASS_\\\$_GDTMob|_OBJC_CLASS_\\\$_KSAd|_OBJC_CLASS_\\\$_FSUnion|_OBJC_CLASS_\\\$_Sigmob" || true)
  POLL_ADCS=${POLL_ADCS:-0}
  POLL_WIND=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "WindMillSDK|WindMillAds|_OBJC_CLASS_\\\$_WindMillSDK|_OBJC_CLASS_\\\$_WindFoundation|_OBJC_CLASS_\\\$_WindSDK" || true)
  POLL_WIND=${POLL_WIND:-0}
  POLL_AT=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AT" || true)
  POLL_AT=${POLL_AT:-0}
  if [ "${POLL_ADCS}" -eq 0 ]; then
    echo "   ✅ 无三方广告源 SDK 静态符号（AdGain/BU/CSJ/Baidu/GDT/KS/FS/Sigmob）"
  else
    echo "   ❌ 三方广告源 SDK 静态符号: ${POLL_ADCS}"
  fi
  if [ "${POLL_WIND}" -eq 0 ]; then
    echo "   ✅ 未静态打入 ToBid/WindMill 实现"
  else
    echo "   ⚠️  ToBid/WindMill 实现符号: ${POLL_WIND}（应通过 podspec dependency 接入期解析）"
  fi
  echo "   （参考）AnyThink AT* 静态定义符号: ${POLL_AT}（应 0，AnyThink 是动态依赖）"

  # 6) otool -L 动态依赖
  echo "   --- （参考）otool -L 动态依赖 ---"
  # AnyThinkSDK 弱链接产物断言（Phase 5A.13 Step 1.2B 收口）
  # 要求：otool -l 必须 LC_LOAD_WEAK_DYLIB（不能是 LC_LOAD_DYLIB）；otool -L 必须显示 weak 标记。
  # 若此处失败，说明 xcconfig patch 未生效，TB App 仍会被 dyld 强加载 AnyThinkSDK → 弹窗回归。
  if otool -L "$CHECK_BINARY" 2>/dev/null | grep -qE 'AnyThinkSDK\.framework/AnyThinkSDK.*weak'; then
    echo "   ✅ AnyThinkSDK 动态依赖（otool -L 显示 weak 标记）"
  else
    echo "❌ AnyThinkSDK 未呈现弱链接（otool -L 缺少 weak 标记）"
    otool -L "$CHECK_BINARY" 2>/dev/null | grep -E "AnyThinkSDK" | sed 's/^/      /'
    echo "   → TB App 会被 dyld 强加载 AnyThinkSDK → 弹窗回归，构建中止"
    exit 1
  fi
  # load command 层面再次确认（LC_LOAD_WEAK_DYLIB 而非 LC_LOAD_DYLIB）
  if otool -l "$CHECK_BINARY" 2>/dev/null | awk '/cmd LC_LOAD_WEAK_DYLIB/{found=weak=1} weak&&/AnyThinkSDK/{print; exit}' | grep -q "AnyThinkSDK"; then
    echo "   ✅ AnyThinkSDK LC_LOAD_WEAK_DYLIB（load command 层面确认）"
  else
    echo "❌ AnyThinkSDK load command 不是 LC_LOAD_WEAK_DYLIB"
    otool -l "$CHECK_BINARY" 2>/dev/null | grep -B 1 "AnyThinkSDK" | sed 's/^/      /'
    exit 1
  fi
  if otool -L "$CHECK_BINARY" 2>/dev/null | grep -qE "WindMill|WindSDK|WindFoundation"; then
    echo "   ⚠️  发现 WindMill/WindSDK/WindFoundation 动态依赖（疑似未隔离干净）"
  else
    echo "   ✅ 无 ToBid/WindMill 动态依赖（静态归档已隔离，podspec 公共依赖提供）"
  fi
  if otool -L "$CHECK_BINARY" 2>/dev/null | grep -q "OpenSSL"; then
    echo "   ✅ OpenSSL 动态依赖（podspec 公共依赖提供）"
  fi

  # 7) 资源 bundle 污染检查
  POLLUTED_BUNDLES=$(find "${XCFRAMEWORK_OUTPUT}" -maxdepth 3 \( -name "*.bundle" -o -name "*.metallib" \) 2>/dev/null | head -20)
  if [ -n "$POLLUTED_BUNDLES" ]; then
    echo "   ⚠️  警告：framework 内出现三方资源 bundle/metallib："
    echo "$POLLUTED_BUNDLES" | sed 's/^/      /'
  else
    echo "   ✅ framework 内无三方资源 bundle/metallib"
  fi
fi

echo ""
echo "✅ XCFramework 构建完成（single-binary）：${XCFRAMEWORK_OUTPUT}"

# ============================================================
# 复制到开发仓库根目录（podspec vendored_frameworks 引用根目录路径）
# ------------------------------------------------------------
# podspec 的 s.vendored_frameworks = 'flame_sdk_ios.xcframework'（根目录，无 build/ 前缀），
# 对应二进制分发仓库 javaice007/flame_sdk_ios 的 tag 归档结构（xcframework 在根目录）。
# 本地开发 :path => 模式 pod install 时，CocoaPods 在仓库根目录查找 vendored_frameworks，
# 因此构建完成后必须复制到根目录（与 build/ 下的产物同步，不替换）。
# build/ 目录继续被 .gitignore 忽略，仅用于本地开发；根目录副本也不进 git（已加入 .gitignore）。
# ============================================================
ROOT_XCFRAMEWORK="flame_sdk_ios.xcframework"
rm -rf "${ROOT_XCFRAMEWORK}"
cp -R "${XCFRAMEWORK_OUTPUT}" "${ROOT_XCFRAMEWORK}"
echo "📦 已复制到根目录：${ROOT_XCFRAMEWORK}（本地开发用，不进 git）"
