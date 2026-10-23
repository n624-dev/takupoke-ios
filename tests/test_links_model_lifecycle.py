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
    let baseURL: URL
    let network: URLSession
    func checkRevision(installed: String?, path: String) async throws -> MappingRevisionResult {
        guard path == "links-revision" else { throw MappingError.unavailable }
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
        let model = LinksModel(preferencesStore: store, storeRoot: URL(fileURLWithPath: CommandLine.arguments[1]))
        var failures = [String]()
        func check(_ condition: Bool, _ name: String) {
            if !condition { failures.append(name); print("FAILED: " + name) }
        }
        model.loadIfNeeded()
        check(model.ready && !model.preferencesReady && model.preferencesError != nil, "actual corrupt settings detected")
        check(defaults.data(forKey: "linkPreferences.v1") == bad, "corrupt original is preserved")
        let network = URLSession(configuration: .ephemeral)
        defer { network.invalidateAndCancel() }
        _ = try await model.revision(using: network)
        check(!model.preferencesReady && model.preferencesError != nil, "revision success must retain preferences error")
        check(defaults.data(forKey: "linkPreferences.v1") == bad, "revision does not overwrite original")
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
        check(failures.isEmpty, "all preference lifecycle assertions")
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
                            str(ROOT / "Takupoke/LinksAPI.swift"), str(ROOT / "Takupoke/LinksStore.swift"),
                            str(root / "LinksModel.swift"), str(root / "Host.swift"), "-o", str(root / "probe")],
                           check=True, timeout=60)
            subprocess.run([str(root / "probe"), str(root / "data")], check=True, timeout=15)
