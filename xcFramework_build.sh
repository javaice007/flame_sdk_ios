#!/bin/bash
set -e

# ============================================================
# xcFramework_build.sh — 多变体互斥构建脚本
# ------------------------------------------------------------
# 用法：
#   ./xcFramework_build.sh        # 默认 = tk
#   ./xcFramework_build.sh tk     # 构建 TK 默认包 → build/tk/flame_sdk_ios.xcframework
#   ./xcFramework_build.sh tb     # 构建 TB 包     → build/tb/flame_sdk_ios.xcframework
#   ./xcFramework_build.sh core   # 构建 Core 包  → build/core/flame_sdk_ios.xcframework
#                                 #   （Phase 5A.10 Step 1：平台中立 Thin Core Binary，
#                                 #    不含 AnyThink/ToBid/WindMill/任何广告源 SDK）
#   ./xcFramework_build.sh core-named
#                                 #   Phase 5A.10 Step 2B：构建改名 Core binary
#                                 #   → build/core_named/flame_sdk_ios_core.xcframework
#                                 #   framework/module/install name 均为 flame_sdk_ios_core
#                                 #   用于方案 D（双 podspec + 单内部 core binary + 单 pod 接入）：
#                                 #   pod 名仍为 flame_sdk_ios/flame_sdk_ios_tb，
#                                 #   但内部 vendored framework 改名避免同名 module 遮蔽
#
# 依赖入口是唯一的 Podfile，通过环境变量 FLAME_SDK_VARIANT=tk|tb|core 切换构建依赖。
# 各产物 framework/module 名均为 flame_sdk_ios（同名，接入方 import 不变）
# 各变体互斥，不能同时接入（同 module 名天然保证）
# ============================================================

# =========================
# 变体解析
# =========================
VARIANT="${1:-tk}"
if [ "$VARIANT" != "tk" ] && [ "$VARIANT" != "tb" ] && [ "$VARIANT" != "core" ] && [ "$VARIANT" != "core-named" ]; then
  echo "❌ 未知变体: $VARIANT（仅支持 tk / tb / core / core-named）"
  exit 1
fi

echo "=========================================="
echo "  构建 Flame SDK — 变体: $VARIANT"
echo "=========================================="

# 根据变体选择构建宏与输出子目录（Podfile 通过 FLAME_SDK_VARIANT 环境变量切换，无需 cp）
if [ "$VARIANT" = "tk" ]; then
  BUILD_MACRO="FLAME_BUILD_TK=1"
  VARIANT_OUTPUT_SUBDIR="tk"
elif [ "$VARIANT" = "tb" ]; then
  BUILD_MACRO="FLAME_BUILD_TB=1"
  VARIANT_OUTPUT_SUBDIR="tb"
elif [ "$VARIANT" = "core-named" ]; then
  # core-named：先用 FLAME_BUILD_CORE 构建（与 core 相同），构建后改名
  BUILD_MACRO="FLAME_BUILD_CORE=1"
  VARIANT_OUTPUT_SUBDIR="core_named"
else
  # core：注入 FLAME_BUILD_CORE=1，不注入 TK/TB
  BUILD_MACRO="FLAME_BUILD_CORE=1"
  VARIANT_OUTPUT_SUBDIR="core"
fi

# =========================
# 基础配置
# =========================
WORKSPACE_NAME="flame_sdk_ios.xcworkspace"
SCHEME_NAME="flame_sdk_ios"
FRAMEWORK_NAME="flame_sdk_ios"
OUTPUT_DIR="./build/${VARIANT_OUTPUT_SUBDIR}"
# 部署目标与 Podfile / podspec 保持一致（统一 13.0）
MIN_IOS_VERSION="13.0"

IOS_ARCHIVE_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}_ios"
SIM_ARCHIVE_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}_sim"
XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"

# =========================
# 干净 pod install（环境变量驱动唯一 Podfile）
# 避免上一个变体的 Pods 残留污染本次构建
# =========================
# 清理旧 Pods 安装，避免变体间残留（lock/Manifest/xcconfig 全部重建）
echo "🧹 清理旧 Pods 安装..."
pod deintegrate >/dev/null 2>&1 || true
rm -rf Pods Podfile.lock

