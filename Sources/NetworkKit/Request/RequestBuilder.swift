import Foundation

/**
 * A protocol for building network requests from endpoints.
 * 
 * RequestBuilder is responsible for converting Endpoint instances into
 * URLRequest objects that can be executed by the networking system.
 */
public protocol RequestBuilder {
    /**
     * Builds a request from the configured endpoint and modifiers.
     * 
     * - Returns: A BuiltRequest containing the URLRequest and any additional metadata
     * - Throws: `NetworkError` if the request cannot be built
     */
    func build() throws -> BuiltRequest
}

/**
 * A concrete implementation of RequestBuilder that creates URLRequests from Endpoints.
 * 
 * NetworkRequestBuilder handles all aspects of request construction including:
 * - URL composition and validation
 * - Header management and merging
 * - Request body encoding
 * - Timeout and cache policy configuration
 * - Request modifier application
 * 
 * ## Usage
 * ```swift
 * let builder = NetworkRequestBuilder(endpoint: UserEndpoint())
 * builder.addModifier(TimeoutModifier(30))
 * let request = try builder.build()
 * ```
 */
public class NetworkRequestBuilder: RequestBuilder {
    /// The endpoint that defines the request structure
    private let endpoint: any Endpoint
    
    /// Additional headers to be merged with endpoint headers
    private var extraHeaders: [String: String] = [:]
    
    /// Custom timeout override for this request
    private var timeout: TimeInterval?
    
    /// Custom cache policy override for this request
    private var cachePolicy: URLRequest.CachePolicy?
    
    /// Request modifiers to apply during building
    private var requestModifiers: [RequestModifier] = []
    
    public init(endpoint: any Endpoint) {
        self.endpoint = endpoint
    }
    
    public func build() throws -> BuiltRequest {
        let baseRequest = try buildBaseRequest()
        let modifiedRequest = try applyModifiers(to: baseRequest)
        return modifiedRequest
    }
    
    private func buildBaseRequest() throws -> BuiltRequest {
        guard let components = URLComponents(url: endpoint.baseURL.appendingPathComponent(endpoint.path),
                                             resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidRequest
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = endpoint.method.rawValue

        // Apply headers
        let mergedHeaders = mergeHeaders()
        if !mergedHeaders.isEmpty {
            request.allHTTPHeaderFields = mergedHeaders
        }

        // Apply timeout / cache policy
        if let t = timeout ?? endpoint.timeout { request.timeoutInterval = t }
        if let cp = cachePolicy { request.cachePolicy = cp }

        // Handle Task specifics
        let downloadDestination = try handleTask(for: &request)

        return BuiltRequest(urlRequest: request, downloadDestination: downloadDestination)
    }
    
    private func mergeHeaders() -> [String: String] {
        var headerDict: [String: String] = [:]
        
        // Add endpoint headers
        endpoint.headers.forEach { headerDict[$0.field] = $0.value }
        
        // Add extra headers
        extraHeaders.forEach { headerDict[$0.key] = $0.value }
        
        return headerDict
    }
    
    private func handleTask(for request: inout URLRequest) throws -> DownloadDestination? {
        switch endpoint.task {
        case .requestPlain:
            return nil

        case .requestJSON(let encodable):
            do {
                let data = try JSONEncoder().encode(encodable)
                request.httpBody = data
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw NetworkError.encodingError(error)
            }
            return nil

        case .requestParameters(let params, let encoding):
            request = try encoding.encode(request: request, parameters: params)
            return nil

        case .uploadMultipart(let parts):
            let boundary = "Boundary-\(UUID().uuidString)"
            let body = MultipartEncoder.encode(parts: parts, boundary: boundary)
            request.httpBody = body
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
            return nil

        case .download(let destination):
            return destination
    
        case .requestCustom(let body, let contentType):
            request.httpBody = body
            if let ct = contentType { request.setValue(ct, forHTTPHeaderField: "Content-Type") }
            return nil

        case .requestStream(let inputStream, let length, let contentType):
            request.httpBodyStream = inputStream
            request.setValue("\(length)", forHTTPHeaderField: "Content-Length")
            if let ct = contentType { request.setValue(ct, forHTTPHeaderField: "Content-Type") }
            return nil
        }
    }
    
    private func applyModifiers(to request: BuiltRequest) throws -> BuiltRequest {
        var modifiedRequest = request
        
        for modifier in requestModifiers {
            modifiedRequest = try modifier.modify(modifiedRequest)
        }
        
        return modifiedRequest
    }
}

// MARK: - Builder Methods
extension NetworkRequestBuilder {
    @discardableResult
    public func addHeader(field: String, value: String) -> Self {
        extraHeaders[field] = value
        return self
    }
    
    @discardableResult
    public func addHeaders(_ headers: [String: String]) -> Self {
        headers.forEach { extraHeaders[$0.key] = $0.value }
        return self
    }
    
    @discardableResult
    public func setTimeout(_ seconds: TimeInterval) -> Self {
        timeout = seconds
        return self
    }
    
    @discardableResult
    public func setCachePolicy(_ policy: URLRequest.CachePolicy) -> Self {
        cachePolicy = policy
        return self
    }
    
    @discardableResult
    public func addModifier(_ modifier: RequestModifier) -> Self {
        requestModifiers.append(modifier)
        return self
    }
}
