import Foundation

public extension Download {

    /// A `Resource` represents a single `URLSessionTask`
    final class Resource: Codable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {

        /// Represents the remote URL associated with this `Resource`. This is used to create and re-associate a `URLSessionTask`
        public let remoteUrl: URL

        /// An identifier used by the client to identify this with its associated content
        public let clientIdentifier: String

        public init(clientIdentifier: String, remoteUrl: URL) {
            self.clientIdentifier = clientIdentifier
            self.remoteUrl = remoteUrl
        }

        public var description: String {
            return "Client Id: \(clientIdentifier)"
        }

        public var debugDescription: String {
            let attributes = [
                "Client Id": clientIdentifier,
                "Remote URL": remoteUrl.absoluteString,
            ].compactMapValues { $0 }
            return attributes.values.joined(separator: " | ")
        }

        public static func == (lhs: Resource, rhs: Resource) -> Bool {
            return lhs.clientIdentifier == rhs.clientIdentifier
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(clientIdentifier)
        }

    }

}