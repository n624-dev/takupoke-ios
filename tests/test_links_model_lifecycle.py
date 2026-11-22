"""Run the actual link model/store with owned settings and a revision boundary fake."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LinksModelLifecycleTests(unittest.TestCase):
    def test_corrupt_preferences_remain_visible_after_revision_success_and_can_be_reloaded(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift is required to execute the link preferences model")
        host = r'''import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> { var wrappedValue: Value }
enum MappingError: Error { case authentication, changedDuringDownload, unavailable }
enum MappingRevisionResult: Equatable { case unchanged, available(String) }
struct MappingService {
    static var calls = 0
    let baseURL: URL
    let network: URLSession
    func checkRevision(installed: String?, path: String) async throws -> MappingRevisionResult {
        guard path == "links-revision" else { throw MappingError.unavailable }
        Self.calls += 1
        return .available(String(repeating: "F", count: 43))
    }
}
@main struct Probe {
    @MainActor static func main() async throws {
        let suite = "takupoke-links-lifecycle-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let bad = Data("{fictional-invalid-preferences".utf8)
        defaults.set(bad, forKey: "linkPreferences.v1")
        let store = LinkPreferencesStore(defaults: defaults)
        let model = LinksModel(preferencesStore: store, storeRoot: URL(fileURLWithPath: CommandLine.arguments[1]), endpoint: URL(string: "https://links.example.invalid/links")!)
        var failures = [String]()
        func check(_ condition: Bool, _ name: String) {
            if !condition { failures.append(name); print("FAILED: " + name) }
        }
        model.loadIfNeeded()
        check(model.ready && !model.preferencesReady && model.preferencesError != nil, "actual corrupt settings detected")
        check(defaults.data(forKey: "linkPreferences.v1") == bad, "corrupt original is preserved")
        _ = try await model.revision()
        check(!model.preferencesReady && model.preferencesError != nil, "revision success must retain preferences error")
        check(defaults.data(forKey: "linkPreferences.v1") == bad, "revision does not overwrite original")
        await model.refresh()
        check(MappingService.calls == 1 && !model.busy, "automatic refresh uses successful revision TTL without new work")
        model.report(LinksError.unavailable)
        let failureMessage = model.message
        await model.refresh()
        check(model.failed && model.message == failureMessage && MappingService.calls == 1, "cached success does not erase a later failure")
        await model.refresh(force: true)
        check(MappingService.calls == 2 && !model.failed && model.preferencesError != nil, "forced refresh bypasses TTL and retains independent preference errors")
        let previous = LinkPreferences(favoriteIDs: ["fictional-favorite"], hiddenIDs: ["fictional-hidden"], colorOverrides: ["fictional-colored": "blue"])
        try store.save(previous)
        model.loadIfNeeded()
        check(model.preferencesReady && model.preferencesError == nil && model.preferences == previous, "ready data must still allow repaired preferences to reload")
        model.toggleFavorite("fictional-new")
        model.setColor("blue", for: "fictional-new")
        model.hide("fictional-new")
        let stored = try store.load()
        check(stored.favoriteIDs == previous.favoriteIDs.union(["fictional-new"]), "favorite editing recovers without erasing old values")
        check(stored.hiddenIDs == previous.hiddenIDs.union(["fictional-new"]), "hidden editing recovers without erasing old values")
        check(stored.colorOverrides["fictional-new"] == "blue" && stored.colorOverrides["fictional-colored"] == "blue", "color editing recovers without erasing old values")
        let dataRoot = URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("LinksAPI")
        let links = try LinksStore(root:dataRoot)
        func fictional(_ id: String) -> SavedLinks {
            let item = LinkItem(id:id,categoryId:"fictional",label:"架空リンク",href:"https://example.invalid/page",
                color:"sky",visible:true,sortOrder:0,recommended:false,recommendationOrder:0,searchAliases:[],searchTerms:"fictional match")
            let category = LinkCategory(id:"fictional",label:"架空カテゴリ",sortOrder:0,buttons:[item])
            return SavedLinks(payload:LinksPayload(version:"v1",linksVersion:"sha256-" + String(repeating:"a",count:64),
                categories:[category]),apiETag:"W/\"fictional\"",checkedAt:Date())
        }
        let cacheFile = dataRoot.appendingPathComponent("links.json")
        let damagedCache = Data("{fictional-malformed-link-cache".utf8)
        try damagedCache.write(to:cacheFile)
        model.resetForRetention(); model.loadIfNeeded()
        let readWarning = model.message
        check(model.ready && model.failed && model.saved == nil, "damaged link cache stays distinguishable from missing data")
        _ = try await model.revision()
        check(model.updateAvailable && model.failed && model.message == readWarning, "public revision does not erase the cache warning")
        check(try Data(contentsOf:cacheFile) == damagedCache, "public revision does not change the cache bytes")
        try links.save(fictional("fictional-first"))
        model.resetForRetention(); model.loadIfNeeded()
        check(!model.failed && model.message == nil, "reading the restored cache clears the warning")
        let originalRevision = model.searchRevision
        let originalHits = await model.search(normalizedQuery:"match",revision:originalRevision,excluding:[])
        check(originalHits?.map(\.id) == ["fictional-first"], "search uses current saved data")
        let hidden = await model.search(normalizedQuery:"match",revision:originalRevision,excluding:["fictional-first"])
        check(hidden?.isEmpty == true, "search applies the current hidden set")
        try links.save(fictional("fictional-second"))
        model.resetForRetention(); model.loadIfNeeded()
        let updatedRevision = model.searchRevision
        let outdated = await model.search(normalizedQuery:"match",revision:originalRevision,excluding:[])
        let updated = await model.search(normalizedQuery:"match",revision:updatedRevision,excluding:[])
        check(outdated == nil && updated?.map(\.id) == ["fictional-second"], "an old input revision cannot show removed links")
        let cancelled = Task { await model.search(normalizedQuery:"match",revision:updatedRevision,excluding:[]) }
        cancelled.cancel()
        let cancelledResult = await cancelled.value
        check(cancelledResult == nil, "a cancelled search does not publish results")

        let currentLink = fictional("fictional-second").payload.categories[0].buttons[0]
        var unreadableColors = stored
        unreadableColors.colorOverrides["fictional-removed"] = "fictional-old-color"
        unreadableColors.colorOverrides[currentLink.id] = "fictional-invalid-color"
        let original = try JSONEncoder().encode(unreadableColors)
        defaults.set(original,forKey:"linkPreferences.v1")
        model.reloadPreferences()
        check(model.preferencesReady && model.preferencesError == nil, "otherwise valid settings load")
        check(model.color(for:currentLink) == currentLink.color, "an unsupported override uses the link's original color")
        check(defaults.data(forKey:"linkPreferences.v1") == original, "loading does not rewrite old color data")
        model.toggleFavorite("fictional-third")
        model.hide("fictional-third")
        model.setColor("blue",for:"fictional-third")
        let savedAfterOtherLink = try store.load()
        check(model.preferencesError == nil, "an obsolete color does not block unrelated saves")
        check(savedAfterOtherLink.favoriteIDs == stored.favoriteIDs.union(["fictional-third"]), "old and new favorites persist")
        check(savedAfterOtherLink.hiddenIDs == stored.hiddenIDs.union(["fictional-third"]), "old and new hidden links persist")
        check(savedAfterOtherLink.colorOverrides == unreadableColors.colorOverrides.merging(["fictional-third":"blue"]) { old,_ in old },
              "both existing invalid values and valid colors survive the unrelated save")
        var invalidChange = savedAfterOtherLink
        invalidChange.colorOverrides["fictional-removed"] = "fictional-new-invalid-color"
        do { try store.save(invalidChange); check(false,"new unsupported values must be rejected") }
        catch LinksError.invalidResponse {}
        check(try store.load() == savedAfterOtherLink, "rejected color does not change storage")
        model.setColor("blue",for:currentLink.id)
        model.reloadPreferences()
        check(model.color(for:currentLink) == "blue", "choosing a new supported color works after reload")
        check(model.preferences.colorOverrides[currentLink.id] == "blue", "the replacement is stored as an override")
        check(model.preferences.colorOverrides["fictional-removed"] == "fictional-old-color", "unrelated historic color is retained")
        check(failures.isEmpty, "all preference and search lifecycle assertions")
        if !failures.isEmpty { exit(1) }
        print("Production link preferences: revision, repair and edit persistence passed.")
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="takupoke-links-lifecycle-") as scratch:
            root = Path(scratch)
            (root / "Host.swift").write_text(host, encoding="utf-8")
            model = (ROOT / "Takupoke/LinksModel.swift").read_text(encoding="utf-8")
            model = model.replace("import SwiftUI", "#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif")
            (root / "LinksModel.swift").write_text(model, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library", "-module-cache-path", str(root / "modules"),
                            str(ROOT / "Takupoke/LinksAPI.swift"), str(ROOT / "Takupoke/LinksStore.swift"), str(ROOT / "Takupoke/LinkSearch.swift"),
                            str(root / "LinksModel.swift"), str(root / "Host.swift"), "-o", str(root / "probe")],
                           check=True, timeout=60)
            subprocess.run([str(root / "probe"), str(root / "data")], check=True, timeout=15)
