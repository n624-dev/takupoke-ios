"""Create an isolated Xcode UI-test project in the caller's temporary folder."""
import json
from pathlib import Path
import plistlib
import sys


def generate(destination):
    repo = Path(__file__).resolve().parents[1]
    destination = Path(destination)
    project = destination / "PickerChecks.xcodeproj"
    project.mkdir(parents=True)
    objects = {}

    def add(value):
        key = f"{len(objects) + 1:024X}"
        objects[key] = value
        return key

    def sources(paths):
        refs, builds = [], []
        for path in paths:
            ref = add(dict(isa="PBXFileReference", lastKnownFileType="sourcecode.swift", path=str(repo / path), sourceTree="<absolute>"))
            refs.append(ref)
            builds.append(add(dict(isa="PBXBuildFile", fileRef=ref)))
        phase = add(dict(isa="PBXSourcesBuildPhase", buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0))
        return refs, phase

    app_refs, app_sources = sources([
        "Takupoke/GuidedDocumentPicker.swift", "Takupoke/MaterialPickerLayout.swift",
        "Takupoke/MaterialDocumentPicker.swift", "Takupoke/ScopedMaterialSelection.swift",
        "tests/ui/MaterialPickerUIChecks.swift", "tests/ui/PickerTapHarness.swift",
    ])
    test_refs, test_sources = sources(["tests/ui/MaterialPickerTapChecks.swift"])
    app_product = add(dict(isa="PBXFileReference", explicitFileType="wrapper.application", path="PickerChecks.app", sourceTree="BUILT_PRODUCTS_DIR"))
    test_product = add(dict(isa="PBXFileReference", explicitFileType="wrapper.cfbundle", path="PickerTapChecks.xctest", sourceTree="BUILT_PRODUCTS_DIR"))
    products = add(dict(isa="PBXGroup", children=[app_product, test_product], name="Products", sourceTree="<group>"))
    main_group = add(dict(isa="PBXGroup", children=app_refs + test_refs + [products], sourceTree="<group>"))

    def configurations(settings):
        values = []
        for name in ("Debug", "Release"):
            values.append(add(dict(isa="XCBuildConfiguration", name=name, buildSettings=settings)))
        return add(dict(isa="XCConfigurationList", buildConfigurations=values, defaultConfigurationIsVisible=0, defaultConfigurationName="Debug"))

    common = dict(SWIFT_VERSION="5.0", IPHONEOS_DEPLOYMENT_TARGET="26.0", SDKROOT="iphonesimulator",
                  TARGETED_DEVICE_FAMILY="1", CODE_SIGNING_ALLOWED="NO", PRODUCT_NAME="$(TARGET_NAME)",
                  CLANG_ENABLE_MODULES="YES", SWIFT_OPTIMIZATION_LEVEL="-Onone",
                  LD_RUNPATH_SEARCH_PATHS=["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"])
    app_settings = common | dict(PRODUCT_BUNDLE_IDENTIFIER="jp.n624.takupoke.picker-checks",
        GENERATE_INFOPLIST_FILE="NO", INFOPLIST_FILE=str(destination / "Info.plist"),
        SWIFT_ACTIVE_COMPILATION_CONDITIONS="TAKUPOKE_PICKER_TESTS")
    test_settings = common | dict(PRODUCT_BUNDLE_IDENTIFIER="jp.n624.takupoke.picker-tap-checks",
        GENERATE_INFOPLIST_FILE="YES", TEST_TARGET_NAME="PickerChecks")
    app_target = add(dict(isa="PBXNativeTarget", name="PickerChecks", productName="PickerChecks",
        productType="com.apple.product-type.application", productReference=app_product,
        buildPhases=[app_sources], buildRules=[], dependencies=[], buildConfigurationList=configurations(app_settings)))
    dependency = add(dict(isa="PBXTargetDependency", target=app_target))
    test_target = add(dict(isa="PBXNativeTarget", name="PickerTapChecks", productName="PickerTapChecks",
        productType="com.apple.product-type.bundle.ui-testing", productReference=test_product,
        buildPhases=[test_sources], buildRules=[], dependencies=[dependency], buildConfigurationList=configurations(test_settings)))
    root = add(dict(isa="PBXProject", attributes={"LastUpgradeCheck": "2700", "TargetAttributes": {
        app_target: {"CreatedOnToolsVersion": "27.0"},
        test_target: {"CreatedOnToolsVersion": "27.0", "TestTargetID": app_target}}},
        buildConfigurationList=configurations(common), compatibilityVersion="Xcode 14.0",
        developmentRegion="en", hasScannedForEncodings=0, knownRegions=["en", "Base"],
        mainGroup=main_group, productRefGroup=products, projectDirPath="", projectRoot="",
        targets=[app_target, test_target]))

    def encode(value):
        if isinstance(value, dict):
            return "{ " + " ".join(json.dumps(k) + " = " + encode(v) + ";" for k, v in value.items()) + " }"
        if isinstance(value, list):
            return "(" + ",".join(encode(v) for v in value) + ")"
        return json.dumps(value)

    (project / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=root)))
    scheme_dir = project / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True)
    def reference(target, name):
        return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:PickerChecks.xcodeproj"/>'
    app_reference = reference(app_target, "PickerChecks.app")
    test_reference = reference(test_target, "PickerTapChecks.xctest")
    (scheme_dir / "PickerChecks.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{app_reference}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{test_reference}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
<Testables><TestableReference skipped="NO">{test_reference}</TestableReference></Testables><MacroExpansion>{app_reference}</MacroExpansion>
</TestAction></Scheme>''')
    with (destination / "Info.plist").open("wb") as stream:
        plistlib.dump(dict(CFBundleIdentifier="$(PRODUCT_BUNDLE_IDENTIFIER)", CFBundleExecutable="$(EXECUTABLE_NAME)",
            CFBundleName="PickerChecks", CFBundlePackageType="APPL", CFBundleVersion="1", CFBundleShortVersionString="1.0",
            MinimumOSVersion="26.0", UIDeviceFamily=[1], UILaunchScreen={},
            UIApplicationSceneManifest=dict(UIApplicationSupportsMultipleScenes=False)), stream)


if __name__ == "__main__":
    generate(sys.argv[1])
