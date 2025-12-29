# Swift NetworkKit

![Official](https://badge.pelagornis.com/official.svg)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20visionOS%20%7C%20watchOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A modern, protocol-oriented Swift networking library with enterprise-grade features.

## Features

- 🚀 **Protocol-Oriented Design** - Built with Swift protocols for maximum flexibility
- 🔌 **Plugin System** - Extensible plugin architecture for logging, caching, and more
- 🛡️ **Enterprise Features** - Retry policies, circuit breakers, rate limiting, and security
- 📊 **Metrics & Monitoring** - Built-in metrics collection and monitoring
- 🔄 **Request Modifiers** - Chainable request modifications
- 🎯 **Type Safety** - Full type safety with generics and protocols
- ⚡ **Async/Await** - Modern Swift concurrency support
- 🧪 **Testable** - Designed for easy testing and mocking

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pelagornis/swift-network.git", from: "vTag")
]
```

Or add it directly in Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Documentation

The documentation for releases and `main` are available here:

- [`main`](https://pelagornis.github.io/swift-network/main/documentation/networkkit)

## Quick Start

### Basic Usage

```swift
import NetworkKit

// Define your endpoint
struct UserEndpoint: Endpoint {
    let baseURL = URL(string: "https://api.example.com")!
    let path = "/users"
    let method = Http.Method.get
    let task = Http.Task.requestPlain
    let headers = [Http.Header.accept("application/json")]
    let timeout: TimeInterval? = 30
}

// Create a network provider
let provider = NetworkProvider<UserEndpoint>()

// Make a request
do {
    let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
    print("Users: \(users)")
} catch {
    print("Error: \(error)")
}
```

### With Enterprise Features

```swift
import NetworkKit

// Configure enterprise features
let retryPolicy = ExponentialBackoffRetryPolicy(maxAttempts: 3)
let rateLimiter = TokenBucketRateLimiter(config: RateLimitConfig(maxRequests: 100, timeWindow: 60))
let circuitBreaker = DefaultCircuitBreaker(config: CircuitBreakerConfig())
let cacheManager = MemoryCacheManager()
let metricsCollector = DefaultMetricsCollector()

// Create enterprise-ready provider
let provider = NetworkProvider<UserEndpoint>(
    retryPolicy: retryPolicy,
    rateLimiter: rateLimiter,
    circuitBreaker: circuitBreaker,
    cacheManager: cacheManager,
    metricsCollector: metricsCollector
)

// Make a request with all enterprise features
do {
    let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
    print("Users: \(users)")

    // Access metrics
    if let metrics = provider.getMetrics() {
        print("Request count: \(metrics.requestCount)")
        print("Average response time: \(metrics.averageResponseTime)")
    }
} catch {
    print("Error: \(error)")
}
```

## Core Concepts

### Endpoints

Endpoints define your API endpoints using the `Endpoint` protocol:

```swift
struct UserEndpoint: Endpoint {
    let baseURL = URL(string: "https://api.example.com")!
    let path = "/users"
    let method = Http.Method.get
    let task = Http.Task.requestPlain
    let headers = [Http.Header.accept("application/json")]
    let timeout: TimeInterval? = 30
}

struct CreateUserEndpoint: Endpoint {
    let baseURL = URL(string: "https://api.example.com")!
    let path = "/users"
    let method = Http.Method.post
    let task = Http.Task.requestJSON(User(name: "John", email: "john@example.com"))
    let headers = [Http.Header.contentType("application/json")]
    let timeout: TimeInterval? = 30
}
```

### Request Modifiers

Modify requests dynamically:

```swift
let modifiers: [RequestModifier] = [
    HeaderModifier(key: "Authorization", value: "Bearer token"),
    TimeoutModifier(timeout: 60),
    CachePolicyModifier(policy: .reloadIgnoringLocalCacheData)
]

let users: [User] = try await provider.request(
    UserEndpoint(),
    as: [User].self,
    modifiers: modifiers
)
```

### Plugins

Extend functionality with plugins:

```swift
// Logging plugin
let loggingPlugin = LoggingPlugin(logger: ConsoleLogger(level: .info))

// Rate limiting plugin
let rateLimitingPlugin = RateLimitingPlugin(rateLimiter: rateLimiter)

// Circuit breaker plugin
let circuitBreakerPlugin = CircuitBreakerPlugin(circuitBreaker: circuitBreaker)

