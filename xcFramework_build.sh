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
# 变体解析（只允许 single-binary）
# =========================
VARIANT="${1:-single-binary}"

if [ "$VARIANT" != "single-binary" ]; then
  echo "❌ 当前分支只支持 single-binary 构建，不再支持 tk/tb/release/三包/双二进制历史入口。"
  echo ""
  echo "   传入参数: $VARIANT"
  echo "   唯一合法参数: single-binary（或不传参数）"
  echo ""
  echo "   用法："
  echo "     ./xcFramework_build.sh                 # 默认 = single-binary"
  echo "     ./xcFramework_build.sh single-binary   # 显式写法"
  echo ""
  echo "   历史入口已废弃（如需回退，见 backup/phase-5a-dual-binary-stable 分支）："
  echo "     tk / tb / core / core-named / tk-plugin / tb-plugin / release / nosdk / dual"
  exit 1
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
MIN_IOS_VERSION="13.0"

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
PODS_XCCONFIG_DIR="./Pods/Target Support Files/Pods-flame_sdk_ios"
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
  POLL_ADCS=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AdGain|_OBJC_CLASS_\\\$_BU|_OBJC_CLASS_\\\$_CSJ|_OBJC_CLASS_\\\$_BaiduMob|_OBJC_CLASS_\\\$_GDTMob|_OBJC_CLASS_\\\$_KSAd|_OBJC_CLASS_\\\$_FSUnion|_OBJC_CLASS_\\\$_Sigmob")
  POLL_ADCS=${POLL_ADCS:-0}
  POLL_WIND=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "WindMillSDK|WindMillAds|_OBJC_CLASS_\\\$_WindMillSDK|_OBJC_CLASS_\\\$_WindFoundation|_OBJC_CLASS_\\\$_WindSDK")
  POLL_WIND=${POLL_WIND:-0}
  POLL_AT=$(nm -gU "$CHECK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AT")
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
  if otool -L "$CHECK_BINARY" 2>/dev/null | grep -q "AnyThinkSDK"; then
    echo "   ✅ AnyThinkSDK 动态依赖（MH_DYLIB 预期行为，podspec 公共依赖提供）"
  else
    echo "   ⚠️  未发现 AnyThinkSDK 动态依赖（AnyThink 符号将依赖 dynamic_lookup 兜底）"
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
