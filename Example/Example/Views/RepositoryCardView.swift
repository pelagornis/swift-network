import SwiftUI

// MARK: - Repository Card View
public struct RepositoryCardView: View {
    let repository: GitHubRepository
    let onTap: () -> Void
    
    public init(repository: GitHubRepository, onTap: @escaping () -> Void) {
        self.repository = repository
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with owner avatar and name
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: repository.owner.avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(repository.fullName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("by \(repository.owner.login)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Description
                if let description = repository.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                // Stats row
                HStack(spacing: 16) {
                    // Stars
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text("\(repository.stargazersCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Language
                    if let language = repository.language {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(languageColor(for: language))
                                .frame(width: 8, height: 8)
                            
                            Text(language)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Updated date
                    Text("Updated \(formatDate(repository.updatedAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ dateString: String) -> String {
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
    
    private func languageColor(for language: String) -> Color {
        switch language.lowercased() {
        case "swift":
            return .orange
        case "javascript":
            return .yellow
        case "python":
            return .blue
        case "java":
            return .red
        case "kotlin":
            return .purple
        case "go":
            return .cyan
        case "rust":
            return .orange
        case "c++":
            return .pink
        case "c#":
            return .purple
        case "php":
            return .purple
        case "ruby":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Preview
struct RepositoryCardView_Previews: PreviewProvider {
    static var previews: some View {
        RepositoryCardView(
            repository: GitHubRepository(
                id: 1,
                name: "swift-network",
                fullName: "example/swift-network",
                description: "A modern Swift networking library with enterprise-grade features including retry policies, rate limiting, circuit breaker, and caching.",
                htmlUrl: "https://github.com/example/swift-network",
                stargazersCount: 1500,
                language: "Swift",
                owner: RepositoryOwner(
                    login: "example",
                    id: 123,
                    avatarUrl: "https://avatars.githubusercontent.com/u/123?v=4",
                    htmlUrl: "https://github.com/example"
                ),
                createdAt: "2023-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z"
            )
        ) {
            print("Repository tapped")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
