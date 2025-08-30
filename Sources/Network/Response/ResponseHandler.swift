import Foundation

public protocol ResponseHandler {
    func handle<T: Decodable>(_ data: Data, response: URLResponse, as type: T.Type) throws -> T
}

public struct DefaultResponseHandler: ResponseHandler {
    private let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }
    
    public func handle<T: Decodable>(_ data: Data, response: URLResponse, as type: T.Type) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return try decoder.decode(T.self, from: data)
    }
}
