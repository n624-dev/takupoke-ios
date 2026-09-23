// swift-tools-version: 5.9
import PackageDescription

// Host tests compile the same Foundation-based sources used by the iOS target.
let package = Package(
    name: "TakupokeParsing",
    platforms: [.macOS(.v12), .iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", revision: "22787ffb59de99e5dc1fbfe80b19c97a904ad48d"),
        .package(url: "https://github.com/groue/GRDB.swift.git", revision: "b83108d10f42680d78f23fe4d4d80fc88dab3212")
    ],
    targets: [
        .target(name: "TakupokeParsing", dependencies: ["ZIPFoundation", .product(name: "GRDB", package: "GRDB.swift")], path: "Takupoke",
                exclude: ["Assets.xcassets", "Info.plist", "PrivacyInfo.xcprivacy", "ThirdPartyNotices.txt",
                          "TakupokeApp.swift", "ContentView.swift", "MaterialAccess.swift", "MaterialsModel.swift",
                          "MaterialsView.swift", "ChangeAnalysisView.swift", "WebPDFDownloader.swift", "PDFAnalysisView.swift", "TimetableView.swift"],
                sources: ["LocalMaterialDatabase.swift", "LegacyDatabaseMigration.swift", "ChangeNormalizer.swift", "XLSXReader.swift", "MaterialLibrary.swift", "TimetableLessonNames.swift", "PDFSchoolParser.swift", "PDFKitReader.swift", "PDFTextGeometry.swift", "PDFDiagnostics.swift", "PDFFullDiagnosticEncoding.swift", "SchoolDate.swift", "TimetableSchedule.swift"]),
        .testTarget(name: "ParsingTests", dependencies: ["TakupokeParsing", "ZIPFoundation", .product(name: "GRDB", package: "GRDB.swift")], path: "tests",
                    exclude: ["MaterialLibraryChecks.swift", "WebPDFChecks.swift", "test_distribution.py"],
                    sources: ["ParsingTests.swift", "TimetableNameTests.swift", "PDFParsingTests.swift", "PDFTextGeometryTests.swift", "LocalDatabaseTests.swift", "SchoolDateTests.swift", "TimetableScheduleTests.swift"], resources: [.copy("fixtures")])
    ]
)