let provider = NetworkProvider<UserEndpoint>(
    plugins: [loggingPlugin, rateLimitingPlugin, circuitBreakerPlugin]
)
```

### Status Code Handling

NetworkKit automatically handles HTTP status codes:

- **2xx (200-299)**: Success - Response is decoded and returned
- **Other status codes**: Error - Throws `NetworkError.serverError` with status code and response data

NetworkKit provides a comprehensive `Http.StatusCode` enum with all standard HTTP status codes for type-safe status code handling.

#### Using Status Code Enum

```swift
import NetworkKit

// Create status code from integer
let statusCode = Http.StatusCode(rawValue: 404)
print(statusCode) // .notFound
print(statusCode.rawValue) // 404
print(statusCode.description) // "Not Found"

// Check status code category
if statusCode.isClientError {
    print("This is a client error")
}

// Create from HTTPURLResponse
if let httpResponse = response as? HTTPURLResponse {
    let statusCode = Http.StatusCode(from: httpResponse)
    print("Status: \(statusCode.description)")
}
```

#### Basic Status Code Handling

```swift
do {
    let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
    // Success - status code is 2xx
} catch NetworkError.serverError(let statusCode, let data) {
    // Convert integer status code to enum
    let httpStatusCode = Http.StatusCode(rawValue: statusCode)

    switch httpStatusCode {
    case .badRequest:
        print("Bad Request")
    case .unauthorized:
        print("Unauthorized")
    case .notFound:
        print("Not Found")
    case .internalServerError:
        print("Internal Server Error")
    case .serviceUnavailable:
        print("Service Unavailable")
    default:
        print("Server error: \(httpStatusCode.description) (\(statusCode))")
    }

    // Access response data if needed
    if let errorMessage = String(data: data, encoding: .utf8) {
        print("Error message: \(errorMessage)")
    }
} catch {
    print("Other error: \(error)")
}
```

#### Status Code Categories

```swift
let statusCode = Http.StatusCode(rawValue: 200)

// Check status code category
if statusCode.isSuccess {
    print("Request succeeded")
}

if statusCode.isClientError {
    print("Client error occurred")
}

if statusCode.isServerError {
    print("Server error occurred")
}

if statusCode.isRedirection {
    print("Redirection required")
}

if statusCode.isInformational {
    print("Informational response")
}
```

#### Custom Status Code Handling

You can create a custom `ResponseHandler` to handle specific status codes differently using the `StatusCode` enum:

```swift
struct CustomResponseHandler: ResponseHandler {
    let decoder: JSONDecoder

    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    func handle<T: Decodable>(_ data: Data, response: URLResponse, as type: T.Type) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        let statusCode = Http.StatusCode(from: httpResponse)

        switch statusCode {
        case .ok, .created, .accepted, .noContent:
            // Success - decode and return
            return try decoder.decode(type, from: data)
        case .unauthorized:
            // Unauthorized - throw specific error
            throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
        case .notFound:
            // Not Found - return empty result or throw
            throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
        case .tooManyRequests:
            // Rate limited - special handling
            throw NetworkError.rateLimitExceeded
        default:
            if statusCode.isServerError {
                // Retry server errors
                throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
            } else {
                // Other client errors
                throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
            }
        }
    }
}

// Use custom response handler
let customHandler = CustomResponseHandler()
let provider = NetworkProvider<UserEndpoint>(responseHandler: customHandler)
```

#### Status Code Validation

The default `ResponseHandler` validates that status codes are in the 200-299 range. You can customize this behavior using the `StatusCode` enum:

```swift
struct PermissiveResponseHandler: ResponseHandler {
    let decoder: JSONDecoder

    func handle<T: Decodable>(_ data: Data, response: URLResponse, as type: T.Type) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        let statusCode = Http.StatusCode(from: httpResponse)

        // Allow 2xx and 3xx status codes
        guard statusCode.isSuccess || statusCode.isRedirection else {
            throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
        }

        return try decoder.decode(type, from: data)
    }
}
```

#### Available Status Codes

The `Http.StatusCode` enum includes all standard HTTP status codes:

- **1xx Informational**: `continue`, `switchingProtocols`, `processing`, `earlyHints`
- **2xx Success**: `ok`, `created`, `accepted`, `noContent`, `partialContent`, etc.
- **3xx Redirection**: `movedPermanently`, `found`, `seeOther`, `notModified`, `temporaryRedirect`, etc.
- **4xx Client Error**: `badRequest`, `unauthorized`, `forbidden`, `notFound`, `methodNotAllowed`, `tooManyRequests`, etc.
- **5xx Server Error**: `internalServerError`, `badGateway`, `serviceUnavailable`, `gatewayTimeout`, etc.

For a complete list, see the `Http.StatusCode` enum definition in the source code.

## Enterprise Features

### Retry Policies

```swift
// Exponential backoff
let exponentialRetry = ExponentialBackoffRetryPolicy(maxAttempts: 3)

