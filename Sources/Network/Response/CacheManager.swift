import Foundation

public protocol CacheManager {
    func get<T: Decodable>(for key: String, as type: T.Type) -> T?
    func set<T: Encodable>(_ value: T, for key: String, expiration: TimeInterval?)
    func remove(for key: String)
    func clear()
}

public final class MemoryCacheManager: CacheManager, @unchecked Sendable {
    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "com.network.cache", attributes: .concurrent)
    
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
