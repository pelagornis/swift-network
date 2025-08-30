# Basic Usage

Learn the fundamental concepts and patterns for using Swift Network effectively.

## Overview

This guide covers the essential patterns and concepts you'll use most often with Swift Network, including endpoint creation, request modifiers, and error handling.

## Creating Endpoints

Endpoints define your API endpoints using the `Endpoint` protocol. Here are common patterns:

### Simple GET Request

```swift
struct UserEndpoint: Endpoint {
    let baseURL = URL(string: "https://api.example.com")!
    let path = "/users"
    let method = Http.Method.get
    let task = Http.Task.requestPlain
    let headers = [Http.Header.accept("application/json")]
    let timeout: TimeInterval? = 30
}
```

### POST Request with JSON Body

```swift
struct CreateUserEndpoint: Endpoint {
    let baseURL = URL(string: "https://api.example.com")!
    let path = "/users"
    let method = Http.Method.post
    let task: Http.Task
    let headers = [Http.Header.contentType("application/json")]
    let timeout: TimeInterval? = 30
    
    init(user: CreateUserRequest) {
        self.task = Http.Task.requestJSON(user)
    }
}

struct CreateUserRequest: Codable {
    let name: String
    let email: String
}
```

### Parameterized Endpoint

```swift
struct UserDetailEndpoint: Endpoint {
    let baseURL = URL(string: "https://api.example.com")!
    let path: String
    let method = Http.Method.get
    let task = Http.Task.requestPlain
    let headers = [Http.Header.accept("application/json")]
    let timeout: TimeInterval? = 30
    
    init(userId: Int) {
        self.path = "/users/\(userId)"
    }
}
```

## Using Request Modifiers

Request modifiers allow you to dynamically modify requests:

### Adding Headers

```swift
let authModifier = HeaderModifier(key: "Authorization", value: "Bearer \(token)")
let customModifier = HeaderModifier(key: "X-Custom", value: "value")

let users: [User] = try await provider.request(
    UserEndpoint(), 
    as: [User].self, 
    modifiers: [authModifier, customModifier]
)
```

### Setting Timeout

```swift
let timeoutModifier = TimeoutModifier(timeout: 60)

let users: [User] = try await provider.request(
    UserEndpoint(), 
    as: [User].self, 
    modifiers: [timeoutModifier]
)
```

### Multiple Modifiers

```swift
let modifiers: [RequestModifier] = [
    HeaderModifier(key: "Authorization", value: "Bearer \(token)"),
    TimeoutModifier(timeout: 60),
    CachePolicyModifier(policy: .reloadIgnoringLocalCacheData)
]

let users: [User] = try await provider.request(
    UserEndpoint(), 
    as: [User].self, 
    modifiers: modifiers
)
```

## Error Handling

Swift Network provides comprehensive error handling:

### Basic Error Handling

```swift
do {
    let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
    // Handle success
} catch {
    // Handle error
    print("Request failed: \(error)")
}
```

### Specific Error Types

```swift
do {
    let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
} catch NetworkError.serverError(let statusCode, let data) {
    print("Server error: \(statusCode)")
    // Handle server error
} catch NetworkError.requestFailed(let urlError) {
    print("Network error: \(urlError.localizedDescription)")
    // Handle network error
} catch NetworkError.decodingError(let error) {
    print("Decoding error: \(error)")
    // Handle decoding error
} catch {
    print("Unexpected error: \(error)")
}
```

## Using Plugins

Plugins extend the functionality of your network requests:

### Logging Plugin

```swift
let loggingPlugin = LoggingPlugin(logger: ConsoleLogger(level: .info))
let provider = NetworkProvider<UserEndpoint>(plugins: [loggingPlugin])

// All requests will now be logged
let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
```

### Custom Plugin

```swift
class AuthenticationPlugin: NetworkPlugin {
    func willSend(_ request: URLRequest, target: Endpoint) {
        // Add authentication headers
        var modifiedRequest = request
        modifiedRequest.setValue("Bearer \(getToken())", forHTTPHeaderField: "Authorization")
    }
    
    func didReceive(_ result: Result<(Data, URLResponse), Error>, target: Endpoint) {
        // Handle authentication errors
        if case .failure(let error) = result {
            // Handle token refresh, etc.
        }
    }
    
    private func getToken() -> String {
        // Return current authentication token
        return "your-token"
    }
}

let authPlugin = AuthenticationPlugin()
let provider = NetworkProvider<UserEndpoint>(plugins: [authPlugin])
```

## Best Practices

### 1. Reuse Network Providers

Create network providers once and reuse them:

```swift
class NetworkService {
    private let provider: NetworkProvider<UserEndpoint>
    
    init() {
        self.provider = NetworkProvider<UserEndpoint>(
            plugins: [LoggingPlugin(logger: ConsoleLogger(level: .info))]
        )
    }
    
    func fetchUsers() async throws -> [User] {
        return try await provider.request(UserEndpoint(), as: [User].self)
    }
}
```

### 2. Use Type-Safe Endpoints

Leverage Swift's type system for better safety:

```swift
// Good: Type-safe endpoint
struct UserEndpoint: Endpoint {
    let baseURL = URL(string: "https://api.example.com")!
    let path = "/users"
    // ... other properties
}

// Avoid: String-based URLs
let url = "https://api.example.com/users" // Less type-safe
```

### 3. Handle Errors Appropriately

Provide meaningful error handling:

```swift
enum NetworkServiceError: Error {
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
}

func fetchUsers() async throws -> [User] {
    do {
        return try await provider.request(UserEndpoint(), as: [User].self)
    } catch NetworkError.serverError(let statusCode, _) {
        throw NetworkServiceError.serverError(statusCode)
    } catch {
        throw NetworkServiceError.networkError(error)
    }
}
```

## Next Steps

Now that you understand the basics, explore these advanced topics:

- <doc:Endpoints> - Learn more about endpoint patterns
- <doc:RequestModifiers> - Discover all available modifiers
- <doc:Plugins> - Create custom plugins
- <doc:EnterpriseFeatures> - Use enterprise-grade features
