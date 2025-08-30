import Foundation

public struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    public init(_ encodable: Encodable) { self._encode = encodable.encode }
    public func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
