#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_classic_xcodeproj.py — 为 Xcode 15.4 正式 DT13 构建生成 classic(objectVersion 56) pbxproj

背景：仓库 flame_sdk_ios.xcodeproj 是 objectVersion 77（PBXFileSystemSynchronizedRootGroup，
Xcode 16+ 专属），Xcode 15.4 拒绝读取（"future Xcode project file format (77)"）。
本脚本在构建工作副本（git worktree）内生成等价 classic 工程，供 xcFramework_build.sh 正式
DT13 流程使用。不修改仓库冻结状态；本文件随分支提交（P0G §七：build tooling 单独提交）。

用法（在 worktree 根目录）：
    python3 release-tooling/gen_classic_xcodeproj.py
之后照常：pod install → xcFramework_build.sh tb-static（-workspace -scheme 均可解析）。
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "flame_sdk_ios")
TARGET = "flame_sdk_ios"
PROJECT_DIR = os.path.join(ROOT, "flame_sdk_ios.xcodeproj")


def uid(key):
    return hashlib.md5(("flame-classic:" + key).encode()).hexdigest()[:24].upper()


def walk(cur_rel):
    abs_cur = os.path.join(SRC_DIR, cur_rel) if cur_rel else SRC_DIR
    dirs, files = [], []
    for name in sorted(os.listdir(abs_cur)):
        rel = cur_rel + "/" + name if cur_rel else name
        full = os.path.join(abs_cur, name)
        if os.path.isdir(full):
            dirs.append((name, rel))
        else:
            files.append((name, rel))
    return dirs, files


file_refs = []       # (uuid, basename)
group_defs = []      # (uuid, name, path)
group_children = {}  # uuid -> [child uuid]


def build_group(rel, name, path):
    g = uid("group:" + rel)
    dirs, files = walk(rel)
    kids = [uid("file:" + rel + "/" + f[0]) for f in files]
    group_defs.append((g, name, path))
    for fname, frel in files:
        file_refs.append((uid("file:" + rel + "/" + fname), fname))
    for dname, drel in dirs:
        kids.append(build_group(drel, dname, dname))
    group_children[g] = kids
    return g


root_sub = build_group("", TARGET, TARGET)
m_files = [u for u, b in file_refs if b.endswith(".m")]
h_files = [u for u, b in file_refs if b.endswith(".h")]
basename_of = dict(file_refs)

T = uid("target:" + TARGET)
P = uid("project:" + TARGET)
ROOTG = uid("rootgroup")
PROD = uid("product")
SRC_PH = uid("phase:sources")
HDR_PH = uid("phase:headers")
FW_PH = uid("phase:frameworks")
CL_T = uid("cfglist:target")
CL_P = uid("cfglist:project")
CT_D = uid("cfg:t:debug")
CT_R = uid("cfg:t:release")
CP_D = uid("cfg:p:debug")
CP_R = uid("cfg:p:release")

out = []
out.append("// !$*UTF8*$!")
out.append("{")
out.append("\tarchiveVersion = 1;")
out.append("\tclasses = {};")
out.append("\tobjectVersion = 56;")
out.append("\tobjects = {")

out.append("/* Begin PBXBuildFile section */")
for u in m_files:
    out.append("\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s; };" % (uid("bf:" + u), basename_of[u], u))
for u in h_files:
    out.append("\t\t%s /* %s in Headers */ = {isa = PBXBuildFile; fileRef = %s; settings = {ATTRIBUTES = (Public, ); }; };" % (uid("hf:" + u), basename_of[u], u))
out.append("/* End PBXBuildFile section */")
out.append("")

out.append("/* Begin PBXFileReference section */")
out.append("\t\t%s /* %s.framework */ = {isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = %s.framework; sourceTree = BUILT_PRODUCTS_DIR; };" % (PROD, TARGET, TARGET))
for u, b in file_refs:
    ftype = "sourcecode.c.objc" if b.endswith(".m") else "sourcecode.c.h"
    out.append("\t\t%s /* %s */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = %s; path = %s; sourceTree = \"<group>\"; };" % (u, b, ftype, b))
out.append("/* End PBXFileReference section */")
out.append("")

out.append("/* Begin PBXGroup section */")
for g, name, path in group_defs:
    kids = group_children[g]
    kid_lines = "\n".join("\t\t\t\t%s /* child */," % k for k in kids)
    out.append("\t\t%s /* %s */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n%s\n\t\t\t);\n\t\t\tname = %s;\n\t\t\tpath = %s;\n\t\t\tsourceTree = \"<group>\";\n\t\t};" % (g, name, kid_lines, name, path))
out.append("\t\t%s = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t%s /* %s */,\n\t\t\t\t%s /* Products */,\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t};" % (ROOTG, root_sub, TARGET, PROD))
out.append("/* End PBXGroup section */")
out.append("")

