import Foundation

/**
 * A protocol for handling network response data.
 * 
 * ResponseHandler is responsible for processing raw response data and converting
 * it into the expected type. This allows for custom response processing logic
 * such as custom decoders, error handling, or data transformation.
 * 
 * ## Usage
 * ```swift
 * struct CustomResponseHandler: ResponseHandler {
 *     func handle<T: Decodable>(_ data: Data, response: URLResponse, as type: T.Type) throws -> T {
 *         // Custom response processing logic
 *         let decoder = JSONDecoder()
 *         decoder.keyDecodingStrategy = .convertFromSnakeCase
 *         return try decoder.decode(T.self, from: data)
 *     }
 * }
 * ```
 */
public protocol ResponseHandler {
    /**
     * Handles response data and converts it to the specified type.
     * 
     * - Parameters:
     *   - data: The raw response data
     *   - response: The URLResponse containing response metadata
     *   - type: The type to decode the data into
     * - Returns: The decoded data
     * - Throws: `NetworkError` if processing fails
     */
    func handle<T: Decodable>(_ data: Data, response: URLResponse, as type: T.Type) throws -> T
}

/**
 * A default response handler that uses JSONDecoder for response processing.
 * 
 * This handler validates HTTP status codes and uses a JSONDecoder to convert
 * response data to the expected type. It's suitable for most REST API responses.
 */
public struct DefaultResponseHandler: ResponseHandler {
    /// The JSON decoder used for response processing
    private let decoder: JSONDecoder
    
    /**
     * Creates a new DefaultResponseHandler.
     * 
     * - Parameter decoder: The JSONDecoder to use. Defaults to a new `JSONDecoder()`.
     */
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
