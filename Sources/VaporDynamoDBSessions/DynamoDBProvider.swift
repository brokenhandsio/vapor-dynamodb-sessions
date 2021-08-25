import Vapor
import SotoDynamoDB

public extension Request {
    var dynamoDBSessions: DynamoDBSessions {
        .init(request: self)
    }

    struct DynamoDBSessions {
        var provider: DynamoDBSessionsProvider {
            return request.application.dynamoDBSessions.provider
        }

        let request: Request
    }
}

public extension Application {
    var dynamoDBSessions: DynamoDBSessions {
        .init(application: self)
    }

    struct DynamoDBSessions {
        struct ProviderKey: StorageKey {
            typealias Value = DynamoDBSessionsProvider
        }

        public var provider: DynamoDBSessionsProvider {
            get {
                guard let provider = self.application.storage[ProviderKey.self] else {
                    fatalError("DynamoDBSessions not setup. Use app.dynamoDBSessions.provider = DynamoDBSessionsProvider...")
                }
                return provider
            }
            nonmutating set {
                self.application.storage.set(ProviderKey.self, to: newValue)
            }
        }

        let application: Application
    }
}

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
