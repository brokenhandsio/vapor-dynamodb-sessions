import Vapor
import SotoDynamoDB

public extension Application {
    var aws: AWS {
        .init(application: self)
    }

    struct AWS {
        struct ClientKey: StorageKey {
            typealias Value = AWSClient
        }

        public var client: AWSClient {
            get {
                guard let client = self.application.storage[ClientKey.self] else {
                    fatalError("AWSClient not setup. Use application.aws.client = ...")
                }
                return client
            }
            nonmutating set {
                self.application.storage.set(ClientKey.self, to: newValue) {
                    try $0.syncShutdown()
                }
            }
        }

        let application: Application
    }
}

public extension Request {
    var aws: AWS {
        .init(request: self)
    }

    struct AWS {
        var client: AWSClient {
            return request.application.aws.client
        }

        let request: Request
    }

    #warning("TODO")
    var dynamoDBProvider: DynamoDBProvider {
        .init(client: self.aws.client, tableName: "", region: nil, endpoint: nil)
    }
}

public struct DynamoDBProvider {
    let client: AWSClient
    let tableName: String
    let region: Region?
    let endpoint: String?

    func make() -> (DynamoDB, String) {
        let dynamoDB = DynamoDB(client: client, region: region, endpoint: endpoint)
        return (dynamoDB, tableName)
    }
}
