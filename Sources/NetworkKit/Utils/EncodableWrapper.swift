import Foundation

/**
 * An internal wrapper for Encodable types used within the networking library.
 * 
 * EncodableWrapper provides type erasure for Encodable values in internal
 * contexts where AnyEncodable is not needed. This is used for internal
 * request building and encoding operations.
 */
struct EncodableWrapper: Encodable {
    /// The underlying encoding function
    private let _encode: (Encoder) throws -> Void
    
    /**
     * Creates a new EncodableWrapper.
     * 
     * - Parameter wrapped: The encodable value to wrap
     */
    init<T: Encodable>(_ wrapped: T) {
        self._encode = wrapped.encode
    }
    
    /**
     * Encodes the wrapped value using the provided encoder.
     * 
     * - Parameter encoder: The encoder to use
     * - Throws: Any error thrown by the underlying encodable
     */
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
