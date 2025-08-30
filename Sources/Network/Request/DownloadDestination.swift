import Foundation

public enum DownloadDestination: Sendable {
    case documents(fileName: String)
    case caches(fileName: String)
    case custom(@Sendable (URL, URLResponse) -> URL)

    func resolvedURL(tempLocalURL: URL, response: URLResponse) -> URL {
        switch self {
        case .documents(let fileName):
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return folder.appendingPathComponent(fileName)
        case .caches(let fileName):
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            return folder.appendingPathComponent(fileName)
        case .custom(let block):
            return block(tempLocalURL, response)
        }
    }
}
