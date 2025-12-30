import Foundation

/**
 * A protocol for creating plugins that can intercept and modify network requests and responses.
 * 
 * Plugins allow you to add cross-cutting concerns to your network requests without modifying
 * the core networking code. They can be used for logging, authentication, caching, metrics,
 * and other functionality that needs to be applied to multiple requests.
 * 
 * ## Usage
 * ```swift
 * struct LoggingPlugin: NetworkPlugin {
 *     func willSend(_ request: URLRequest, target: Endpoint) {
 *         print("Sending request to: \(request.url?.absoluteString ?? "")")
 *     }
 *     
 *     func didReceive(_ result: Result<(Data, URLResponse), Error>, target: Endpoint) {
 *         switch result {
 *         case .success(let (data, response)):
 *             print("Received response: \(response)")
 *         case .failure(let error):
 *             print("Request failed: \(error)")
 *         }
 *     }
 * }
 * ```
 */
public protocol NetworkPlugin {
    /**
     * Called before a request is sent.
     * 
     * Use this method to log requests, add headers, or perform other pre-request operations.
     * 
     * - Parameters:
     *   - request: The URLRequest that will be sent
     *   - target: The endpoint that generated this request
     */
    func willSend(_ request: URLRequest, target: any Endpoint)
    
    /**
     * Called after a response is received.
     * 
     * Use this method to log responses, process response data, or perform other post-response operations.
     * 
     * - Parameters:
     *   - result: The result containing either the response data and URLResponse, or an error
     *   - target: The endpoint that generated the original request
     */
    func didReceive(_ result: Result<(Data, URLResponse), Error>, target: any Endpoint)
}

/**
 * Default implementations that make all plugin methods optional.
 * 
 * This allows you to implement only the plugin methods you need.
 */
public extension NetworkPlugin {
    /// Default empty implementation for willSend
    func willSend(_ request: URLRequest, target: any Endpoint) {}
    
    /// Default empty implementation for didReceive
    func didReceive(_ result: Result<(Data, URLResponse), Error>, target: any Endpoint) {}
}
