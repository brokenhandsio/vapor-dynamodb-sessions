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
        let (dynamoDB, tableName) = request.dynamoDBProvider.make()
        let input = DynamoDB.GetItemInput(key: ["pk": .s(sessionID.string), "sk": .s("SESSION_RECORD")], tableName: tableName)
        return dynamoDB.getItem(input, type: SessionRecord.self, logger: request.logger, on: request.eventLoop).flatMapThrowing { result in
            return result.item?.data
        }
    }

    func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        let updatedItem = SessionRecord(id: sessionID, data: data)
        let (dynamoDB, tableName) = request.dynamoDBProvider.make()
        let input = DynamoDB.UpdateItemCodableInput(key: ["pk", "sk"], tableName: tableName, updateItem: updatedItem)
        return dynamoDB.updateItem(input, logger: request.logger, on: request.eventLoop).transform(to: sessionID)
    }

    func deleteSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<Void> {
        let (dynamoDB, tableName) = request.dynamoDBProvider.make()
        let input = DynamoDB.DeleteItemInput(key: ["pk": .s(sessionID.string), "sk": .s("SESSION_RECORD")], tableName: tableName)
        return dynamoDB.deleteItem(input, logger: request.logger, on: request.eventLoop).transform(to: ())
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
    public let pk: String
    public let sk: String
    public var data: SessionData

    public init(id: SessionID, data: SessionData) {
        self.pk = id.string
        self.sk = "SESSION_RECORD"
        self.data = data
    }
}
