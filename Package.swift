// swift-tools-version: 5.9
import PackageDescription

// Host tests compile the same Foundation-based sources used by the iOS target.
let package = Package(
    name: "TakupokeParsing",
    platforms: [.macOS(.v12), .iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", revision: "22787ffb59de99e5dc1fbfe80b19c97a904ad48d")
    ],
    targets: [
        .target(name: "TakupokeParsing", dependencies: ["ZIPFoundation"], path: "Takupoke",
                exclude: ["Assets.xcassets", "Info.plist", "PrivacyInfo.xcprivacy", "ThirdPartyNotices.txt",
                          "TakupokeApp.swift", "ContentView.swift", "MaterialAccess.swift", "MaterialsModel.swift",
                          "MaterialsView.swift", "ChangeAnalysisView.swift", "WebPDFDownloader.swift", "PDFAnalysisView.swift"],
                sources: ["ChangeNormalizer.swift", "XLSXReader.swift", "MaterialLibrary.swift", "TimetableLessonNames.swift", "PDFSchoolParser.swift", "PDFKitReader.swift", "PDFTextGeometry.swift", "PDFDiagnostics.swift", "PDFFullDiagnosticEncoding.swift"]),
        .testTarget(name: "ParsingTests", dependencies: ["TakupokeParsing", "ZIPFoundation"], path: "tests",
                    exclude: ["MaterialLibraryChecks.swift", "WebPDFChecks.swift", "test_distribution.py"],
                    sources: ["ParsingTests.swift", "TimetableNameTests.swift", "PDFParsingTests.swift", "PDFTextGeometryTests.swift"], resources: [.copy("fixtures")])
    ]
)
