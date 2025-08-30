import Foundation

public enum ParameterEncoding: Sendable {
    case url
    case json
    case formURLEncoded

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
