import XCTest
@testable import VaporDynamoDBSessions
import Vapor
import XCTVapor
import SotoDynamoDB
import Baggage

final class DynamoDBSessionTests: XCTestCase {

    var app: Application!
    var eventLoopGroup: EventLoopGroup!
    let tableName = "session-tests"
    var dynamoDB: DynamoDB!
    var dynamoDBEndpoint: String!
    var context: LoggingContext!

    override func setUpWithError() throws {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        app = Application(.testing, .shared(eventLoopGroup))
        context = DefaultLoggingContext.topLevel(logger: app.logger)
        let awsClient = AWSClient(credentialProvider: .static(accessKeyId: "SOMETHING", secretAccessKey: "SOMETHINGLESE"), httpClientProvider: .shared(app.http.client.shared))
        app.aws.client = awsClient
        dynamoDBEndpoint = Environment.get("DYNAMODB_ENDPOINT") ?? "http://localhost:8000"
        dynamoDB = DynamoDB(client: awsClient, region: .useast1, endpoint: dynamoDBEndpoint)
        app.dynamoDBSessions.provider = DynamoDBSessionsProvider(client: app.aws.client, tableName: tableName, region: .useast1, endpoint: dynamoDBEndpoint)
        app.sessions.use(.dynamodb)
        app.middleware.use(app.sessions.middleware)

        app.routes.get("set") { req -> String in
            let value = try req.query.get(String.self, at: "value")
            req.session.data["test"] = value
            return "OK"
        }

        app.routes.get("get") { req -> String in
            guard let value = req.session.data["test"] else {
                throw Abort(.badRequest)
            }
            return value
        }

        app.routes.get("delete") { req -> String in
            req.session.destroy()
            return "OK"
        }

        try setupTable()
    }

    override func tearDownWithError() throws {
        self.app.shutdown()
        try self.eventLoopGroup.syncShutdownGracefully()
    }

    func testSessionsWorksAsExpected() throws {
        let value = "test-value-\(Int.random())"
        try app.test(.GET, "/set?value=\(value)", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let sessionIDCookie = try XCTUnwrap(res.headers.setCookie?.all["vapor-session"])
            let count = try getTableCount()
            XCTAssertEqual(count, 1)

            let data = try scanTable()
            let sessions = try data.items.map { try $0.map { try DynamoDBDecoder().decode(SessionRecord.self, from: $0) } }
            XCTAssertEqual(sessions?.first?.data["test"], value)

            var headers = HTTPHeaders()
            headers.add(name: .cookie, value: sessionIDCookie.serialize(name: "vapor-session"))
            try app.test(.GET, "/get", headers: headers, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, value)

                let count = try getTableCount()
                XCTAssertEqual(count, 1)
            })

