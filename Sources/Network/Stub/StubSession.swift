import Foundation

public struct StubSession: Session {
    let data: Data
    let statusCode: Int
    let url: URL

    public init(_ data: Data, statusCode: Int = 200, url: URL) {
        self.data = data
        self.statusCode = statusCode
        self.url = url
    }

    public func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let res = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, res)
    }
}
