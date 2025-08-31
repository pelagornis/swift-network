import Foundation

/**
 * Defines the destination for downloaded files.
 * 
 * DownloadDestination specifies where downloaded files should be saved,
 * providing options for common locations like documents and caches,
 * as well as custom destinations.
 * 
 * ## Usage
 * ```swift
 * let destination = DownloadDestination.documents(fileName: "image.jpg")
 * 
 * // Or use custom destination
 * let customDestination = DownloadDestination.custom { tempURL, response in
 *     let fileName = response.suggestedFilename ?? "download"
 *     return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
 * }
 * ```
 */
public enum DownloadDestination: Sendable {
    /// Save file to the app's documents directory
    case documents(fileName: String)
    
    /// Save file to the app's caches directory
    case caches(fileName: String)
    
    /// Use a custom closure to determine the destination URL
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
