import Foundation

public protocol Endpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: Http.Method { get }
    var task: Http.Task { get }
    var headers: [Http.Header] { get }
    var sampleData: Data? { get }
    var timeout: TimeInterval? { get }
}

public extension Endpoint {
    var headers: [Http.Header] {
        []
    }
    var sampleData: Data? {
        nil
    }
    var timeout: TimeInterval? {
        nil
    }
}
