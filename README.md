# Vapor DynamoDB Sessions

<p align="center">
    <a href="https://vapor.codes">
        <img src="http://img.shields.io/badge/Vapor-4-brightgreen.svg" alt="Language">
    </a>
    <a href="https://swift.org">
        <img src="http://img.shields.io/badge/Swift-5.2-brightgreen.svg" alt="Language">
    </a>
    <a href="https://github.com/brokenhandsio/vapor-dynamodb-sessions/actions">
         <img src="https://github.com/brokenhandsio/vapor-dynamodb-sessions/workflows/CI/badge.svg?branch=main" alt="Build Status">
    <a href="https://codecov.io/gh/brokenhandsio/vapor-dynamodb-sessions">
        <img src="https://codecov.io/gh/brokenhandsio/vapor-dynamodb-sessions/branch/main/graph/badge.svg" alt="Code Coverage">
    </a>
    <a href="https://raw.githubusercontent.com/brokenhandsio/vapor-dynamodb-sessions/main/LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
    </a>
</p>

A simple library to use DynamoDB with [Soto](https://github.com/soto-project/soto) to back Vapor's sessions.

## Installation

Add the library in your dependencies array in **Package.swift**:

```swift
dependencies: [
    // ...,
    package(name: "VaporDynamoDBSessions", url: "https://github.com/brokenhandsio/vapor-dynamodb-sessions.git", from: "1.0.0"),
],
```

Also ensure you add it as a dependency to your target:

```swift
targets: [
    .target(name: "App", dependencies: [
        .product(name: "Vapor", package: "vapor"), 
        // ..., 
        .product(name: "VaporDynamoDBSessions", package: "VaporDynamoDBSessions")
    ]),
    // ...
]
```

## Usage

To start, you must configure the `DynamoDBSessionsProvider` with the `AWSClient` and a table name. In **configure.swift** set the provider on the application:

```swift
app.dynamoDBSessions.provider = DynamoDBSessionsProvider(client: app.aws.client, tableName: tableName)
```

The `DynamoDBSessionsProvider` also takes an optional AWS `region` and endpoint if you need to configure these. To learn how to configure the `AWSClient` see the [Soto Documentation](https://soto.codes/user-guides/using-soto-with-vapor.html).

Next, tell Vapor to use DynamoDB for sessions:

```swift
app.sessions.use(.dynamodb)
app.middleware.use(app.sessions.middleware)
```

**Note**: You must set DynamoDB as the `SessionDriver` before adding the `SessionsMiddleware`.

### Database Requirements

`VaporDynamoDBSessions` will work with its own table or as part of an application using a [single-table design](https://www.alexdebrie.com/posts/dynamodb-single-table/). The only requirements for the library to work is that the table must have a partition key named `pk` and a sort key named `sk`.
