import Foundation

/// A `Download` provides a container with multiple associated `Resource`'s as its children.
public final class Download: Codable, Hashable, CustomDebugStringConvertible {

    public typealias ChangeHandler = (Download) -> Void

    /// The possible states for a `Download`
    public enum State: String {
        /// All `Resource` tasks are running
        case running
        /// All `Resource` tasks are suspended
        case suspended
        /// All `Resource` tasks have completed
        case completed
        /// At least one `Resource` task failed
        case failed
        /// At least one `Resource` task was cancelled
        case cancelled
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case clientIdentifier
        case name
        case resources
    }

    /// A hashed representation of the clientIdentifier
    private var id: String

    /// Represents any associated observers currently attached to this `Download`
    private var observers: [Observation: ChangeHandler] = [:]

    /// An identifier used by the client to identify this with its associated content
    public let clientIdentifier: String

    /// A friendly name, if you don't provide a name, a unique identifier will be used instead.
    ///
    /// Names provide a way for you to identify your `Download`  at run time. Tools may also use this name to provide additional context during debugging or analysis of your code.
    public let name: String?

    /// Returns the current state of the `Download`. Defaults to `suspended`
    public var state: State {
        guard let task = tasks.first else {
            return .suspended
        }

        switch task.state {
        case .running: return .running
        case .completed: return .completed
        case .suspended: return .suspended
        case .canceling: return .cancelled
        default: return .failed
        }
    }

    /// The fraction of the overall work completed by the `Download`, including work done by any `Resources` it may have.
    public var fractionCompleted: Float {
        let total = tasks.reduce(0, { $0 + $1.progress.fractionCompleted })
        let average = Float(total) / Float(tasks.count)
        return average
    }

    /// All associated `Resource`'s for this `Download`
    internal var resources: Set<Resource>

    /// All associated `URLSessionTask`'s for this `Download`
    internal var tasks: [URLSessionTask] = []

    /// Instantiates a new `Download` with the specified `clientIdentifier` and all associated `Resources`
    /// - Parameters:
    ///   - name: A friendly name, if you don't provide a name, a unique identifier will be used instead.
    ///   - clientIdentifier: An identifier used by the client to identify this with its associated content
    ///   - resources: All associated `Resource`'s for this `Download`
    public init(name: String?, clientIdentifier: String, resources: Set<Resource>) {
        self.id = clientIdentifier.encrypted
        self.name = name
        self.clientIdentifier = clientIdentifier
        self.resources = resources
    }

    public var containerUrl: URL {
        // swiftlint:disable force_try
        return try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(id, isDirectory: true)
    }

    public func suggestedUrl(for resource: Resource) -> URL {
        return containerUrl.appendingPathComponent(resource.localFilename, isDirectory: false)
    }

    /// Returns an `Observation` that can be used to observe updates on this `Download`.
    /// You should retain the retuurned value, when the `Observation` is deinited or invalidated – it will stop observing.
    /// - Parameter observation: The
    public func observe(changeHandler: @escaping ChangeHandler) -> Observation {
        let observer = Observation(download: self)
        observers[observer] = changeHandler
        changeHandler(self)
        return observer
    }

    /// This is automatically when the observation is deinited or invalidated
    private func unobserve(_ observation: Observation) {
        observers.removeValue(forKey: observation)
    }

    /// Used by the `DownloadService` to notify this `Download` when its been updated
    internal func setNeedsUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.observers.values.forEach { $0(self) }
        }
    }

    public static func == (lhs: Download, rhs: Download) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var debugDescription: String {
        let attributes = [
            "Client Id": clientIdentifier,
            "Name": name,
            "Completed": "\(Int(max(0, min(1, fractionCompleted)) * 100))%"
        ].compactMapValues { $0 }
        return attributes.values.joined(separator: " | ")
    }

    /// Convenience function used by the `DownloadService` to associate a `URLSessionTask` to the associated `Resource`
    internal func resource(for url: URL) -> Resource? {
        return resources.first(where: { $0.remoteUrl == url })
    }

    internal func fractionCompleted(for resource: Download.Resource) -> Float {
        return Float(tasks.first { resource.remoteUrl == $0.originalRequest?.url }?.progress.fractionCompleted ?? 0)
    }

}

public extension Download {

    /// An opaque type for representing an observation on a `Download`
    final class Observation: Hashable {

        deinit {
            // when we lose a reference to this observation, we should invalidate it
            invalidate()
        }

        /// A unique identifier that provides hashability for using this as a key in a dictionary on the `Download`
        private let id = UUID()

        /// The associated Download this observation applies to
        private weak var download: Download?

        /// Instantiates a new `Observation` for the specified `Download`
        fileprivate init(download: Download) {
            self.download = download
        }

        /// Invalidates the observation
        public func invalidate() {
            // when the observation is invalidated, we remove it from the associated `Download`
            download?.unobserve(self)
        }

        public static func == (lhs: Observation, rhs: Observation) -> Bool {
            return lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

    }

}
