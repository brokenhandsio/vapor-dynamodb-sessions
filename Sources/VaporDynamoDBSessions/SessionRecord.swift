import Foundation
import Vapor

struct SessionRecord: Codable {
    let pk: String
    let sk: String
    var data: SessionData

    init(id: SessionID, data: SessionData) {
        self.pk = id.string
        self.sk = "SESSION_RECORD"
        self.data = data
    }
}
