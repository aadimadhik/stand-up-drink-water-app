#!/usr/bin/env python3
"""Generate DeskBreak.xcodeproj from the files on disk.

The project is written in the classic OpenStep pbxproj format (objectVersion 56)
rather than Xcode 16's synchronised-folder format, so it opens in Xcode 14
through 26. Re-run after adding or removing source files:

    python3 scripts/generate_xcodeproj.py
"""

import hashlib
import os

APP = "DeskBreak"
BUNDLE_ID = "com.aadim.DeskBreak"
DEPLOYMENT_TARGET = "17.0"
PROJECT_DIR = APP + ".xcodeproj"
SOURCE_ROOT = APP

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".wav": "audio.wav",
    ".xcassets": "folder.assetcatalog",
}


def object_id(key):
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def file_type(name):
    for ext, kind in FILE_TYPES.items():
        if name.endswith(ext):
            return kind
    return "text"


def scan():
    """Walk the app folder, returning (swift sources, resources) relative to it."""
    sources, resources = [], []
    for dirpath, dirnames, filenames in os.walk(SOURCE_ROOT):
        dirnames.sort()
        # Asset catalogs are a single resource, not a folder to descend into.
        dirnames[:] = [d for d in dirnames if not d.endswith(".xcassets")]
        for name in sorted(filenames):
            rel = os.path.relpath(os.path.join(dirpath, name), SOURCE_ROOT)
            if name.endswith(".swift"):
                sources.append(rel)
            elif name.endswith(".wav"):
                resources.append(rel)
    for name in sorted(os.listdir(SOURCE_ROOT)):
        if name.endswith(".xcassets"):
            resources.append(name)
    return sorted(sources), sorted(resources)


def build_tree(paths):
    """Nest relative paths so every folder becomes its own PBXGroup."""
    tree = {"__files__": []}
    for path in paths:
        parts = path.split(os.sep)
        node = tree
        for part in parts[:-1]:
            node = node.setdefault(part, {"__files__": []})
        node["__files__"].append(parts[-1])
    return tree


def emit_groups(tree, prefix, lines, group_ids):
    """Depth-first, so a child group exists before its parent references it."""
    children = []
    for name in sorted(key for key in tree if key != "__files__"):
        child_prefix = os.path.join(prefix, name) if prefix else name
        emit_groups(tree[name], child_prefix, lines, group_ids)
        children.append((group_ids[child_prefix], name))

    for name in sorted(tree["__files__"]):
        rel = os.path.join(prefix, name) if prefix else name
        children.append((object_id("file:" + rel), name))

    group_id = object_id("group:" + prefix) if prefix else object_id("group:root-app")
    group_ids[prefix] = group_id
    display = os.path.basename(prefix) if prefix else APP
    listing = "\n".join("\t\t\t\t%s /* %s */," % pair for pair in children)

    lines.append(
        "\t\t%s /* %s */ = {\n"
        "\t\t\tisa = PBXGroup;\n"
        "\t\t\tchildren = (\n%s\n\t\t\t);\n"
        "\t\t\tpath = %s;\n"
        "\t\t\tsourceTree = \"<group>\";\n"
        "\t\t};\n" % (group_id, display, listing, display)
    )
    return group_id


PROJECT_BUILD_SETTINGS = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = %s;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
""" % DEPLOYMENT_TARGET

TARGET_BUILD_SETTINGS = """\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = DeskBreak;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIStatusBarStyle = UIStatusBarStyleDefault;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = %s;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
""" % BUNDLE_ID

DEBUG_ONLY = """\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""

RELEASE_ONLY = """\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;
"""


