import SwiftUI

// MARK: - Search View
public struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showingRepositoryDetail = false
    @State private var selectedRepository: GitHubRepository?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                // Content
                if viewModel.repositories.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    repositoryListView
                }
            }
            .navigationTitle("GitHub Search")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingRepositoryDetail) {
                if let repository = selectedRepository {
                    RepositoryDetailView(repository: repository)
                }
            }
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search repositories...", text: $viewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            Task {
                                await viewModel.searchRepositories()
                            }
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                if !viewModel.searchText.isEmpty {
                    Button("Search") {
                        Task {
                            await viewModel.searchRepositories()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // Results Count
            if viewModel.totalCount > 0 {
                HStack {
                    Text("\(viewModel.totalCount) repositories found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Search GitHub Repositories")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter a search term to find repositories on GitHub")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Repository List View
    private var repositoryListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.repositories) { repository in
                    RepositoryCardView(repository: repository) {
                        selectedRepository = repository
                        showingRepositoryDetail = true
                    }
                    .padding(.horizontal, 16)
                    
                    // Load more trigger
                    if repository.id == viewModel.repositories.last?.id {
                        loadMoreView
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.searchRepositories()
        }
    }
    
    // MARK: - Load More View
    private var loadMoreView: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else {
                Button("Load More") {
                    Task {
                        await viewModel.loadMoreRepositories()
                    }
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadMoreRepositories()
            }
        }
    }
}

// MARK: - Repository Detail View
public struct RepositoryDetailView: View {
    let repository: GitHubRepository
    @Environment(\.dismiss) private var dismiss
    
    public init(repository: GitHubRepository) {
        self.repository = repository
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            AsyncImage(url: URL(string: repository.owner.avatarUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(repository.fullName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("by \(repository.owner.login)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        if let description = repository.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Stats
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(repository.stargazersCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Stars")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let language = repository.language {
                            VStack {
                                Text(language)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Language")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Links
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Links")
                            .font(.headline)
                        
                        Link(destination: URL(string: repository.htmlUrl)!) {
                            HStack {
                                Image(systemName: "link")
                                Text("View on GitHub")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Repository Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
