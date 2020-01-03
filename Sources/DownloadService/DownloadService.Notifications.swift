import Foundation

public extension DownloadService {

    static let downloadDidBegin = Notification.Name(rawValue: "DownloadService.DownloadDidBegin")
    static let downloadWasRestore = Notification.Name(rawValue: "DownloadService.DownloadWasRestored")
    static let downloadDidUpdate = Notification.Name(rawValue: "DownloadService.DownloadDidUpdate")
    static let downloadDidComplete = Notification.Name(rawValue: "DownloadService.DownloadDidComplete")
    static let downloadDidFail = Notification.Name(rawValue: "DownloadService.DownloadDidFail")

    static let resourceDidBegin = Notification.Name(rawValue: "DownloadService.ResourceDidBegin")
    static let resourceDidUpdate = Notification.Name(rawValue: "DownloadService.ResourceDidUpdate")
    static let resourceDidComplete = Notification.Name(rawValue: "DownloadService.ResourceDidComplete")
    static let resourceDidFail = Notification.Name(rawValue: "DownloadService.ResourceDidFail")

}

public extension Download {

    static let errorKey: String = "Download.Error"
    static let resourceKey: String = "Download.Resource"

}
