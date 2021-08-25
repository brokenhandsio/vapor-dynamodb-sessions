import XCTest
import VaporDynamoDBSessions
import Vapor
import XCTVapor
import SotoDynamoDB

final class DynamoDBSessionTests: XCTestCase {

    var app: Application!
    var eventLoopGroup: EventLoopGroup!
    let tableName = "session-tests"
    var dynamoDB: DynamoDB!

    override func setUpWithError() throws {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        app = Application(.testing, .shared(eventLoopGroup))
        let awsClient = AWSClient(credentialProvider: .static(accessKeyId: "SOMETHING", secretAccessKey: "SOMETHINGLESE"), httpClientProvider: .shared(app.http.client.shared))
        app.aws.client = awsClient
        let dynamoDBEndpoint = "http://localhost:8000"
        dynamoDB = DynamoDB(client: awsClient, region: .useast1, endpoint: dynamoDBEndpoint)
        app.dynamoDBSessions.provider = DynamoDBSessionsProvider(client: app.aws.client, tableName: tableName, region: .useast1, endpoint: dynamoDBEndpoint)
        app.sessions.use(.dynamodb)
        app.middleware.use(app.sessions.middleware)

        app.routes.get { req -> String in
            req.session.data["test"] = "TEST"
            return "OK"
        }
    }

    override func tearDownWithError() throws {
        self.app.shutdown()
        try self.eventLoopGroup.syncShutdownGracefully()
    }

    func testSessionsWorksAsExpected() throws {
        try app.test(.GET, "/", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertNotNil(res.headers.setCookie?.all["vapor-session"])

            let count = try getTableCount()
            XCTAssertEqual(count, 1)
        })

    }

    func getTableCount(file: StaticString = #file, line: UInt = #line) throws -> Int {
        let scanInput = DynamoDB.ScanInput(select: .count, tableName: self.tableName)
        let scanResult = try dynamoDB.scan(scanInput).wait()
        guard let count = scanResult.count else {
            XCTFail("No count when there should be", file: file, line: line)
            throw Abort(.internalServerError)
        }
        return count
    }
}
