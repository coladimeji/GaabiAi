import Foundation
import Vapor

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case rateLimitExceeded
    case unauthorized
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    case retryExhausted
    
    var description: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .rateLimitExceeded: return "Rate limit exceeded"
        case .unauthorized: return "Unauthorized access"
        case .serverError(let code): return "Server error with code: \(code)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .retryExhausted: return "Retry attempts exhausted"
        }
    }
}

final class NetworkUtility {
    static let shared = NetworkUtility()
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    func performRequest<T: Decodable>(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> T {
        var retryCount = 0
        var lastError: Error?
        
        while retryCount <= maxRetries {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = method
                request.httpBody = body
                
                headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    do {
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        throw NetworkError.decodingError(error)
                    }
                case 401:
                    throw NetworkError.unauthorized
                case 429:
                    if retryCount < maxRetries {
                        let delay = calculateRetryDelay(retryCount: retryCount, baseDelay: retryDelay)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        retryCount += 1
                        continue
                    }
                    throw NetworkError.rateLimitExceeded
                case 500...599:
                    if retryCount < maxRetries {
                        let delay = calculateRetryDelay(retryCount: retryCount, baseDelay: retryDelay)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        retryCount += 1
                        continue
                    }
                    throw NetworkError.serverError(httpResponse.statusCode)
                default:
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
            } catch {
                lastError = error
                if retryCount < maxRetries {
                    let delay = calculateRetryDelay(retryCount: retryCount, baseDelay: retryDelay)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    retryCount += 1
                    continue
                }
                throw NetworkError.networkError(error)
            }
        }
        
        throw NetworkError.retryExhausted
    }
    
    private func calculateRetryDelay(retryCount: Int, baseDelay: TimeInterval) -> TimeInterval {
        // Exponential backoff with jitter
        let exponentialDelay = baseDelay * pow(2.0, Double(retryCount))
        let jitter = Double.random(in: 0...0.3)
        return exponentialDelay + jitter
    }
} 