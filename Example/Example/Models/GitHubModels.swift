import Foundation

// MARK: - GitHub Repository Model
public struct GitHubRepository: Codable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String?
    public let htmlUrl: String
    public let stargazersCount: Int
    public let language: String?
    public let owner: RepositoryOwner
    public let createdAt: String
    public let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case description
        case htmlUrl = "html_url"
        case stargazersCount = "stargazers_count"
        case language
        case owner
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Repository Owner Model
public struct RepositoryOwner: Codable, Sendable {
    public let login: String
    public let id: Int
    public let avatarUrl: String
    public let htmlUrl: String
    
    enum CodingKeys: String, CodingKey {
        case login
        case id
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}

// MARK: - GitHub Search Response Model
public struct GitHubSearchResponse: Codable, Sendable {
    public let totalCount: Int
    public let incompleteResults: Bool
    public let items: [GitHubRepository]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

// MARK: - GitHub Error Model
public struct GitHubError: Codable, LocalizedError {
    public let message: String
    public let documentationUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
    }
    
    public var errorDescription: String? {
        return message
    }
}
