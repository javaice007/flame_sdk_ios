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

echo "✅ XCFramework 构建完成：${XCFRAMEWORK_OUTPUT}"
