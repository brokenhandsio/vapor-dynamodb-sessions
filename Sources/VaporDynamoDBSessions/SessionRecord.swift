import Foundation
import Vapor
import SotoCore

struct SessionRecord: Codable {
    let pk: String
    let sk: String
    var data: SessionData
    @OptionalCustomCoding<UnixEpochDateCoder>
    var expiryDate: Date?

    init(id: SessionID, data: SessionData, expiryDate: Date?) {
        self.pk = id.string
        self.sk = "SESSION_RECORD"
        self.data = data
        self.expiryDate = expiryDate
    }
}

// Used to avoid overwriting the expiry on update
struct SessionRecordWithoutExpiry: Codable {
    let pk: String
    let sk: String
    var data: SessionData

    init(id: SessionID, data: SessionData) {
        self.pk = id.string
        self.sk = "SESSION_RECORD"
        self.data = data
    }
}
