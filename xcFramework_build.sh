#!/bin/bash
set -e

# =========================
# 基础配置
# =========================
WORKSPACE_NAME="flame_sdk_ios.xcworkspace"
SCHEME_NAME="flame_sdk_ios"
FRAMEWORK_NAME="flame_sdk_ios"
OUTPUT_DIR="./build"
MIN_IOS_VERSION="13.0"

IOS_ARCHIVE_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}_ios"
SIM_ARCHIVE_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}_sim"
XCFRAMEWORK_OUTPUT="${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"

# =========================
# 深度清理缓存
# =========================
rm -rf ~/Library/Developer/Xcode/DerivedData/${FRAMEWORK_NAME}-*
rm -rf "${OUTPUT_DIR}"

# =========================
# 真机 Archive
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
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# =========================
# 模拟器 Archive
# =========================
echo "📦 正在归档模拟器..."
xcodebuild archive \
  -workspace "${WORKSPACE_NAME}" \
  -scheme "${SCHEME_NAME}" \
  -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "${SIM_ARCHIVE_PATH}" \
  ARCHS="x86_64 arm64" \
  SKIP_INSTALL=NO \
  IPHONEOS_DEPLOYMENT_TARGET="${MIN_IOS_VERSION}" \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# =========================
# 合并 XCFramework
# =========================
echo "🛠️ 合并 XCFramework..."
xcodebuild -create-xcframework \
  -framework "${IOS_ARCHIVE_PATH}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -framework "${SIM_ARCHIVE_PATH}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -output "${XCFRAMEWORK_OUTPUT}"

# ====== 构建完成后清理 ======
# 1. 删除 .framework 内部不该存在的文件（.sh 会导致 codesign 失败，.podspec 是冗余文件）
find "${XCFRAMEWORK_OUTPUT}" -type f \( -name "*.sh" -o -name "*.podspec" \) -delete

# 2. 剥离所有 framework 内嵌的 bitcode（Apple 已废弃 bitcode，App Store 不接受含 bitcode 的二进制）
#    遍历 xcframework 中所有 .framework 的主二进制，使用 bitcode_strip 去除 __LLVM 段
echo "🧹 剥离 bitcode..."
while IFS= read -r -d '' binary; do
  echo "  stripping bitcode: $(basename "$(dirname "$binary")")"
  xcrun bitcode_strip "$binary" -r -o "$binary"
done < <(find "${XCFRAMEWORK_OUTPUT}" -type f -perm +111 \
  ! -name "*.dsym" ! -name "*.plist" ! -name "Info.plist" \
  -path "*/Frameworks/*.framework/*" -print0 2>/dev/null)
echo "✅ bitcode 剥离完成"

echo "✅ XCFramework 构建完成：${XCFRAMEWORK_OUTPUT}"
