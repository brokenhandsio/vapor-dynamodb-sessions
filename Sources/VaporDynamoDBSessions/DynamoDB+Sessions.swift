import Vapor
import SotoDynamoDB

struct DynamoDBSessions: SessionDriver {
    func createSession(_ data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        let sessionID = generateID()
        let expiryDate = request.dynamoDBSessions.provider.getExpiryDate()
        let sessionRecord = SessionRecord(id: sessionID, data: data, expiryDate: expiryDate)
        let (dynamoDB, tableName) = request.dynamoDBSessions.provider.make()
        let input = DynamoDB.PutItemCodableInput(item: sessionRecord, tableName: tableName)
        return dynamoDB.putItem(input, context: request, on: request.eventLoop).transform(to: sessionID)
    }

    func readSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<SessionData?> {
        let (dynamoDB, tableName) = request.dynamoDBSessions.provider.make()
        let input = DynamoDB.GetItemInput(key: ["pk": .s(sessionID.string), "sk": .s("SESSION_RECORD")], tableName: tableName)
        return dynamoDB.getItem(input, type: SessionRecord.self, context: request, on: request.eventLoop).flatMapThrowing { result in
            if let date = result.item?.expiryDate {
                guard date >= Date() else {
                    return nil
                }
            }
            return result.item?.data
        }
    }

    func updateSession(_ sessionID: SessionID, to data: SessionData, for request: Request) -> EventLoopFuture<SessionID> {
        let updatedItem = SessionRecordWithoutExpiry(id: sessionID, data: data)
        let (dynamoDB, tableName) = request.dynamoDBSessions.provider.make()
        let input = DynamoDB.UpdateItemCodableInput(key: ["pk", "sk"], tableName: tableName, updateItem: updatedItem)
        return dynamoDB.updateItem(input, context: request, on: request.eventLoop).transform(to: sessionID)
    }

    func deleteSession(_ sessionID: SessionID, for request: Request) -> EventLoopFuture<Void> {
        let (dynamoDB, tableName) = request.dynamoDBSessions.provider.make()
        let input = DynamoDB.DeleteItemInput(key: ["pk": .s(sessionID.string), "sk": .s("SESSION_RECORD")], tableName: tableName)
        return dynamoDB.deleteItem(input, context: request, on: request.eventLoop).transform(to: ())
    }

    private func generateID() -> SessionID {
        var bytes = Data()
        for _ in 0..<32 {
            bytes.append(UInt8.random(in: UInt8.min..<UInt8.max))
        }
        return .init(string: bytes.base64EncodedString())
    }
}

extension Application.Sessions.Provider {
    public static var dynamodb: Self {
        .init {
            $0.sessions.use { _ in DynamoDBSessions() }
        }
    }
}
