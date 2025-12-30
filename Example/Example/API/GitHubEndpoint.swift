import Foundation
import NetworkKit

// MARK: - GitHub API Endpoints
public enum GitHubEndpoint: Endpoint {
    case searchRepositories(query: String, page: Int = 1, perPage: Int = 20)
    case getRepository(owner: String, repo: String)
    
    // Base endpoint with common settings
    private static var baseEndpoint: HTTPEndpoint {
        HTTP {
            BaseURL("https://api.github.com")
            Headers([
                .accept("application/vnd.github.v3+json"),
                .userAgent("GitHubSearchApp/1.0")
            ])
            Timeout(30.0)
        }
    }

    public var body: HTTPEndpoint {
        switch self {
        case .searchRepositories(let query, let page, let perPage):
            let parameters = [
                "q": query,
                "page": "\(page)",
                "per_page": "\(perPage)",
                "sort": "stars",
                "order": "desc"
            ]
            return HTTP(base: Self.baseEndpoint) {
                Path("/search/repositories")
                Method(.get)
                HTTPTask(.requestParameters(parameters, encoding: .url))
            }
        case .getRepository(let owner, let repo):
            return HTTP(base: Self.baseEndpoint) {
                Path("/repos/\(owner)/\(repo)")
                Method(.get)
                HTTPTask(.requestPlain)
            }
        }
    }
}
