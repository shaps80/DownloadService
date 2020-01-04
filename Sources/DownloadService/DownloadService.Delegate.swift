import Foundation

/// `DownloadServiceDelegate` specifies methods that a download delegate may respond to. There are both `Download` and
/// `Resource` specific messages.
public protocol DownloadServiceDelegate: class {

    /// Called when the first `Resource` of a `Download` begins
    /// - Parameters:
    ///   - service: The service that's managing the`Download`
    ///   - download: The associated `Download`
    func service(_ service: DownloadService, didBegin download: Download)

    /// Called when the `Download` has been restored after a re-launch
    /// - Parameters:
    ///   - service: The service that's managing the `Download`
    ///   - download: The associated `Download`
    func service(_ service: DownloadService, didRestore download: Download)

    /// Called when a `Resource` of a `Download` updates its progress
    /// - Parameters:
    ///   - service: The service that's managing the`Download`
    ///   - download: The associated `Download`
    ///   - fractionCompleted: The fraction of the overall work completed by the `Download`, including work done by any `Resources` it may have.
    ///   - state: The current state of the `Download`, e.g. `suspended`, `running`, etc...
    func service(_ service: DownloadService, didUpdate download: Download, fractionCompleted: Float, state: Download.State)

    /// Called when all `Resource`'s of a `Download` have completed
    /// - Parameters:
    ///   - service: The service that's managing the`Download`
    ///   - download: The associated `Download`
    func service(_ service: DownloadService, didComplete download: Download)

    /// Called when any `Resource` of a `Download` fails. Any other associated `Resource`'s for this `Download` will be cancelled
    /// - Parameters:
    ///   - service: The service that's managing the`Download`
    ///   - download: The associated `Download`
    ///   - error: The error that occurred
    func service(_ service: DownloadService, didFail download: Download, error: Error)

    /// Called when a `Resource` begins downloading
    /// - Parameters:
    ///   - service: The service that's managing the`Resource`
    ///   - resource: The associated `Resource`
    ///   - download: The `Download` that owns this `Resource`
    func service(_ service: DownloadService, didBegin resource: Download.Resource, for download: Download)

    /// Called when a `Resource` updates its progress
    /// - Parameters:
    ///   - service: The service that's managing the`Download`
    ///   - resource: The associated `Resource`
    ///   - download: The `Download` that owns this `Resource`
    ///   - fractionCompleted: The fraction of the work completed by this `Resource`
    func service(_ service: DownloadService, didUpdate resource: Download.Resource, for download: Download, fractionCompleted: Float)

    /// Called when a `Resource` completes downloading. The delegate is responsible for copying the data from `temporaryUrl`. You __MUST__ also call the provided `completionHandler` when you're done.
    ///
    /// - Note: This URL is only guaranteed to remain valid until execution of this method has completed. The `suggestedDestinationUrl` is provided as a convenience.
    /// - Note: Since this is a blocking function, don't perform long running tasks in this function. Instead its recommended that you copy the data to a temporary location you own and immediately call the completion.
    ///
    /// - Parameters:
    ///   - service: The service that's managing the`Download`
    ///   - resource: The associated `Resource`
    ///   - download: The `Download` that owns this `Resource`
    ///   - temporaryUrl: The location on disk where the `Resource` data has been downloaded to, this URL is only guaranteed to remain valid until the execution of this method has completed.
    ///   - destinationUrl: The suggested destination to copy the data to, this is purely for convenience
    ///   - completionHandler: A handler that you must call once you've copied the downloaded data from its temporary location.
    func service(_ service: DownloadService, didComplete resource: Download.Resource, for download: Download, temporaryUrl: URL, suggestedDestination destinationUrl: URL, completionHandler: @escaping () -> Void)

    /// Called when a `Resource` fails.
    /// - Parameters:
    ///   - service: The service that's managing the`Download`
    ///   - resource: The associated `Resource`
    ///   - download: The `Download` that owns this `Resource`
    ///   - error: The error that occured
    func service(_ service: DownloadService, didFail resource: Download.Resource, for download: Download, error: Error)
}

// Optional methods have a default implementation here
public extension DownloadServiceDelegate {
    func service(_ service: DownloadService, didBegin download: Download) { }
    func service(_ service: DownloadService, didRestore download: Download) { }
    func service(_ service: DownloadService, didUpdate download: Download, fractionCompleted: Float, state: Download.State) { }
    func service(_ service: DownloadService, didBegin resource: Download.Resource, for download: Download) { }
    func service(_ service: DownloadService, didUpdate resource: Download.Resource, for download: Download, fractionCompleted: Float) { }
    func service(_ service: DownloadService, didFail resource: Download.Resource, for download: Download, error: Error) { }
}
