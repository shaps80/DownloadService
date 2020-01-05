import Foundation
import CommonCrypto
import CryptoKit

internal extension String {

    var encrypted: String {
        let data = Data(self.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()

    }

}