out.append("/* Begin PBXNativeTarget section */")
out.append("\t\t%s /* %s */ = {\n\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"%s\" */;\n\t\t\tbuildPhases = (\n\t\t\t\t%s /* Headers */,\n\t\t\t\t%s /* Sources */,\n\t\t\t\t%s /* Frameworks */,\n\t\t\t);\n\t\t\tbuildRules = ();\n\t\t\tdependencies = ();\n\t\t\tname = %s;\n\t\t\tproductName = %s;\n\t\t\tproductReference = %s /* %s.framework */;\n\t\t\tproductType = \"com.apple.product-type.framework\";\n\t\t};" % (T, TARGET, CL_T, TARGET, HDR_PH, SRC_PH, FW_PH, TARGET, TARGET, PROD, TARGET))
out.append("/* End PBXNativeTarget section */")
out.append("")

out.append("/* Begin PBXProject section */")
out.append("\t\t%s /* Project object */ = {\n\t\t\tisa = PBXProject;\n\t\t\tattributes = {\n\t\t\t\tLastUpgradeCheck = 1540;\n\t\t\t\tTargetAttributes = {\n\t\t\t\t\t%s = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;\n\t\t\t\t\t};\n\t\t\t\t};\n\t\t\t};\n\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject \"%s\" */;\n\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n\t\t\tdevelopmentRegion = en;\n\t\t\thasScannedForEncodings = 0;\n\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n\t\t\tmainGroup = %s;\n\t\t\tproductRefGroup = %s;\n\t\t\tprojectDirPath = \"\";\n\t\t\tprojectRoot = \"\";\n\t\t\ttargets = (\n\t\t\t\t%s /* %s */,\n\t\t\t);\n\t\t};" % (P, T, CL_P, TARGET, ROOTG, ROOTG, T, TARGET))
out.append("/* End PBXProject section */")
out.append("")

out.append("/* Begin PBXHeadersBuildPhase section */")
hdr_lines = "\n".join("\t\t\t\t%s /* %s in Headers */," % (uid("hf:" + u), basename_of[u]) for u in h_files)
out.append("\t\t%s /* Headers */ = {\n\t\t\tisa = PBXHeadersBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n%s\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};" % (HDR_PH, hdr_lines))
out.append("/* End PBXHeadersBuildPhase section */")
out.append("")

out.append("/* Begin PBXFrameworksBuildPhase section */")
out.append("\t\t%s /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ();\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};" % FW_PH)
out.append("/* End PBXFrameworksBuildPhase section */")
out.append("")

out.append("/* Begin PBXSourcesBuildPhase section */")
src_lines = "\n".join("\t\t\t\t%s /* %s in Sources */," % (uid("bf:" + u), basename_of[u]) for u in m_files)
out.append("\t\t%s /* Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n%s\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};" % (SRC_PH, src_lines))
out.append("/* End PBXSourcesBuildPhase section */")
out.append("")

out.append("/* Begin XCBuildConfiguration section */")
base_cfg = ("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;\n"
            "\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
            "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n"
            "\t\t\t\tDEFINES_MODULE = YES;\n"
            "\t\t\t\tHEADER_SEARCH_PATHS = \"$(SRCROOT)/flame_sdk_ios/**\";\n"
            "\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n"
            "\t\t\t\tMARKETING_VERSION = 1.0;\n"
            "\t\t\t\tSDKROOT = iphoneos;\n"
            "\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";\n"
            "\t\t\t\tOTHER_LDFLAGS = \"$(inherited)\";\n")
for c, name in ((CT_D, "Debug"), (CT_R, "Release")):
    out.append("\t\t%s /* %s */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n%s\t\t\t};\n\t\t\tname = \"%s\";\n\t\t};" % (c, name, base_cfg, name))
for c, name in ((CP_D, "Debug"), (CP_R, "Release")):
    out.append("\t\t%s /* %s */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t};\n\t\t\tname = \"%s\";\n\t\t};" % (c, name, name))
out.append("/* End XCBuildConfiguration section */")
out.append("")

out.append("/* Begin XCConfigurationList section */")
out.append("\t\t%s /* Build configuration list for PBXProject \"%s\" */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t%s /* Debug */,\n\t\t\t\t%s /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t};" % (CL_P, TARGET, CP_D, CP_R))
out.append("\t\t%s /* Build configuration list for PBXNativeTarget \"%s\" */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t%s /* Debug */,\n\t\t\t\t%s /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t};" % (CL_T, TARGET, CT_D, CT_R))
out.append("/* End XCConfigurationList section */")
out.append("\t};")
out.append("\trootObject = %s /* Project object */;" % P)
out.append("}")

os.makedirs(PROJECT_DIR, exist_ok=True)
with open(os.path.join(PROJECT_DIR, "project.pbxproj"), "w") as f:
    f.write("\n".join(out) + "\n")
print("generated classic pbxproj: %d .m, %d .h -> %s" % (len(m_files), len(h_files), PROJECT_DIR))
