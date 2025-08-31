import Foundation

/**
 * Defines how request parameters should be encoded.
 * 
 * ParameterEncoding specifies the format in which request parameters
 * should be encoded, supporting URL query parameters, JSON body, and
 * form URL encoding.
 * 
 * ## Usage
 * ```swift
 * // URL encoding for query parameters
 * let urlEncoding = ParameterEncoding.url
 * 
 * // JSON encoding for request body
 * let jsonEncoding = ParameterEncoding.json
 * 
 * // Form URL encoding for request body
 * let formEncoding = ParameterEncoding.formURLEncoded
 * ```
 */
public enum ParameterEncoding: Sendable {
    /// Encode parameters as URL query parameters
    case url
    
    /// Encode parameters as JSON in request body
    case json
    
    /// Encode parameters as form URL encoded in request body
    case formURLEncoded

    /**
     * Encodes parameters into the request using the specified encoding method.
     * 
     * - Parameters:
     *   - request: The request to encode parameters into
     *   - parameters: The parameters to encode
     * - Returns: The request with encoded parameters
     * - Throws: `NetworkError` if encoding fails
     */
    func encode(request: URLRequest, parameters: [String: Any]) throws -> URLRequest {
        var request = request
        switch self {
        case .url:
            guard let url = request.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw NetworkError.invalidRequest
            }
            let existing = components.queryItems ?? []
            let items = parameters.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
            components.queryItems = existing + items
            guard let url = components.url else {
                throw NetworkError.invalidRequest
            }
            request.url = url
            return request
        case .json:
            let data = try JSONSerialization.data(withJSONObject: parameters)
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return request
        case .formURLEncoded:
            let pairs = parameters.map { key, value in
                "\(percentEncode(key))=\(percentEncode(String(describing: value)))"
            }.joined(separator: "&")
            request.httpBody = pairs.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            return request
        }
    }

    private func percentEncode(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}
