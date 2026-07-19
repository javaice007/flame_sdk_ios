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
