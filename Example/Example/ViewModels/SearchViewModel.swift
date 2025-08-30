import Foundation
import SwiftUI

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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
            currentPage -= 1 // Revert page increment on error
        }
        
        isLoading = false
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
