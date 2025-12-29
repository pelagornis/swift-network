import Foundation
import NetworkKit

// MARK: - GitHub Response Handler
struct GitHubResponseHandler: ResponseHandler {
    let decoder: JSONDecoder
    
    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }
    
    func handle<T: Decodable>(_ data: Data, response: URLResponse, as type: T.Type) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        let statusCode = Http.StatusCode(from: httpResponse)
        
        // Handle success status codes
        if statusCode.isSuccess {
            return try decoder.decode(type, from: data)
        }
        
        // Handle specific error status codes
        switch statusCode {
        case .unauthorized:
            // Try to decode GitHub error message
            if (try? decoder.decode(GitHubError.self, from: data)) != nil {
                throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
            }
            throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
            
        case .forbidden:
            // Rate limit or forbidden
            throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
            
        case .notFound:
            throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
            
        case .tooManyRequests:
            // GitHub API rate limit
            throw NetworkError.rateLimitExceeded
            
        case .serviceUnavailable, .badGateway, .gatewayTimeout:
            // Server errors that might be retried
            throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
            
        default:
            // Other errors
            throw NetworkError.serverError(statusCode: statusCode.rawValue, data: data)
        }
    }
}

// MARK: - GitHub API Service
public class GitHubService: ObservableObject {
    private let networkProvider: NetworkProvider<GitHubEndpoint>
    
    public init() {
        // Network provider with logging plugin and custom response handler
        let loggingPlugin = LoggingPlugin(logger: ConsoleLogger())
        let responseHandler = GitHubResponseHandler()
        self.networkProvider = NetworkProvider(
            plugins: [loggingPlugin],
            responseHandler: responseHandler
        )
    }
    
    // MARK: - Search Repositories
    public func searchRepositories(query: String, page: Int = 1) async throws -> GitHubSearchResponse {
        let endpoint = GitHubEndpoint.searchRepositories(query: query, page: page)
        return try await networkProvider.request(endpoint, as: GitHubSearchResponse.self)
    }
    
    // MARK: - Get Repository Details
    public func getRepository(owner: String, repo: String) async throws -> GitHubRepository {
        let endpoint = GitHubEndpoint.getRepository(owner: owner, repo: repo)
        return try await networkProvider.request(endpoint, as: GitHubRepository.self)
    }
}

// MARK: - Mock GitHub Service for Preview
public class MockGitHubService: ObservableObject {
    public init() {}
    
    public func searchRepositories(query: String, page: Int = 1) async throws -> GitHubSearchResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let mockRepositories = [
            GitHubRepository(
                id: 1,
                name: "swift-network",
                fullName: "pelagornis/swift-network",
                description: "A modern Swift networking library",
                htmlUrl: "https://github.com/pelagornis/swift-network",
                stargazersCount: 1500,
                language: "Swift",
                owner: RepositoryOwner(
                    login: "pelagornis",
                    id: 123,
                    avatarUrl: "https://avatars.githubusercontent.com/u/123?v=4",
                    htmlUrl: "https://github.com/pelagornis"
                ),
                createdAt: "2023-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z"
            ),
            GitHubRepository(
                id: 2,
                name: "awesome-swift",
                fullName: "example/awesome-swift",
                description: "A curated list of awesome Swift libraries",
                htmlUrl: "https://github.com/example/awesome-swift",
                stargazersCount: 2500,
                language: "Swift",
                owner: RepositoryOwner(
                    login: "example",
                    id: 123,
                    avatarUrl: "https://avatars.githubusercontent.com/u/123?v=4",
                    htmlUrl: "https://github.com/example"
                ),
                createdAt: "2022-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z"
            )
        ]
        
        return GitHubSearchResponse(
            totalCount: mockRepositories.count,
            incompleteResults: false,
            items: mockRepositories
        )
    }
    
    public func getRepository(owner: String, repo: String) async throws -> GitHubRepository {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return GitHubRepository(
            id: 1,
            name: repo,
            fullName: "\(owner)/\(repo)",
            description: "A sample repository for demonstration",
            htmlUrl: "https://github.com/\(owner)/\(repo)",
            stargazersCount: 1000,
            language: "Swift",
            owner: RepositoryOwner(
                login: owner,
                id: 123,
                avatarUrl: "https://avatars.githubusercontent.com/u/123?v=4",
                htmlUrl: "https://github.com/\(owner)"
            ),
            createdAt: "2023-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    }
}