echo "📦 pod install（FLAME_SDK_VARIANT=${VARIANT}）..."
FLAME_SDK_VARIANT="$VARIANT" pod install
# =========================
# 深度清理缓存
# =========================
rm -rf ~/Library/Developer/Xcode/DerivedData/${FRAMEWORK_NAME}-*
rm -rf "${OUTPUT_DIR}"

# =========================
# 真机 Archive
# 通过 GCC_PREPROCESSOR_DEFINITIONS 注入构建宏（不改 pbxproj）
# =========================
echo "📦 正在归档真机（${BUILD_MACRO}）..."
xcodebuild archive \
  -workspace "${WORKSPACE_NAME}" \
  -scheme "${SCHEME_NAME}" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "${IOS_ARCHIVE_PATH}" \
  SKIP_INSTALL=NO \
  IPHONEOS_DEPLOYMENT_TARGET="${MIN_IOS_VERSION}" \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) COCOAPODS=1 '"${BUILD_MACRO}"

# =========================
# 模拟器 Archive
# 注意：AnyThinkBeiZiAdapter / AnyThinkSigmobAdapter 等国产广告 adapter 的
# xcframework 只提供 x86_64 模拟器切片（无 arm64 模拟器），因此模拟器产物
# 只归档 x86_64 架构，与已发布的 flame_sdk_ios.xcframework 结构一致。
# =========================
echo "📦 正在归档模拟器（${BUILD_MACRO}）..."
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
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) COCOAPODS=1 '"${BUILD_MACRO}"

# =========================
# 合并 XCFramework
# =========================
echo "🛠️ 合并 XCFramework..."
xcodebuild -create-xcframework \
  -framework "${IOS_ARCHIVE_PATH}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -framework "${SIM_ARCHIVE_PATH}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -output "${XCFRAMEWORK_OUTPUT}"

