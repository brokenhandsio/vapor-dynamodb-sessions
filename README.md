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

A simple library to use DynamoDB to back Vapor's sessions

## Installation

Add the library in your dependencies array in **Package.swift**:

```swift
dependencies: [
    // ...,
    .package(name: "VaporDynamoDBSessions", url: "https://github.com/brokenhandsio/vapor-dynamodb-sessions.git", from: "1.0.0")
],
```

Also ensure you add it as a dependency to your target:

```swift
targets: [
    .target(name: "App", dependencies: [
        .product(name: "Vapor", package: "vapor"), 
        // ..., 
        .product(name: "VaporDynamoDBSessions", package: "vapor-dynamodb-sessions")
    ]),
    // ...
]
```

## Usage

You must be using the `SessionsMiddleware` on all routes you interact with CSRF with. You can enable this globally in **configure.swift** with:

```swift
app.middleware.use(app.sessions.middleware)
```

For more information on sessions, [see the documentation](https://docs.vapor.codes/4.0/sessions/).

### GET routes

In GET routes that could return a POST request you want to protect, store a CSRF token in the session:

```swift
let csrfToken = req.csrf.storeToken()
```

This function returns a token you can then pass to your HTML page. For example, with Leaf this would look like:

```swift
let csrfToken = req.csrf.storeToken()
let context = MyPageContext(csrfToken: csrfToken)
return req.view.render("myPage", context)
```

You then need to return the token when the form is submitted. With Leaf, this would look something like:

```html
<form method="post">
    <input type="hidden" name="csrfToken" value="#(csrfToken)">
    <input type="submit" value="Submit">
</form>
```

### POST routes

You can protect your POST routes either with Middleware or manually verifying the token.

#### Middleware

VaporCSRF provides a middleware that checks the token for you. You can apply this to your routes with:

```swift
let csrfTokenPotectedRoutes = app.grouped(CSRFMiddleware())
```

#### Manual Verification

If you want to control when you verify the CSRF token, you can do this manually in your route handler with `try req.csrf.verifyToken()`. E.g.:

```swift
app.post("myForm") { req -> EventLoopFuture<Response> in
    try req.csrf.verifyToken()
    // ...
}
```

### Configuration

By default, VaporCSRF looks for a value with the key `csrfToken` in the POST body. You can change the key with:

```swift
app.csrf.setTokenContentKey("aDifferentKey")
```