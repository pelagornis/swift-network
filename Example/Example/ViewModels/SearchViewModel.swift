import Foundation
import SwiftUI
import NetworkKit

// MARK: - Search View Model
@MainActor
public class SearchViewModel: ObservableObject {
    @Published var repositories: [GitHubRepository] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var totalCount = 0
    
    private let gitHubService: GitHubService
    private var currentPage = 1
    private var hasMorePages = true
    
    public init(gitHubService: GitHubService = GitHubService()) {
        self.gitHubService = gitHubService
    }
    
    // MARK: - Search Repositories
    public func searchRepositories() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            repositories = []
            totalCount = 0
            return
        }
        
        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMorePages = true
        
        do {
            let response = try await gitHubService.searchRepositories(query: searchText, page: currentPage)
            repositories = response.items
            totalCount = response.totalCount
            hasMorePages = response.items.count >= 20 // GitHub API default per page
        } catch {
            errorMessage = handleError(error)
            repositories = []
            totalCount = 0
        }
        
        isLoading = false
    }
    
    // MARK: - Load More Repositories
    public func loadMoreRepositories() async {
        guard hasMorePages && !isLoading else { return }
        
        currentPage += 1
        isLoading = true
        
        do {
            let response = try await gitHubService.searchRepositories(query: searchText, page: currentPage)
            repositories.append(contentsOf: response.items)
            hasMorePages = response.items.count >= 20
        } catch {
            errorMessage = handleError(error)
            currentPage -= 1 // Revert page increment on error
        }
        
        isLoading = false
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) -> String {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .serverError(let statusCode, let data):
                let httpStatusCode = Http.StatusCode(rawValue: statusCode)
                return getErrorMessage(for: httpStatusCode, data: data)
                
            case .rateLimitExceeded:
                return "Rate limit exceeded. Please try again later."
                
            case .requestFailed(let urlError):
                return "Network request failed: \(urlError.localizedDescription)"
                
            case .decodingError(let error):
                return "Failed to parse response: \(error.localizedDescription)"
                
            case .circuitBreakerOpen:
                return "Service temporarily unavailable. Please try again later."
                
            default:
                return "An error occurred: \(networkError.localizedDescription)"
            }
        }
        
        return error.localizedDescription
    }
    
    private func getErrorMessage(for statusCode: Http.StatusCode, data: Data) -> String {
        switch statusCode {
        case .unauthorized:
            // Try to decode GitHub error message
            if let gitHubError = try? JSONDecoder().decode(GitHubError.self, from: data) {
                return "Authentication failed: \(gitHubError.message)"
            }
            return "Unauthorized. Please check your authentication."
            
        case .forbidden:
            if let gitHubError = try? JSONDecoder().decode(GitHubError.self, from: data) {
                return "Access forbidden: \(gitHubError.message)"
            }
            return "Access forbidden. You may not have permission to access this resource."
            
        case .notFound:
            return "Repository not found. Please check your search query."
            
        case .tooManyRequests:
            return "Too many requests. GitHub API rate limit exceeded. Please try again later."
            
        case .serviceUnavailable:
            return "GitHub service is temporarily unavailable. Please try again later."
            
        case .badGateway, .gatewayTimeout:
            return "GitHub API is experiencing issues. Please try again later."
            
        case .badRequest:
            if let gitHubError = try? JSONDecoder().decode(GitHubError.self, from: data) {
                return "Invalid request: \(gitHubError.message)"
            }
            return "Bad request. Please check your search query."
            
        default:
            if statusCode.isClientError {
                return "Client error (\(statusCode.rawValue)): \(statusCode.description)"
            } else if statusCode.isServerError {
                return "Server error (\(statusCode.rawValue)): \(statusCode.description)"
            } else {
                return "Unexpected error: \(statusCode.description)"
            }
        }
    }
    
    // MARK: - Clear Search
    public func clearSearch() {
        searchText = ""
        repositories = []
        totalCount = 0
        errorMessage = nil
        currentPage = 1
        hasMorePages = true
    }
    
    // MARK: - Format Star Count
    public func formatStarCount(_ count: Int) -> String {
        if count >= 1000 {
            let formatted = Double(count) / 1000.0
            return String(format: "%.1fk", formatted)
        }
        return "\(count)"
    }
    
    // MARK: - Format Date
    public func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}