// Fixed delay
let fixedRetry = FixedDelayRetryPolicy(maxAttempts: 3, delay: 1.0)

// Custom retry
let customRetry = CustomRetryPolicy { error, attempt, request in
    // Custom retry logic
    return attempt < 3 && error is NetworkError.serverError
}
```

### Circuit Breaker

```swift
let config = CircuitBreakerConfig(
    failureThreshold: 5,
    recoveryTimeout: 30,
    expectedFailureRate: 0.5
)

let circuitBreaker = DefaultCircuitBreaker(config: config)

// Check state
if let state = provider.getCircuitBreakerState() {
    switch state {
    case .closed:
        print("Circuit breaker is closed - requests allowed")
    case .open:
        print("Circuit breaker is open - requests blocked")
    case .halfOpen:
        print("Circuit breaker is half-open - limited requests allowed")
    }
}
```

### Rate Limiting

```swift
// Token bucket rate limiter
let tokenBucket = TokenBucketRateLimiter(
    config: RateLimitConfig(maxRequests: 100, timeWindow: 60, burstSize: 10)
)

// Sliding window rate limiter
let slidingWindow = SlidingWindowRateLimiter(
    config: RateLimitConfig(maxRequests: 100, timeWindow: 60)
)

// Endpoint-specific rate limiting
let endpointConfigs = [
    "api.example.com-/users-GET": RateLimitConfig(maxRequests: 50, timeWindow: 60),
    "api.example.com-/posts-GET": RateLimitConfig(maxRequests: 200, timeWindow: 60)
]

let endpointLimiter = EndpointSpecificRateLimiter(
    defaultConfig: RateLimitConfig(maxRequests: 100, timeWindow: 60),
    endpointConfigs: endpointConfigs
)
```

### Security

```swift
let securityManager = DefaultSecurityManager()

// Add certificate pinning
if let certificate = loadCertificate() {
    securityManager.addCertificatePinning(certificate, for: "api.example.com")
}

// Configure SSL validation
securityManager.allowInvalidCertificates = false
```

### Caching

```swift
let cacheManager = MemoryCacheManager()

// Cache with expiration
cacheManager.set(user, for: "user:123", expiration: 300) // 5 minutes

// Get cached data
if let cachedUser: User = cacheManager.get(for: "user:123", as: User.self) {
    print("Cached user: \(cachedUser)")
}

// Clear cache
cacheManager.clear()
```

### Metrics

```swift
let metricsCollector = DefaultMetricsCollector()

// Get metrics
if let metrics = provider.getMetrics() {
    print("Total requests: \(metrics.requestCount)")
    print("Successful requests: \(metrics.successCount)")
    print("Failed requests: \(metrics.failureCount)")
    print("Average response time: \(metrics.averageResponseTime)")
    print("Cache hit rate: \(metrics.cacheHitRate)")
}

// Reset metrics
provider.resetMetrics()
```

## Testing

The library is designed for easy testing:

```swift
import XCTest
@testable import NetworkKit

class NetworkTests: XCTestCase {
    func testNetworkRequest() async throws {
        // Create mock session
        let mockSession = MockSession()
        mockSession.mockResponse = (Data(), URLResponse())

        // Create provider with mock session
        let provider = NetworkProvider<UserEndpoint>(session: mockSession)

        // Test request
        let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
        XCTAssertNotNil(users)
    }
}
```

## Architecture

The library follows a protocol-oriented design with clear separation of concerns:

- **`Endpoint`** - Defines API endpoints
- **`NetworkProvider`** - Main networking class with enterprise features
- **`Session`** - Handles actual network requests
- **`NetworkPlugin`** - Extensible plugin system
- **`RequestModifier`** - Chainable request modifications
- **`ResponseHandler`** - Handles response processing
- **`CacheManager`** - Caching functionality
- **`NetworkLogger`** - Logging system

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

## License

**swift-network** is under MIT license. See the [LICENSE](LICENSE) file for more info.
