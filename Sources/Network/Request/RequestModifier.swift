import Foundation

public protocol RequestModifier {
    func modify(_ request: BuiltRequest) throws -> BuiltRequest
}

public class HeaderModifier: RequestModifier {
    private let headers: [String: String]
    
    public init(headers: [String: String]) {
        self.headers = headers
    }
    
    public func modify(_ request: BuiltRequest) throws -> BuiltRequest {
        var urlRequest = request.urlRequest
        var currentHeaders = urlRequest.allHTTPHeaderFields ?? [:]
        currentHeaders.merge(headers) { _, new in new }
        urlRequest.allHTTPHeaderFields = currentHeaders
        return BuiltRequest(urlRequest: urlRequest, downloadDestination: request.downloadDestination)
    }
}

public class TimeoutModifier: RequestModifier {
    private let timeout: TimeInterval
    
    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }
    
    public func modify(_ request: BuiltRequest) throws -> BuiltRequest {
        var urlRequest = request.urlRequest
        urlRequest.timeoutInterval = timeout
        return BuiltRequest(urlRequest: urlRequest, downloadDestination: request.downloadDestination)
    }
}

public class CachePolicyModifier: RequestModifier {
    private let cachePolicy: URLRequest.CachePolicy
    
    public init(cachePolicy: URLRequest.CachePolicy) {
        self.cachePolicy = cachePolicy
    }
    
    public func modify(_ request: BuiltRequest) throws -> BuiltRequest {
        var urlRequest = request.urlRequest
        urlRequest.cachePolicy = cachePolicy
        return BuiltRequest(urlRequest: urlRequest, downloadDestination: request.downloadDestination)
    }
}
