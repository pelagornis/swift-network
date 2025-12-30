import Foundation

/**
 * A protocol for managing response caching in the networking library.
 * 
 * CacheManager provides a way to store and retrieve network responses to improve
 * performance and reduce network requests. It supports automatic expiration
 * and thread-safe operations.
 * 
 * ## Usage
 * ```swift
 * let cacheManager = MemoryCacheManager()
 * 
 * // Store a response
 * cacheManager.set(user, for: "user-123", expiration: 300) // 5 minutes
 * 
 * // Retrieve a response
 * if let cachedUser: User = cacheManager.get(for: "user-123", as: User.self) {
 *     // Use cached data
 * }
 * ```
 */
public protocol CacheManager {
    /**
     * Retrieves a cached value for the given key.
     * 
     * - Parameters:
     *   - key: The cache key
     *   - type: The type to decode the cached data into
     * - Returns: The cached value, or `nil` if not found or expired
     */
    func get<T: Decodable>(for key: String, as type: T.Type) -> T?
    
    /**
     * Stores a value in the cache.
     * 
     * - Parameters:
     *   - value: The value to cache (must be Encodable)
     *   - key: The cache key
     *   - expiration: Optional expiration time in seconds
     */
    func set<T: Encodable>(_ value: T, for key: String, expiration: TimeInterval?)
    
    /**
     * Removes a specific item from the cache.
     * 
     * - Parameter key: The cache key to remove
     */
    func remove(for key: String)
    
    /**
     * Clears all cached data.
     */
    func clear()
}
/**
 * A memory-based implementation of CacheManager.
 * 
 * MemoryCacheManager stores cached data in memory using a thread-safe dictionary.
 * It automatically handles expiration and provides concurrent access for better performance.
 * 
 * ## Thread Safety
 * This implementation is thread-safe and can be used from multiple threads concurrently.
 * It uses a concurrent dispatch queue to ensure safe access to the cache.
 */
public final class MemoryCacheManager: CacheManager, @unchecked Sendable {
    /// The underlying cache storage
    private var cache: [String: CacheEntry] = [:]
    
    /// Concurrent queue for thread-safe cache operations
    private let queue = DispatchQueue(label: "com.network.cache", attributes: .concurrent)
    
    /**
     * Creates a new MemoryCacheManager.
     */
    public init() {}
    
    public func get<T: Decodable>(for key: String, as type: T.Type) -> T? {
        return queue.sync {
            guard let entry = cache[key], !entry.isExpired else {
                cache.removeValue(forKey: key)
                return nil
            }
            
            do {
                return try JSONDecoder().decode(type, from: entry.data)
            } catch {
                cache.removeValue(forKey: key)
                return nil
            }
        }
    }
    
    public func set<T: Encodable>(_ value: T, for key: String, expiration: TimeInterval? = nil) {
        do {
            let data = try JSONEncoder().encode(value)
            let entry = CacheEntry(data: data, expirationDate: expiration.map { Date().addingTimeInterval($0) })
            
            queue.sync(flags: .barrier) {
                self.cache[key] = entry
            }
        } catch {
            // Encoding failed, don't cache
        }
    }
    
    public func remove(for key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

private struct CacheEntry {
    let data: Data
    let expirationDate: Date?
    
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate
    }
}

