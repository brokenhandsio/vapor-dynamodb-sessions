import XCTest
import VaporDynamoDBSessions
import Vapor
import XCTVapor

final class DynamoDBSessionTests: XCTestCase {

    var app: Application!
    var eventLoopGroup: EventLoopGroup!
    let tableName = "session-tests"

    override func setUpWithError() throws {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        app = Application(.testing, .shared(eventLoopGroup))
        app.dynamoDBSessions.provider = DynamoDBSessionsProvider(client: app.aws.client, tableName: tableName)
        app.sessions.use(.dynamodb)
    }

    override func tearDownWithError() throws {
        self.app.shutdown()
        try self.eventLoopGroup.syncShutdownGracefully()
    }
}
