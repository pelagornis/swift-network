import Foundation

public protocol NetworkPlugin {
    func willSend(_ request: URLRequest, target: Endpoint)
    func didReceive(_ result: Result<(Data, URLResponse), Error>, target: Endpoint)
}

public extension NetworkPlugin {
    func willSend(_ request: URLRequest, target: Endpoint) {}
    func didReceive(_ result: Result<(Data, URLResponse), Error>, target: Endpoint) {}
}
