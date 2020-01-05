import Foundation
import os.log

/// Represents the various errors that may be reported by a `DownloadService`
public enum DownloadError: Error {
    /// The `Download` was cancelled
    case cancelled
    /// The `Download` has already been enqueued
    case duplicate
    /// The `Download` didn't contain any `Resource`'s
    case noResources
    /// One of the `Download`'s `Resource`'s failed
    case failedResource(Download.Resource, Error)
}

/// The download service is responsible for downloading media and/or collections of media. It provides notification
/// and delegate based feedback to allow user interfaces to respond to events.
public final class DownloadService: NSObject {

    public var isLoggingVerbose: Bool = false

    private static var category = "download-service"
    private static var subsystem: String {
        return Bundle(for: self).bundleIdentifier
            ?? Bundle.main.bundleIdentifier
            ?? "com.152percent"
    }

    private static var identifier: String {
        return [
            DownloadService.subsystem,
            DownloadService.category
        ].joined(separator: ".")
    }

    private let log = OSLog(subsystem: DownloadService.subsystem, category: DownloadService.category)

    public private(set) lazy var configuration: URLSessionConfiguration = {
        let config = URLSessionConfiguration.background(withIdentifier: DownloadService.identifier)
        config.httpAdditionalHeaders = ["Range": "bytes=0-"] // this sometimes speeds up certain services that throttle
        config.sessionSendsLaunchEvents = true
        return config
    }()

    private lazy var session: URLSession = {
        guard _resumed else { fatalError("You MUST call resume before performing any actions on this service.") }
        return URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }()

    /// Represents the total progress of all pending tasks
    public var backgroundEventsCompletionHandler: (() -> Void)?
    public weak var delegate: DownloadServiceDelegate?
    private let delegateQueue: OperationQueue

    public private(set) lazy var downloads: Set<Download> = []

    private lazy var downloadsQueue: DispatchQueue = {
        return DispatchQueue.global(qos: .background)
    }()

    private var downloadsCacheUrl: URL {
        // swiftlint:disable force_try
        let docs = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return docs.appendingPathComponent("downloads.service")
    }

    private func commitActiveDownloads() {
        let url = downloadsCacheUrl
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        downloadsQueue.sync { [unowned self] in
            do {
                let data = try encoder.encode(self.downloads)
                try data.write(to: url)
                os_log("Updated downloads to: %{public}s", log: log, type: .debug, url.path)
            } catch {
                os_log("Failed to update downloads to: %{public}s, %{public}s", log: log, type: .debug, url.path, "\(error)")
            }
        }
    }

    private func restoreDownloads() {
        let url = downloadsCacheUrl
        let decoder = JSONDecoder()

        os_log("Download service started: %{public}s", log: log, type: .debug, url.path)

        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            self.downloads = try decoder.decode(Set<Download>.self, from: data)
        } catch {
            self.downloads = []
        }

        guard !self.downloads.isEmpty else {
            os_log("No downloads restored.", log: self.log, type: .debug)
            return
        }

        os_log("%{public}i download(s) found, attempting to restore.", log: self.log, type: .debug, self.downloads.count)

