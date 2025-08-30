import Foundation

public protocol Session {
    func perform(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: Session {
    public func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await self.data(for: request)
    }
}
