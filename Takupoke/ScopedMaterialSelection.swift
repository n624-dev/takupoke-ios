import Foundation

/// Acquire the picker URL before its callback returns; retain the lease until
/// the worker finishes copying and saving the bookmark. URL and lease are immutable.
final class ScopedMaterialSelection: @unchecked Sendable {
    let url: URL
    private let granted: Bool

    init(_ url: URL) {
        self.url = url
        granted = url.startAccessingSecurityScopedResource()
    }

    deinit { if granted { url.stopAccessingSecurityScopedResource() } }

    func access<T>(_ body: (URL) throws -> T) throws -> T {
        guard granted else { throw MaterialError.accessExpired }
        return try withExtendedLifetime(self) { try body(url) }
    }
}
