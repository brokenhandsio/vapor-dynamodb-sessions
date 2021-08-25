import Vapor

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

