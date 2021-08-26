import Vapor
import SotoDynamoDB

public struct DynamoDBSessionsProvider {
    let client: AWSClient
    let tableName: String
    let region: Region?
    let endpoint: String?
    let sessionLength: TimeInterval?

    public init(client: AWSClient, tableName: String, region: Region? = nil, endpoint: String? = nil, sessionLength: TimeInterval? = nil) {
        self.client = client
        self.tableName = tableName
        self.region = region
        self.endpoint = endpoint
        self.sessionLength = sessionLength
    }

    func make() -> (DynamoDB, String) {
        let dynamoDB = DynamoDB(client: client, region: region, endpoint: endpoint)
        return (dynamoDB, tableName)
    }

    func getExpiryDate() -> Date? {
        if let sessionLength = self.sessionLength {
            return Date().addingTimeInterval(sessionLength)
        } else {
            return nil
        }
    }
}
