import Vapor
import SotoDynamoDB

struct DynamoDBSessions: SessionDriver {
    func createSession(_ data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        let sessionID = SessionID(string: UUID().uuidString)
        let sessionRecord = SessionRecord(id: sessionID, data: data)
        let (dynamoDB, tableName) = request.dynamoDBProvider.make()
        let input = DynamoDB.PutItemCodableInput(item: sessionRecord, tableName: tableName)
        return dynamoDB.putItem(input, logger: request.logger, on: request.eventLoop).transform(to: sessionID)
    }

    func readSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<SessionData?> {
        fatalError()
    }

    func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        fatalError()
    }

    func deleteSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<Void> {
        fatalError()
    }

    
}

extension Application.Sessions.Provider {
    public static var dynamodb: Self {
        return dynamodb(tableName: "")
    }

    public static func dynamodb(tableName: String) -> Self {
        .init {
            $0.sessions.use { _ in DynamoDBSessions() }
        }
    }
}


public final class SessionRecord: Codable {
    public let id: SessionID
    public var data: SessionData

    public init(id: SessionID, data: SessionData) {
        self.id = id
        self.data = data
    }
}
