import Vapor
import SotoDynamoDB

public struct DynamoDBSessionsProvider {
    let client: AWSClient
    let tableName: String
    let region: Region?
    let endpoint: String?

    public init(client: AWSClient, tableName: String, region: Region? = nil, endpoint: String? = nil) {
        self.client = client
        self.tableName = tableName
        self.region = region
        self.endpoint = endpoint
    }

    func make() -> (DynamoDB, String) {
        let dynamoDB = DynamoDB(client: client, region: region, endpoint: endpoint)
        return (dynamoDB, tableName)
    }
}
