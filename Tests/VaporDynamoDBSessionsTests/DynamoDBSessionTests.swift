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
        let dynamoDBEndpoint = Environment.get("DYNAMODB_ENDPOINT") ?? "http://localhost:8000"
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
                throw Abort(.internalServerError)
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

    func getTableCount(file: StaticString = #file, line: UInt = #line) throws -> Int {
        let scanInput = DynamoDB.ScanInput(select: .count, tableName: self.tableName)
        let scanResult = try dynamoDB.scan(scanInput).wait()
        guard let count = scanResult.count else {
            XCTFail("No count when there should be", file: file, line: line)
            throw Abort(.internalServerError)
        }
        return count
    }

    func setupTable() throws {
        let deleteTableInput = DynamoDB.DeleteTableInput(tableName: self.tableName)
        do {
            _ = try dynamoDB.deleteTable(deleteTableInput).wait()
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
        _ = try dynamoDB.createTable(createTableInput).wait()
    }
}