def main():
    sources, resources = scan()
    all_files = sources + resources

    ids = {name: object_id(name) for name in (
        "project", "target", "product", "group:products", "group:root",
        "phase:sources", "phase:resources", "phase:frameworks",
        "configlist:project", "configlist:target")}

    out = ["// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n"
           "\tobjectVersion = 56;\n\tobjects = {\n"]

    out.append("\n/* Begin PBXBuildFile section */\n")
    for rel in all_files:
        name = os.path.basename(rel)
        phase = "Sources" if rel in sources else "Resources"
        out.append("\t\t%s /* %s in %s */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n"
                   % (object_id("build:" + rel), name, phase, object_id("file:" + rel), name))
    out.append("/* End PBXBuildFile section */\n")

    out.append("\n/* Begin PBXFileReference section */\n")
    out.append("\t\t%s /* %s.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application;"
               " includeInIndex = 0; path = %s.app; sourceTree = BUILT_PRODUCTS_DIR; };\n"
               % (ids["product"], APP, APP))
    for rel in all_files:
        name = os.path.basename(rel)
        out.append("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s;"
                   " path = %s; sourceTree = \"<group>\"; };\n"
                   % (object_id("file:" + rel), name, file_type(name), name))
    out.append("/* End PBXFileReference section */\n")

    out.append("\n/* Begin PBXFrameworksBuildPhase section */\n"
               "\t\t%s /* Frameworks */ = {\n"
               "\t\t\tisa = PBXFrameworksBuildPhase;\n"
               "\t\t\tbuildActionMask = 2147483647;\n"
               "\t\t\tfiles = (\n\t\t\t);\n"
               "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n"
               "/* End PBXFrameworksBuildPhase section */\n" % ids["phase:frameworks"])

    out.append("\n/* Begin PBXGroup section */\n")
    group_lines, group_ids = [], {}
    app_group = emit_groups(build_tree(all_files), "", group_lines, group_ids)
    out.extend(group_lines)
    out.append("\t\t%s /* Products */ = {\n"
               "\t\t\tisa = PBXGroup;\n"
               "\t\t\tchildren = (\n\t\t\t\t%s /* %s.app */,\n\t\t\t);\n"
               "\t\t\tname = Products;\n"
               "\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
               % (ids["group:products"], ids["product"], APP))
    out.append("\t\t%s = {\n"
               "\t\t\tisa = PBXGroup;\n"
               "\t\t\tchildren = (\n\t\t\t\t%s /* %s */,\n\t\t\t\t%s /* Products */,\n\t\t\t);\n"
               "\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
               % (ids["group:root"], app_group, APP, ids["group:products"]))
    out.append("/* End PBXGroup section */\n")

    out.append("\n/* Begin PBXNativeTarget section */\n"
               "\t\t%s /* %s */ = {\n"
               "\t\t\tisa = PBXNativeTarget;\n"
               "\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"%s\" */;\n"
               "\t\t\tbuildPhases = (\n\t\t\t\t%s /* Sources */,\n\t\t\t\t%s /* Frameworks */,\n"
               "\t\t\t\t%s /* Resources */,\n\t\t\t);\n"
               "\t\t\tbuildRules = (\n\t\t\t);\n"
               "\t\t\tdependencies = (\n\t\t\t);\n"
               "\t\t\tname = %s;\n\t\t\tproductName = %s;\n"
               "\t\t\tproductReference = %s /* %s.app */;\n"
               "\t\t\tproductType = \"com.apple.product-type.application\";\n\t\t};\n"
               "/* End PBXNativeTarget section */\n"
               % (ids["target"], APP, ids["configlist:target"], APP, ids["phase:sources"],
                  ids["phase:frameworks"], ids["phase:resources"], APP, APP, ids["product"], APP))

    out.append("\n/* Begin PBXProject section */\n"
               "\t\t%s /* Project object */ = {\n"
               "\t\t\tisa = PBXProject;\n"
               "\t\t\tattributes = {\n"
               "\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
               "\t\t\t\tLastSwiftUpdateCheck = 1500;\n"
               "\t\t\t\tLastUpgradeCheck = 1500;\n"
               "\t\t\t\tTargetAttributes = {\n\t\t\t\t\t%s = {\n"
               "\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t};\n\t\t\t\t};\n"
               "\t\t\t};\n"
               "\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject \"%s\" */;\n"
               "\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
               "\t\t\tdevelopmentRegion = en;\n"
               "\t\t\thasScannedForEncodings = 0;\n"
               "\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n"
               "\t\t\tmainGroup = %s;\n"
               "\t\t\tproductRefGroup = %s /* Products */;\n"
               "\t\t\tprojectDirPath = \"\";\n\t\t\tprojectRoot = \"\";\n"
               "\t\t\ttargets = (\n\t\t\t\t%s /* %s */,\n\t\t\t);\n\t\t};\n"
               "/* End PBXProject section */\n"
               % (ids["project"], ids["target"], ids["configlist:project"], APP,
                  ids["group:root"], ids["group:products"], ids["target"], APP))

    for key, isa, label, files in (
        ("phase:resources", "PBXResourcesBuildPhase", "Resources", resources),
        ("phase:sources", "PBXSourcesBuildPhase", "Sources", sources),
    ):
        entries = "".join("\t\t\t\t%s /* %s in %s */,\n"
                          % (object_id("build:" + rel), os.path.basename(rel), label)
                          for rel in files)
        out.append("\n/* Begin %s section */\n"
                   "\t\t%s /* %s */ = {\n\t\t\tisa = %s;\n"
                   "\t\t\tbuildActionMask = 2147483647;\n"
                   "\t\t\tfiles = (\n%s\t\t\t);\n"
                   "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n"
                   "/* End %s section */\n"
                   % (isa, ids[key], label, isa, entries, isa))

    out.append("\n/* Begin XCBuildConfiguration section */\n")
    for scope, base in (("project", PROJECT_BUILD_SETTINGS), ("target", TARGET_BUILD_SETTINGS)):
        for name, extra in (("Debug", DEBUG_ONLY), ("Release", RELEASE_ONLY)):
            settings = base + (extra if scope == "project" else "")
            out.append("\t\t%s /* %s */ = {\n\t\t\tisa = XCBuildConfiguration;\n"
                       "\t\t\tbuildSettings = {\n%s\t\t\t};\n\t\t\tname = %s;\n\t\t};\n"
                       % (object_id("config:%s:%s" % (scope, name)), name, settings, name))
    out.append("/* End XCBuildConfiguration section */\n")

    out.append("\n/* Begin XCConfigurationList section */\n")
    for scope, key, owner in (("project", "configlist:project", 'PBXProject "%s"' % APP),
                              ("target", "configlist:target", 'PBXNativeTarget "%s"' % APP)):
        out.append("\t\t%s /* Build configuration list for %s */ = {\n"
                   "\t\t\tisa = XCConfigurationList;\n"
                   "\t\t\tbuildConfigurations = (\n\t\t\t\t%s /* Debug */,\n\t\t\t\t%s /* Release */,\n\t\t\t);\n"
                   "\t\t\tdefaultConfigurationIsVisible = 0;\n"
                   "\t\t\tdefaultConfigurationName = Release;\n\t\t};\n"
                   % (ids[key], owner, object_id("config:%s:Debug" % scope),
                      object_id("config:%s:Release" % scope)))
    out.append("/* End XCConfigurationList section */\n")

    out.append("\t};\n\trootObject = %s /* Project object */;\n}\n" % ids["project"])

    os.makedirs(PROJECT_DIR, exist_ok=True)
    with open(os.path.join(PROJECT_DIR, "project.pbxproj"), "w") as handle:
        handle.write("".join(out))

    write_scheme(ids["target"])
    print("Wrote %s: %d sources, %d resources" % (PROJECT_DIR, len(sources), len(resources)))


def write_scheme(target_id):
    """A shared scheme, so Run works the moment the project opens."""
    directory = os.path.join(PROJECT_DIR, "xcshareddata", "xcschemes")
    os.makedirs(directory, exist_ok=True)
    reference = ('<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="%s" '
                 'BuildableName="%s.app" BlueprintName="%s" ReferencedContainer="container:%s">'
                 '</BuildableReference>' % (target_id, APP, APP, PROJECT_DIR))
    scheme = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            %s
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         %s
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         %s
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
""" % (reference, reference, reference)
    with open(os.path.join(directory, APP + ".xcscheme"), "w") as handle:
        handle.write(scheme)


if __name__ == "__main__":
    main()
