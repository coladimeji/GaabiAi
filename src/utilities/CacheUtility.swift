import Foundation

actor CacheUtility {
    static let shared = CacheUtility()
    
    private var cache: [String: CacheEntry] = [:]
    private let cleanupInterval: TimeInterval = 300 // 5 minutes
    
    private struct CacheEntry {
        let value: Any
        let expirationDate: Date
    }
    
    private init() {
        // Start periodic cleanup
        Task {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(cleanupInterval * 1_000_000_000))
                await cleanup()
            }
        }
    }
    
    func set<T>(_ value: T, forKey key: String, ttl: TimeInterval = 3600) {
        let expirationDate = Date().addingTimeInterval(ttl)
        cache[key] = CacheEntry(value: value, expirationDate: expirationDate)
    }
    
    func get<T>(forKey key: String) -> T? {
        guard let entry = cache[key] else { return nil }
        
        if entry.expirationDate < Date() {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return entry.value as? T
    }
    
    func remove(forKey key: String) {
        cache.removeValue(forKey: key)
    }
    
    func clear() {
        cache.removeAll()
    }
    
    private func cleanup() {
        let now = Date()
        cache = cache.filter { $0.value.expirationDate > now }
    }
} 