# =========================
# core-named 改名（Phase 5A.10 Step 2B）
# Xcode 工程产物名固定为 flame_sdk_ios，这里在 xcframework 创建后改名：
#   framework 目录、binary、Info.plist、modulemap、umbrella header、install name
# 目的：让内部 core binary 的 module 名 = flame_sdk_ios_core，
#      与外层 pod 名 flame_sdk_ios/flame_sdk_ios_tb 区分，避免同名 module 遮蔽。
# =========================
if [ "$VARIANT" = "core-named" ]; then
  CORE_NEW_NAME="flame_sdk_ios_core"
  echo "🏷️  core-named 改名：flame_sdk_ios → ${CORE_NEW_NAME}"

  for FW_DIR in "${XCFRAMEWORK_OUTPUT}"/*/*.framework; do
    [ -d "$FW_DIR" ] || continue
    FW_PARENT=$(dirname "$FW_DIR")

    # 1. binary 改名 + install name 改写
    if [ -f "${FW_DIR}/${FRAMEWORK_NAME}" ]; then
      mv "${FW_DIR}/${FRAMEWORK_NAME}" "${FW_DIR}/${CORE_NEW_NAME}"
      # install_name_tool -id 改 LC_ID_DYLIB（@rpath/flame_sdk_ios.framework/flame_sdk_ios → ...core）
      install_name_tool -id "@rpath/${CORE_NEW_NAME}.framework/${CORE_NEW_NAME}" "${FW_DIR}/${CORE_NEW_NAME}"
    fi

    # 2. umbrella header flame_sdk_ios.h → flame_sdk_ios_core.h（若存在）
    if [ -f "${FW_DIR}/Headers/${FRAMEWORK_NAME}.h" ]; then
      mv "${FW_DIR}/Headers/${FRAMEWORK_NAME}.h" "${FW_DIR}/Headers/${CORE_NEW_NAME}.h"
    fi

    # 2.1 umbrella header 内部 #import <flame_sdk_ios/...> → <flame_sdk_ios_core/...>
    #     （umbrella 里用尖括号引用同 framework 公共头，改名后模块名变了，必须同步改）
    UMBRELLA="${FW_DIR}/Headers/${CORE_NEW_NAME}.h"
    if [ -f "$UMBRELLA" ]; then
      sed -i '' "s|<${FRAMEWORK_NAME}/|<${CORE_NEW_NAME}/|g" "$UMBRELLA"
    fi

    # 3. modulemap 改 module 名 + umbrella header 名
    MODULEMAP="${FW_DIR}/Modules/module.modulemap"
    if [ -f "$MODULEMAP" ]; then
      sed -i '' \
        -e "s/framework module ${FRAMEWORK_NAME}/framework module ${CORE_NEW_NAME}/g" \
        -e "s/umbrella header \"${FRAMEWORK_NAME}.h\"/umbrella header \"${CORE_NEW_NAME}.h\"/g" \
        "$MODULEMAP"
    fi

    # 4. Info.plist 改 CFBundleExecutable / CFBundleName
    PLIST="${FW_DIR}/Info.plist"
    if [ -f "$PLIST" ]; then
      /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${CORE_NEW_NAME}" "$PLIST" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Set :CFBundleName ${CORE_NEW_NAME}" "$PLIST" 2>/dev/null || true
    fi

    # 5. framework 目录改名
    mv "$FW_DIR" "${FW_PARENT}/${CORE_NEW_NAME}.framework"
  done

  # 6. xcframework Info.plist 改 LibraryPath / BinaryPath
  XCFW_PLIST="${XCFRAMEWORK_OUTPUT}/Info.plist"
  if [ -f "$XCFW_PLIST" ]; then
    # LibraryPath: flame_sdk_ios.framework → flame_sdk_ios_core.framework
    # BinaryPath:  flame_sdk_ios.framework/flame_sdk_ios → flame_sdk_ios_core.framework/flame_sdk_ios_core
    /usr/libexec/PlistBuddy -c "Print" "$XCFW_PLIST" >/dev/null 2>&1 && {
      # 用 sed 批量替换（PlistBuddy 对数组元素路径不友好，sed 更稳）
      sed -i '' \
        -e "s|${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}|${CORE_NEW_NAME}.framework/${CORE_NEW_NAME}|g" \
        -e "s|${FRAMEWORK_NAME}.framework|${CORE_NEW_NAME}.framework|g" \
        "$XCFW_PLIST"
    }
  fi

  # 7. xcframework 外层目录改名：flame_sdk_ios.xcframework → flame_sdk_ios_core.xcframework
  XCFW_PARENT=$(dirname "${XCFRAMEWORK_OUTPUT}")
  if [ -d "${XCFW_PARENT}/${FRAMEWORK_NAME}.xcframework" ]; then
    mv "${XCFW_PARENT}/${FRAMEWORK_NAME}.xcframework" "${XCFW_PARENT}/${CORE_NEW_NAME}.xcframework"
    # 更新后续符号校验用的输出路径
    XCFRAMEWORK_OUTPUT="${XCFW_PARENT}/${CORE_NEW_NAME}.xcframework"
  fi

  echo "✅ core-named 改名完成"

  # =========================
  # core-named 补暴露内部头（Phase 5A.10 Step 2B）
  # Core binary Headers/ 默认只含 10 个公共 API。平台源码插件还需要 12 个内部头
  # （mediation 协议 + AdapterManager/ConfigManager/ErrorCode/Logger）。
  # 方案 D 要求「平台源码依赖 core binary 的 Headers，不依赖 core 源码树」，
  # 因此把这 12 个内部头从源码树复制到 framework Headers/。
  # 这 12 个头只用 #import "..."（同 framework 内相对解析），互相 + 公共 API 已自包含。
  # modulemap 的 module * { export * } 会自动把它们作为子模块暴露。
  # =========================
  echo "📋 core-named 补暴露 12 个内部头到 Headers/..."
  INTERNAL_HEADERS=(
    "flame_sdk_ios/mediation/FlameMediationRegistry.h"
    "flame_sdk_ios/mediation/FlameMediationProvider.h"
    "flame_sdk_ios/mediation/FlameMediationRouter.h"
    "flame_sdk_ios/mediation/FlameRewardAdapterProtocol.h"
    "flame_sdk_ios/mediation/FlameSplashAdapterProtocol.h"
    "flame_sdk_ios/mediation/FlameInterstitialAdapterProtocol.h"
    "flame_sdk_ios/mediation/FlameBannerAdapterProtocol.h"
    "flame_sdk_ios/mediation/FlameNativeAdapterProtocol.h"
    "flame_sdk_ios/adapter/FlameAdapterManager.h"
    "flame_sdk_ios/core/FlameConfigManager.h"
    "flame_sdk_ios/core/FlameErrorCode.h"
    "flame_sdk_ios/core/FlameLogger.h"
  )
  for FW_DIR in "${XCFRAMEWORK_OUTPUT}"/*/*.framework; do
    [ -d "$FW_DIR" ] || continue
    for SRC_H in "${INTERNAL_HEADERS[@]}"; do
      H_NAME=$(basename "$SRC_H")
      cp "./${SRC_H}" "${FW_DIR}/Headers/${H_NAME}"
    done
  done
  echo "✅ 内部头补暴露完成"
