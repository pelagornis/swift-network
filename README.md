# Swift Network

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
    .package(url: "https://github.com/your-username/swift-network.git", from: "1.0.0")
]
```

Or add it directly in Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Quick Start

### Basic Usage

```swift
import Network

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
import Network

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
@testable import Network

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

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
