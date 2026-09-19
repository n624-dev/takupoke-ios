import Foundation
import SwiftUI

@MainActor
final class MaterialsModel: ObservableObject {
    @Published private(set) var state = MaterialLibraryState()
    @Published private(set) var candidates: [MaterialCandidate] = []
    @Published private(set) var folderListed = false
    @Published private(set) var busy = false
    @Published private(set) var ready = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false

    private let worker = MaterialWorker()
    private let queue = DispatchQueue(label: "io.github.n624dev.takupoke.materials", qos: .userInitiated)
    private var control: AcquisitionControl?

    func loadIfNeeded() {
        guard !ready else { return }
        perform(success: nil) { worker, _ in try worker.open() }
    }

    func selectFolder(_ url: URL) {
        perform(success: "フォルダを登録しました。資料ごとに使用するファイルを選んでください。") {
            try $0.selectFolder(url, control: $1)
        }
    }

    func refreshFolder() {
        perform(success: "フォルダ内の一覧を更新しました。") { try $0.refreshFolder(control: $1) }
    }

    func selectFile(_ url: URL, kind: MaterialKind) {
        perform(success: "\(kind.title)を取得しました。内容の解析はまだ行っていません。") {
            try $0.selectFile(url, kind: kind, control: $1)
        }
    }

    func selectCandidate(_ name: String, kind: MaterialKind) {
        perform(success: "\(kind.title)を取得しました。内容の解析はまだ行っていません。") {
            try $0.selectCandidate(name, kind: kind, control: $1)
        }
    }

    func refresh(_ kind: MaterialKind) {
        perform(success: "\(kind.title)を再取得しました。") { try $0.refresh(kind, control: $1) }
    }

    func cancel() {
        control?.cancel()
        message = "中止を要求しました。ファイルサービスの応答を待っています。"
    }

    private func perform(success: String?, operation: @escaping (MaterialWorker, AcquisitionControl) throws -> Void) {
        guard !busy else { return }
        busy = true
        failed = false
        message = nil
        let worker = self.worker
        let control = AcquisitionControl()
        self.control = control
        queue.async {
            let result = Result { try operation(worker, control) }
            let snapshot = worker.library?.state
            let candidates = worker.candidates
            let listed = worker.folderListed
            DispatchQueue.main.async {
                self.ready = snapshot != nil
                if let snapshot = snapshot { self.state = snapshot }
                self.candidates = candidates
                self.folderListed = listed
                self.busy = false
                self.control = nil
                switch result {
                case .success:
                    self.message = success
                case .failure(let error):
                    self.failed = true
                    self.message = ((error as? MaterialError) ?? .unavailable).localizedDescription
                }
            }
        }
    }
}