        self.session.getAllTasks { tasks in
            guard !tasks.isEmpty else {
                self.downloads.forEach { self.cancel(download: $0) }
                self.downloads.removeAll()
                self.commitActiveDownloads()
                return
            }

            for task in tasks {
                if let download = self.download(for: task) {
                    download.tasks.append(task)
                    os_log("Found matching download for task: %{public}s. Resuming...", log: self.log, type: .debug, url.absoluteString)
                } else {
                    task.cancel()
                }
            }

            self.downloads.filter { $0.tasks.isEmpty }.forEach {
                os_log("No pending tasks for download: %{public}s. Assuming completed successfully.", log: self.log, type: .debug, $0.name ?? $0.clientIdentifier)
                self.dequeue(download: $0)
            }

            self.downloads.forEach {
                DownloadService.Message.downloadWasRestored($0).post(for: self)
            }
        }
    }

    private func download(for task: URLSessionTask) -> Download? {
        return downloads.first { download in
            download.resources.contains { $0.remoteUrl == task.originalRequest?.url }
        }
    }

    public func download(forClientIdentifier id: String) -> Download? {
        return downloads.first { $0.clientIdentifier == id }
    }

    public func suspend(download: Download) {
        download.tasks.forEach { $0.suspend() }
        postUpdate(for: download)
    }

    public func resume(download: Download) {
        download.tasks.forEach { $0.resume() }
        postUpdate(for: download)
    }

    public func cancel(download: Download) {
        download.tasks.forEach { $0.cancel() }
        postCancel(for: download)
    }

    private func postUpdate(for download: Download) {
        let message = Message.downloadDidUpdate(download)
        let resourceMessages = download.resources.map { Message.resourceDidUpdate(download, $0) }
        [resourceMessages, [message]]
            .flatMap { $0 }
            .forEach { $0.post(for: self) }
    }

    private func postCancel(for download: Download) {
        let message = Message.downloadDidFail(download, DownloadError.cancelled)
        let resourceMessages = download.resources.map {
            Message.resourceDidFail(download, $0, DownloadError.cancelled)
        }

        [resourceMessages, [message]]
            .flatMap { $0 }
            .forEach { $0.post(for: self) }
    }

    public func enqueue(download: Download) throws {
        guard !download.resources.isEmpty else { throw DownloadError.noResources }
        guard !downloads.contains(download) else { throw DownloadError.duplicate }

        // 1. Prepare the download tasks and associate them with this download
        let tasks = download.resources.map { session.downloadTask(with: $0.remoteUrl) }
        download.tasks = tasks

        // 2. Add the download to the activeDownloads and commit the change
        downloads.insert(download)
        commitActiveDownloads()

        // 3. Resume the tasks and return the progress for this download
        tasks.forEach { $0.resume() }

        let message = Message.downloadDidBegin(download)
        let resourceMessages = download.resources.map { Message.resourceDidBegin(download, $0) }
        [[message], resourceMessages]
            .flatMap { $0 }
            .forEach { $0.post(for: self) }
    }

    public func dequeue(download: Download) {
        guard let index = downloads.firstIndex(of: download) else { return }
        downloads.remove(at: index)
        commitActiveDownloads()
    }

    public init(delegate: DownloadServiceDelegate, delegateQueue: OperationQueue = OperationQueue()) {
        self.delegate = delegate
        self.delegateQueue = delegateQueue
        super.init()
    }

    private var _resumed: Bool = false
    public func resume() {
        _resumed = true
        restoreDownloads()
    }
    
}

// MARK: - URLSessionDownloadDelegate

extension DownloadService: URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let url = downloadTask.originalRequest?.url else { return }
        guard let download = self.download(for: downloadTask),
            let resource = download.resource(for: url) else { return }

        [Message.downloadDidUpdate(download),
         Message.resourceDidUpdate(download, resource)
            ].forEach { $0.post(for: self) }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.originalRequest?.url,
            let download = self.download(for: downloadTask),
            let resource = download.resource(for: url) else { return }

        Message.resourceDidComplete(download, resource).post(for: self)
        self.delegate?.service(self, didComplete: resource, for: download, temporaryUrl: location, suggestedDestination: download.suggestedUrl(for: resource)) {
            guard download.tasks.allSatisfy({ $0.progress.isFinished }) else { return }
            Message.downloadDidComplete(download).post(for: self)
            self.dequeue(download: download)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let download = self.download(for: task),
            let url = task.originalRequest?.url,
            let resource = download.resource(for: url) else { return }

        if let error = error {
            download.tasks.forEach { $0.cancel() }

            [Message.resourceDidFail(download, resource, error),
             Message.downloadDidFail(download, error),
                ].forEach { $0.post(for: self) }

            dequeue(download: download)
        }
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { [unowned self] in
            self.backgroundEventsCompletionHandler?()
        }
    }
    
}

// MARK: - Notifications, Delegate & Logging

private extension DownloadService {

    enum Message {
        case downloadDidBegin(Download)
        case downloadWasRestored(Download)
        case downloadDidUpdate(Download)
        case downloadDidComplete(Download)
        case downloadDidFail(Download, Error)

        case resourceDidBegin(Download, Download.Resource)
        case resourceDidUpdate(Download, Download.Resource)
        case resourceDidComplete(Download, Download.Resource)
        case resourceDidFail(Download, Download.Resource, Error)