fi

# ====== 构建完成后清理 ======
# 删除 .framework 内部不该存在的文件（.sh 会导致 codesign 失败，.podspec 是冗余文件）
find "${XCFRAMEWORK_OUTPUT}" -type f \( -name "*.sh" -o -name "*.podspec" \) -delete

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
# 符号校验：确认变体纯净
# =========================
# core-named 改名后 binary 名为 flame_sdk_ios_core，其余变体仍为 flame_sdk_ios
if [ "$VARIANT" = "core-named" ]; then
  BIN_NAME="flame_sdk_ios_core"
else
  BIN_NAME="${FRAMEWORK_NAME}"
fi
TK_BINARY=$(find "${XCFRAMEWORK_OUTPUT}" -path "*ios-arm64*/${BIN_NAME}" -type f 2>/dev/null | head -1)
if [ -n "$TK_BINARY" ]; then
  echo ""
  echo "🔍 符号校验（${VARIANT} 变体）..."
  # 体积提示（异常膨胀通常意味三方符号被静态合并）
  BIN_SIZE=$(du -h "$TK_BINARY" | cut -f1)
  echo "   二进制体积: ${BIN_SIZE}"

  # 统一污染检测模式：TK 变体不应包含任何三方广告源 SDK 符号
  # TB 变体不应包含 AnyThink / TK adapter 符号
  # CORE 变体不应包含任何三方广告 SDK 符号（最严格：连 AT* / FlameTKProvider 都不能有）
  if [ "$VARIANT" = "tk" ]; then
    # TK 变体：Flame 源码只依赖 AnyThinkSDK，不应静态嵌入任何三方广告源 SDK
    # 构建期 Podfile 只含 OpenSSL + AnyThinkiOS，运行时广告源依赖在 podspec 分发期声明
    # 以下任一非零说明三方 SDK 被静态合并进了 framework binary（archive 期 static link 污染）
    POLLUTION_TOBID=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "WindMillSDK|WindMillAds|WindMillRewardVideo|_OBJC_CLASS_\\\$_FlameTBProvider|_OBJC_CLASS_\\\$_TbRewardAdapter")
    POLLUTION_ADCS=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AdGain|_OBJC_CLASS_\\\$_BU|_OBJC_CLASS_\\\$_CSJ")
    POLLUTION_WIND=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_Wind|_OBJC_CLASS_\\\$_WindMill|_OBJC_CLASS_\\\$_WindFoundation")
    POLLUTION_OTHER=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_BaiduMob|_OBJC_CLASS_\\\$_GDTMob|_OBJC_CLASS_\\\$_KSAd|_OBJC_CLASS_\\\$_FSUnion|_OBJC_CLASS_\\\$_Sigmob")
    POLLUTION_TOBID=${POLLUTION_TOBID:-0}
    POLLUTION_ADCS=${POLLUTION_ADCS:-0}
    POLLUTION_WIND=${POLLUTION_WIND:-0}
    POLLUTION_OTHER=${POLLUTION_OTHER:-0}
    TOTAL_POLLUTION=$((POLLUTION_TOBID + POLLUTION_ADCS + POLLUTION_WIND + POLLUTION_OTHER))

    echo "   TK 污染符号统计：ToBid=${POLLUTION_TOBID} AdGain/BU/CSJ=${POLLUTION_ADCS} Wind=${POLLUTION_WIND} 其他(Baidu/GDT/KS/FS/Sigmob)=${POLLUTION_OTHER}"
    if [ "${TOTAL_POLLUTION}" -gt 0 ]; then
      echo "❌ 严重：TK 二进制被三方广告源 SDK 静态合并污染（共 ${TOTAL_POLLUTION} 个符号）"
      echo "    请检查：1) Podfile TK 变体是否还残留 AnyThinkMediation*/AdGain/FSUnion 依赖"
      echo "           2) use_frameworks! :linkage => :static 是否把三方静态框架合并进了 binary"
      echo "           3) Pods/Podfile.lock 是否仍是旧版本"
    else
      echo "✅ OK: TK 二进制无三方广告源 SDK 符号（ToBid/AdGain/BU/CSJ/Wind/Baidu/GDT/KS/FS/Sigmob）"
    fi

    # AnyThink SDK 作为构建期依赖，二进制内可以有 AT* 符号引用，但不应该把整个 AnyThinkSDK 静态嵌入
    # 这部分仅做信息提示，不阻塞
    ANYTHINK_COUNT=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AT")
    ANYTHINK_COUNT=${ANYTHINK_COUNT:-0}
    echo "   （参考）AnyThink AT* 符号数: ${ANYTHINK_COUNT}（Flame adapter 胶水层引用，正常）"
  elif [ "$VARIANT" = "tb" ]; then
    # TB 变体应含 WindMill（已内置），不应含 TK adapter / FlameTKProvider
    WINDMILL_COUNT=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "WindMillSDK|WindMillAds")
    WINDMILL_COUNT=${WINDMILL_COUNT:-0}
    echo "✅ TB 二进制含 ${WINDMILL_COUNT} 个 ToBid WindMill 符号（预期 >0，自包含模式）"
    TK_COUNT=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AtRewardAdapter|_OBJC_CLASS_\\\$_AtSplashAdapter|_OBJC_CLASS_\\\$_AtInterstitialAdapter|_OBJC_CLASS_\\\$_AtBannerAdapter|_OBJC_CLASS_\\\$_AtNativeAdapter|_OBJC_CLASS_\\\$_FlameTKProvider")
    TK_COUNT=${TK_COUNT:-0}
    if [ "${TK_COUNT}" -gt 0 ]; then
      echo "❌ 严重：TB 二进制含 ${TK_COUNT} 个 TK/AT* 符号（预期为 0）"
    else
      echo "✅ OK: TB 二进制无 TK / AT* adapter 符号"
    fi
    ANYTHINK_POLLUTION=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AT")
    ANYTHINK_POLLUTION=${ANYTHINK_POLLUTION:-0}
    if [ "${ANYTHINK_POLLUTION}" -gt 0 ]; then
      echo "❌ 严重：TB 二进制含 ${ANYTHINK_POLLUTION} 个 AnyThink AT* 符号（预期为 0）"
    else
      echo "✅ OK: TB 二进制无 AnyThink AT* 符号"
    fi
  else
    # CORE 变体（Phase 5A.10 Step 1）：最严格校验
    # Core binary 必须零三方广告 SDK 符号，包括：
    #   - AnyThink (AT*)：TK 平台依赖，Core 不应含
    #   - WindMill / Wind / WindFoundation：TB 平台依赖，Core 不应含
    #   - 广告源 SDK：Baidu/GDT/KS/FSUnion/Sigmob/AdGain/BU/CSJ，Core 不应含
    #   - TK/TB 平台 Provider 与 Adapter 类：FlameTKProvider/FlameTBProvider/At*Adapter/TbRewardAdapter
    CORE_POLL_AT=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_AT|AnyThink")
    CORE_POLL_WIND=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_WindMill|_OBJC_CLASS_\\\$_WindFoundation|_OBJC_CLASS_\\\$_WindSDK|WindMillSDK|WindMillAds")
    CORE_POLL_ADS=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_BaiduMob|_OBJC_CLASS_\\\$_GDTMob|_OBJC_CLASS_\\\$_KSAd|_OBJC_CLASS_\\\$_FSUnion|_OBJC_CLASS_\\\$_Sigmob|_OBJC_CLASS_\\\$_AdGain|_OBJC_CLASS_\\\$_BU|_OBJC_CLASS_\\\$_CSJ")
    CORE_POLL_PROVIDER=$(nm -gU "$TK_BINARY" 2>/dev/null | grep -cE "_OBJC_CLASS_\\\$_FlameTKProvider|_OBJC_CLASS_\\\$_FlameTBProvider|_OBJC_CLASS_\\\$_AtRewardAdapter|_OBJC_CLASS_\\\$_AtSplashAdapter|_OBJC_CLASS_\\\$_AtInterstitialAdapter|_OBJC_CLASS_\\\$_AtBannerAdapter|_OBJC_CLASS_\\\$_AtNativeAdapter|_OBJC_CLASS_\\\$_TbRewardAdapter")
    CORE_POLL_AT=${CORE_POLL_AT:-0}
    CORE_POLL_WIND=${CORE_POLL_WIND:-0}
    CORE_POLL_ADS=${CORE_POLL_ADS:-0}
    CORE_POLL_PROVIDER=${CORE_POLL_PROVIDER:-0}
    CORE_TOTAL_POLLUTION=$((CORE_POLL_AT + CORE_POLL_WIND + CORE_POLL_ADS + CORE_POLL_PROVIDER))

    echo "   CORE 污染符号统计：AnyThink=${CORE_POLL_AT} Wind=${CORE_POLL_WIND} 广告源=${CORE_POLL_ADS} 平台Provider/Adapter=${CORE_POLL_PROVIDER}"
    if [ "${CORE_TOTAL_POLLUTION}" -gt 0 ]; then
      echo "❌ 严重：CORE 二进制含三方符号（共 ${CORE_TOTAL_POLLUTION} 个），不再是 thin core"
      echo "    请检查：1) FLAME_BUILD_CORE 是否正确注入（platform 文件应整体置空）"
      echo "           2) adapter/tk, adapter/tb, mediation/tk, mediation/tb 守卫是否含 !defined(FLAME_BUILD_CORE)"
      echo "           3) FlameAdapterManager.m 的 AnyThink import 是否被 CORE 守卫排除"
      echo "           4) Podfile core 变体是否误引入 AnyThink/ToBid"
    else
      echo "✅ OK: CORE 二进制零三方广告 SDK 符号（AnyThink/WindMill/广告源/平台Provider/Adapter 均无）"
    fi

    # otool -L 动态依赖复查：Core 不应依赖 AnyThink/WindMill framework
    echo "   （参考）otool -L 动态依赖复查："
    otool -L "$TK_BINARY" 2>/dev/null | grep -iE "AnyThink|WindMill|WindSDK|WindFoundation|ToBid|Sigmob" && echo "   ⚠️  发现三方动态依赖" || echo "   ✅ 无 AnyThink/WindMill/ToBid 动态依赖"
  fi

  # 资源 bundle 污染检查（三方 SDK 资源不应出现在 framework 内部）
  POLLUTED_BUNDLES=$(find "${XCFRAMEWORK_OUTPUT}" -maxdepth 3 \( -name "*.bundle" -o -name "*.metallib" \) 2>/dev/null | head -20)
  if [ -n "$POLLUTED_BUNDLES" ]; then
    echo "⚠️  警告：framework 内出现三方资源 bundle/metallib："
    echo "$POLLUTED_BUNDLES" | sed 's/^/    /'
  else
    echo "✅ OK: framework 内无三方资源 bundle/metallib"
  fi
fi

echo ""
echo "✅ XCFramework 构建完成（${VARIANT}）：${XCFRAMEWORK_OUTPUT}"
