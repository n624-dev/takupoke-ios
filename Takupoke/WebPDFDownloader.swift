import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct WebPDFCacheMetadata {
    var etag: String?
    var lastModified: String?
}

struct WebPDFResponse {
    var notModified: Bool
    var metadata: WebPDFCacheMetadata
    var modifiedAt: Date?
}

/// Call fetch on the acquisition queue. Mutable delegate state is confined to
/// its serial callback queue, then read only after the completion semaphore.
final class WebPDFDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    static let eventsURL = URL(string: "https://www.kagawa-nct.ac.jp/school_affairs/event/calendar.pdf")!

    static func validatedURL(_ input: String) throws -> URL {
        guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { throw MaterialError.invalidWebURL }
        return url
    }

    static func fetch(_ url: URL, to destination: URL, cached: WebPDFCacheMetadata?,
                      configuration: URLSessionConfiguration = .ephemeral,
                      checkCancellation: () throws -> Void) throws -> WebPDFResponse {
        _ = try validatedURL(url.absoluteString)
        try checkCancellation()
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw MaterialError.webUnavailable
        }
        let delegate = try WebPDFDownloader(destination: destination, cached: cached)
        // The committed document and validators are the only persistent cache.
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")
        if let etag = cached?.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let modified = cached?.lastModified { request.setValue(modified, forHTTPHeaderField: "If-Modified-Since") }
        let task = session.dataTask(with: request)
        task.resume()
        var cancellation: Error?
        while delegate.completion.wait(timeout: .now() + 0.1) == .timedOut {
            do { try checkCancellation() } catch {
                cancellation = error
                task.cancel()
            }
        }
        // didComplete closes the file before signalling; no callback can write
        // after the caller removes staging or commits the downloaded document.
        if let cancellation = cancellation { throw cancellation }
        try checkCancellation()
        if let failure = delegate.failure { throw failure }
        guard let response = delegate.response else { throw MaterialError.webUnavailable }
        return response
    }

    private let output: FileHandle
    private let cached: WebPDFCacheMetadata?
    private let completion = DispatchSemaphore(value: 0)
    private var response: WebPDFResponse?
    private var failure: MaterialError?
    private var count = 0
    private var header = Data()
    private var redirects = 0

    private init(destination: URL, cached: WebPDFCacheMetadata?) throws {
        output = try FileHandle(forWritingTo: destination)
        self.cached = cached
        super.init()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let sentValidator = cached?.etag != nil || cached?.lastModified != nil
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 || (http.statusCode == 304 && sentValidator) else {
            failure = .webUnavailable
            completionHandler(.cancel)
            return
        }
        guard response.expectedContentLength <= Int64(MaterialLibrary.maximumBytes) else {
            failure = .tooLarge
            completionHandler(.cancel)
            return
        }
        let notModified = http.statusCode == 304
        let metadata = WebPDFCacheMetadata(
            etag: http.value(forHTTPHeaderField: "ETag") ?? (notModified ? cached?.etag : nil),
            lastModified: http.value(forHTTPHeaderField: "Last-Modified") ?? (notModified ? cached?.lastModified : nil))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        self.response = WebPDFResponse(notModified: notModified, metadata: metadata,
                                      modifiedAt: metadata.lastModified.flatMap { formatter.date(from: $0) })
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard failure == nil, let response = response, !response.notModified else { return }
        count += data.count
        guard count <= MaterialLibrary.maximumBytes else {
            failure = .tooLarge
            dataTask.cancel()
            return
        }
        if header.count < 5 { header.append(data.prefix(5 - header.count)) }
        if header.count == 5 && header != Data("%PDF-".utf8) {
            failure = .invalidFile
            dataTask.cancel()
            return
        }
        do { try output.write(contentsOf: data) } catch {
            failure = .webUnavailable
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            try? output.close()
            completion.signal()
        }
        if failure != nil { return }
        guard error == nil else { failure = .webUnavailable; return }
        guard let response = response else { failure = .webUnavailable; return }
        if !response.notModified && (count < 5 || header != Data("%PDF-".utf8)) {
            failure = .invalidFile
            return
        }
        do { try output.synchronize() } catch { failure = .webUnavailable }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        redirects += 1
        guard redirects <= 5, let url = request.url,
              (try? Self.validatedURL(url.absoluteString)) != nil else {
            failure = .webUnavailable
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    willCacheResponse proposedResponse: CachedURLResponse,
                    completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(nil)
    }
}
