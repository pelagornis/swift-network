import Foundation

public struct BuiltRequest {
    public let urlRequest: URLRequest
    public let downloadDestination: DownloadDestination?
    public init(urlRequest: URLRequest, downloadDestination: DownloadDestination? = nil) {
        self.urlRequest = urlRequest
        self.downloadDestination = downloadDestination
    }
}
