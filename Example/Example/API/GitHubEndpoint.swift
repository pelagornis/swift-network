import Foundation
import NetworkKit

// MARK: - GitHub API Endpoints
public enum GitHubEndpoint: Endpoint {
    case searchRepositories(query: String, page: Int = 1, perPage: Int = 20)
    case getRepository(owner: String, repo: String)
    
    public var baseURL: URL {
        return URL(string: "https://api.github.com")!
    }
    
    public var path: String {
        switch self {
        case .searchRepositories:
            return "/search/repositories"
        case .getRepository(let owner, let repo):
            return "/repos/\(owner)/\(repo)"
        }
    }
    
    public var method: Http.Method {
        switch self {
        case .searchRepositories, .getRepository:
            return .get
        }
    }
    
    public var task: Http.Task {
        switch self {
        case .searchRepositories(let query, let page, let perPage):
            let parameters = [
                "q": query,
                "page": "\(page)",
                "per_page": "\(perPage)",
                "sort": "stars",
                "order": "desc"
            ]
            return .requestParameters(parameters, encoding: .url)
        case .getRepository:
            return .requestPlain
        }
    }
    
    public var headers: [Http.Header] {
        return [
            .accept("application/vnd.github.v3+json"),
            .userAgent("GitHubSearchApp/1.0")
        ]
    }
    
    public var timeout: TimeInterval? {
        return 30.0
    }
}