            let value2 = "another-test-value-\(Int.random())"
            try app.test(.GET, "/set?value=\(value2)", headers: headers, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let count = try getTableCount()
                XCTAssertEqual(count, 1)

                let data = try scanTable()
                let sessions = try data.items.map { try $0.map { try DynamoDBDecoder().decode(SessionRecord.self, from: $0) } }
                XCTAssertEqual(sessions?.first?.data["test"], value2)
            })

            try app.test(.GET, "/get", headers: headers, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, value2)

                let count = try getTableCount()
                XCTAssertEqual(count, 1)
            })

            try app.test(.GET, "/delete", headers: headers, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)

                let count = try getTableCount()
                XCTAssertEqual(count, 0)
            })
        })
    }

    func testSessionsExpirySet() throws {
        let sessionLength: TimeInterval = 60 * 60 * 24 * 30
        app.dynamoDBSessions.provider = DynamoDBSessionsProvider(client: app.aws.client, tableName: tableName, region: .useast1, endpoint: dynamoDBEndpoint, sessionLength: sessionLength)
        app.sessions.use(.dynamodb)
        app.middleware = .init()
        app.middleware.use(ErrorMiddleware.default(environment: .testing))
        app.middleware.use(app.sessions.middleware)

        let value = "test-value-\(Int.random())"
        try app.test(.GET, "/set?value=\(value)", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let sessionIDCookie = try XCTUnwrap(res.headers.setCookie?.all["vapor-session"])
            let count = try getTableCount()
            XCTAssertEqual(count, 1)

            let data = try scanTable()
            let sessions = try data.items.map { try $0.map { try DynamoDBDecoder().decode(SessionRecord.self, from: $0) } }
            let timeInterval = try XCTUnwrap(sessions?.first?.expiryDate?.timeIntervalSince1970)
            XCTAssertEqual(timeInterval, Date().addingTimeInterval(sessionLength).timeIntervalSince1970, accuracy: 5.0)
            XCTAssertEqual(sessions?.first?.data["test"], value)

            var headers = HTTPHeaders()
            headers.add(name: .cookie, value: sessionIDCookie.serialize(name: "vapor-session"))
            try app.test(.GET, "/get", headers: headers, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, value)

                let count = try getTableCount()
                XCTAssertEqual(count, 1)
            })

            let value2 = "another-test-value-\(Int.random())"
            try app.test(.GET, "/set?value=\(value2)", headers: headers, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let count = try getTableCount()
                XCTAssertEqual(count, 1)

                let data = try scanTable()
                let sessions = try data.items.map { try $0.map { try DynamoDBDecoder().decode(SessionRecord.self, from: $0) } }
                XCTAssertEqual(sessions?.first?.data["test"], value2)
                let newTimeInterval = try XCTUnwrap(sessions?.first?.expiryDate?.timeIntervalSince1970)
                XCTAssertEqual(timeInterval, newTimeInterval)
            })
        })
    }

    func testExpiredSessionIsDiscarded() throws {
        let sessionID = SessionID(string: UUID().uuidString)
        var data = SessionData()
        data["test"] = "Some value"
        let session = SessionRecord(id: sessionID, data: data, expiryDate: Date().addingTimeInterval(-3600))
        let input = DynamoDB.PutItemCodableInput(item: session, tableName: self.tableName)
        _ = try self.dynamoDB.putItem(input, logger: app.logger, on: app.eventLoopGroup.next()).wait()

        var headers = HTTPHeaders()
        let sessionIDCookie = HTTPCookies.Value(string: sessionID.string)
        headers.add(name: .cookie, value: sessionIDCookie.serialize(name: "vapor-session"))
        try app.test(.GET, "/get", headers: headers, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    // MARK: - Helpers

    func getTableCount(file: StaticString = #file, line: UInt = #line) throws -> Int {
        let scanResult = try scanTable()
        guard let count = scanResult.count else {
            XCTFail("No count when there should be", file: file, line: line)
            throw Abort(.internalServerError)
        }
        return count
    }

    func scanTable(file: StaticString = #file, line: UInt = #line) throws -> DynamoDB.ScanOutput {
        let scanInput = DynamoDB.ScanInput(tableName: self.tableName)
        let scanResult = try dynamoDB.scan(scanInput).wait()
        return scanResult
    }

    func setupTable() throws {
        let deleteTableInput = DynamoDB.DeleteTableInput(tableName: self.tableName)
        do {
            _ = try dynamoDB.deleteTable(deleteTableInput, context: context).wait()
        } catch {
            // Swallow error in case table doesn't exist yet
        }
        let createTableInput = DynamoDB.CreateTableInput(
            attributeDefinitions: [
                .init(attributeName: "pk", attributeType: .s),
                .init(attributeName: "sk", attributeType: .s),
            ],
            billingMode: .payPerRequest,
            keySchema: [
                .init(attributeName: "pk", keyType: .hash),
                .init(attributeName: "sk", keyType: .range)
            ],
            tableName: self.tableName)
        _ = try dynamoDB.createTable(createTableInput, context: context).wait()
    }
}
