import Foundation

public extension DownloadService {

    static var downloadDidBegin: Notification.Name {
        Notification.Name(rawValue: "DownloadService.DownloadDidBegin")
    }

    static var downloadWasRestore: Notification.Name {
        Notification.Name(rawValue: "DownloadService.DownloadWasRestored")
    }

    static var downloadDidUpdate: Notification.Name {
        Notification.Name(rawValue: "DownloadService.DownloadDidUpdate")
    }

    static var downloadDidComplete: Notification.Name {
        Notification.Name(rawValue: "DownloadService.DownloadDidComplete")
    }

    static var downloadDidFail: Notification.Name {
        Notification.Name(rawValue: "DownloadService.DownloadDidFail")
    }

    static var resourceDidBegin: Notification.Name {
        Notification.Name(rawValue: "DownloadService.ResourceDidBegin")
    }

    static var resourceDidUpdate: Notification.Name {
        Notification.Name(rawValue: "DownloadService.ResourceDidUpdate")
    }

    static var resourceDidComplete: Notification.Name {
        Notification.Name(rawValue: "DownloadService.ResourceDidComplete")
    }

    static var resourceDidFail: Notification.Name {
        Notification.Name(rawValue: "DownloadService.ResourceDidFail")
    }

}

public extension Download {

    static let errorKey: String = "Download.Error"
    static let resourceKey: String = "Download.Resource"

}
