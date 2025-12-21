import Foundation

/**
 * A built network request ready for execution.
 * 
 * BuiltRequest contains a fully configured URLRequest along with any
 * additional metadata needed for request execution, such as download
 * destinations for file downloads.
 * 
 * This struct is the final output of the request building process and
 * is used by the networking system to execute requests.
 */
public struct BuiltRequest {
    /// The fully configured URLRequest ready for execution
    public let urlRequest: URLRequest
    
    /// Optional download destination for file download requests
    public let downloadDestination: DownloadDestination?
    
    /**
     * Creates a new BuiltRequest.
     * 
     * - Parameters:
     *   - urlRequest: The configured URLRequest
     *   - downloadDestination: Optional download destination for file downloads
     */
    public init(urlRequest: URLRequest, downloadDestination: DownloadDestination? = nil) {
        self.urlRequest = urlRequest
        self.downloadDestination = downloadDestination
    }
}
