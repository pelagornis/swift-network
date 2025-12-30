# GitHub Search App Example

This example app demonstrates how to use the `swift-network` library to call the GitHub API and search for repositories in a SwiftUI app.

## Features

- 🔍 GitHub repository search
- 📱 Modern SwiftUI-based UI
- 🌐 API calls using the Network library
- 📄 Infinite scroll (pagination)
- 🔄 Pull-to-refresh
- 📊 Repository detail information display
- 🎨 Programming language color coding
- ⭐ Star count display

## Running the App

### 1. Navigate to Directory

```bash
cd Example/Example
```

### 2. Build and Run

```bash
swift run
```

### 3. Run on iOS Simulator

```bash
swift run --configuration release
```

## App Structure

```
Example/
├── GitHubSearchApp.swift          # Main app file
├── Models/
│   └── GitHubModels.swift         # GitHub API models
├── API/
│   ├── GitHubEndpoint.swift       # API endpoint definitions
│   └── GitHubService.swift        # API service class
├── ViewModels/
│   └── SearchViewModel.swift      # Search view model
└── Views/
    ├── SearchView.swift           # Main search view
    └── RepositoryCardView.swift   # Repository card view
```

## Network Library Usage Examples

### 1. Endpoint Definition

```swift
public enum GitHubEndpoint: Endpoint {
    case searchRepositories(query: String, page: Int = 1, perPage: Int = 20)

    public var body: HTTPEndpoint {
        switch self {
        case .searchRepositories(let query, let page, let perPage):
            return HTTP {
                BaseURL("https://api.github.com")
                Path("/search/repositories")
                Method(.get)
                HTTPTask(.requestParameters([...], encoding: .url))
            }
        }
    }
}
```

### 2. Network Provider Setup

```swift
public class GitHubService: ObservableObject {
    private let networkProvider: NetworkProvider<GitHubEndpoint>

    public init() {
        // Initialize Network Provider with logging plugin
        let loggingPlugin = LoggingPlugin(logger: ConsoleLogger())
        self.networkProvider = NetworkProvider(plugins: [loggingPlugin])
    }
}
```

### 3. API Call

```swift
public func searchRepositories(query: String, page: Int = 1) async throws -> GitHubSearchResponse {
    let endpoint = GitHubEndpoint.searchRepositories(query: query, page: page)
    return try await networkProvider.request(endpoint, as: GitHubSearchResponse.self)
}
```

## Key Features

### 1. Protocol-Oriented Design

- Type-safe API definitions using the `Endpoint` protocol
- Consistent networking interface through `NetworkProvider`

### 2. Plugin System

- Request/response logging using `LoggingPlugin`
- Extensible plugin architecture

### 3. Error Handling

- Systematic error handling through `NetworkError`
- User-friendly error message display

### 4. Modern Swift Features

- Asynchronous programming using `async/await`
- UI updates using `@MainActor`
- Reactive UI using SwiftUI's `@StateObject` and `@Published`

## Screenshots

The app includes the following screens:

1. **Search Screen**: Repository search input and results list
2. **Repository Card**: Basic information display for each repository
3. **Detail Screen**: Detailed information for the selected repository

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 6.0+
- Xcode 15.0+

## License

This example app is distributed under the MIT license.