        var notificationName: Notification.Name {
            switch self {
            case .downloadDidBegin: return DownloadService.downloadDidBegin
            case .downloadWasRestored: return DownloadService.downloadWasRestore
            case .downloadDidUpdate: return DownloadService.downloadDidUpdate
            case .downloadDidComplete: return DownloadService.downloadDidComplete
            case .downloadDidFail: return DownloadService.downloadDidFail
            case .resourceDidBegin: return DownloadService.resourceDidBegin
            case .resourceDidUpdate: return DownloadService.resourceDidUpdate
            case .resourceDidComplete: return DownloadService.resourceDidComplete
            case .resourceDidFail: return DownloadService.resourceDidFail
            }
        }

        func post(for service: DownloadService) {
            let log = service.log

            let download: Download
            var resource: Download.Resource?
            var error: Error?
            let delegate: () -> Void
            let logging: () -> Void

            switch self {
            case let .downloadDidBegin(d):
                logging = { os_log("Download began: %{public}s", log: log, type: .info, d.debugDescription) }
                delegate = { service.delegate?.service(service, didBegin: d) }
                download = d
            case let .downloadWasRestored(d):
                logging = { os_log("Download was restored: %{public}s", log: log, type: .info, d.debugDescription) }
                delegate = { service.delegate?.service(service, didRestore: d) }
                download = d
            case let .downloadDidUpdate(d):
                logging = {
                    guard service.isLoggingVerbose else { return }
                    os_log("Download %{public}s: %{public}s", log: log, type: .info, d.state.rawValue, d.debugDescription)
                }
                delegate = { service.delegate?.service(service, didUpdate: d, fractionCompleted: d.fractionCompleted, state: d.state) }
                download = d
            case let .downloadDidComplete(d):
                logging = { os_log("Download completed: %{public}s", log: log, type: .info, d.debugDescription) }
                delegate = { service.delegate?.service(service, didComplete: d) }
                download = d
            case let .downloadDidFail(d, e):
                logging = { os_log("Download failed: %{public}s | %{public}s", log: log, type: .info,
                                   d.debugDescription, e.localizedDescription) }
                delegate = { service.delegate?.service(service, didFail: d, error: e) }
                download = d
                error = e
            case let .resourceDidBegin(d, r):
                logging = { os_log("Resource began: %{public}s | %{public}s", log: log, type: .info,
                                   d.debugDescription, service.isLoggingVerbose ? r.debugDescription : r.description) }
                delegate = { service.delegate?.service(service, didBegin: r, for: d) }
                download = d
                resource = r
            case let .resourceDidUpdate(d, r):
                let f = d.fractionCompleted(for: r)
                logging = {
                    guard service.isLoggingVerbose else { return }
                    os_log("Resource %{public}s: %{public}s | %{public}s | %{public}i%", log: log, type: .info,
                           d.state.rawValue, d.debugDescription, r.debugDescription, Int(f * 100))
                }
                delegate = { service.delegate?.service(service, didUpdate: r, for: d, fractionCompleted: f) }
                download = d
                resource = r
            case let .resourceDidComplete(d, r):
                logging = { os_log("Resource completed: %{public}s | %{public}s", log: log, type: .info,
                                   d.debugDescription, service.isLoggingVerbose ? r.debugDescription : r.description) }
                delegate = { /* we have to do the file copy in the outer method so we can't call the delegate here */ }
                download = d
                resource = r
            case let .resourceDidFail(d, r, e):
                logging = { os_log("Resource failed: %{public}s | %{public}s | %{public}s", log: log, type: .info,
                                   d.debugDescription, service.isLoggingVerbose ? r.debugDescription : r.description, e.localizedDescription) }
                delegate = { service.delegate?.service(service, didFail: r, for: d, error: e) }
                download = d
                resource = r
                error = e
            }

            download.setNeedsUpdate()
            logging()

            service.delegateQueue.addOperation {
                delegate()
            }

            let note = Notification(name: notificationName, object: download, userInfo: [
                Download.resourceKey: resource as Any,
                Download.errorKey: error as Any,
            ].compactMapValues { $0 })

            NotificationCenter.default.post(note)
        }
    }

}
