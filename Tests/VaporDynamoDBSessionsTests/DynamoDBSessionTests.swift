import XCTest
import VaporDynamoDBSessions
import Vapor
import XCTVapor

final class DynamoDBSessionTests: XCTestCase {

    var app: Application!
    var eventLoopGroup: EventLoopGroup!

    override func setUpWithError() throws {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        app = Application(.testing, .shared(eventLoopGroup))
    }

    override func tearDownWithError() throws {
        self.app.shutdown()
        try self.eventLoopGroup.syncShutdownGracefully()
    }
}
