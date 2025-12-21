# Getting Started

Learn how to integrate Swift Network into your project and make your first network request.

## Overview

Swift Network provides a modern, type-safe approach to networking in Swift applications. This guide will walk you through the basic setup and show you how to make your first network request.

## Installation

### Swift Package Manager

Add Swift Network to your project using Swift Package Manager:

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter the repository URL: `https://github.com/your-username/swift-network.git`
3. Select the version you want to use
4. Click **Add Package**

Alternatively, add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/swift-network.git", from: "1.0.0")
]
```

## Basic Setup

### 1. Import the Library

```swift
import NetworkKit
```

### 2. Define Your Endpoint

Create an endpoint that conforms to the `Endpoint` protocol:

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

### 3. Create a Network Provider

```swift
let provider = NetworkProvider<UserEndpoint>()
```

### 4. Make a Request

```swift
do {
    let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
    print("Users: \(users)")
} catch {
    print("Error: \(error)")
}
```

## Complete Example

Here's a complete example showing how to fetch users from an API:

```swift
import NetworkKit

// Define your data model
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

// Define your endpoint
struct UserEndpoint: Endpoint {
    let baseURL = URL(string: "https://api.example.com")!
    let path = "/users"
    let method = Http.Method.get
    let task = Http.Task.requestPlain
    let headers = [Http.Header.accept("application/json")]
    let timeout: TimeInterval? = 30
}

// Create and use the network provider
@main
struct MyApp {
    static func main() async {
        let provider = NetworkProvider<UserEndpoint>()
        
        do {
            let users: [User] = try await provider.request(UserEndpoint(), as: [User].self)
            print("Successfully fetched \(users.count) users")
            
            for user in users {
                print("- \(user.name) (\(user.email))")
            }
        } catch {
            print("Failed to fetch users: \(error)")
        }
    }
}
```

## Next Steps

Now that you have the basics working, explore these topics:

- <doc:BasicUsage> - Learn about more advanced usage patterns
- <doc:Endpoints> - Understand how to create different types of endpoints
- <doc:RequestModifiers> - Add headers, timeouts, and other request modifications
- <doc:Plugins> - Extend functionality with plugins
