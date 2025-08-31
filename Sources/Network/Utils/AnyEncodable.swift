import Foundation

/**
 * A type-erased wrapper for Encodable types.
 * 
 * AnyEncodable allows you to store and encode any Encodable value without
 * knowing its specific type at compile time. This is useful when you need
 * to work with heterogeneous collections of encodable objects.
 * 
 * ## Usage
 * ```swift
 * let encodables: [AnyEncodable] = [
 *     AnyEncodable("string"),
 *     AnyEncodable(42),
 *     AnyEncodable(User(name: "John"))
 * ]
 * 
 * let data = try JSONEncoder().encode(encodables)
 * ```
 */
public struct AnyEncodable: Encodable {
    /// The underlying encoding function
    private let _encode: (Encoder) throws -> Void
    
    /**
     * Creates a new AnyEncodable wrapper.
     * 
     * - Parameter encodable: The encodable value to wrap
     */
    public init(_ encodable: Encodable) { 
        self._encode = encodable.encode 
    }
    
    /**
     * Encodes the wrapped value using the provided encoder.
     * 
     * - Parameter encoder: The encoder to use
     * - Throws: Any error thrown by the underlying encodable
     */
    public func encode(to encoder: Encoder) throws { 
        try _encode(encoder) 
    }
}
