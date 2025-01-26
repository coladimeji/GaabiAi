import Foundation
import MongoDBVapor
import Vapor

struct MongoConfig {
    static func configure(_ app: Application) throws {
        // Get MongoDB URI from environment with fallback
        let mongoURI = Environment.get("MONGODB_URI") ?? "mongodb://gaabi_admin:gaabi_password@localhost:27017/gaabi_db?authSource=admin&tls=true&tlsCAFile=/etc/ssl/mongodb-client.pem&tlsAllowInvalidCertificates=true"
        
        // Configure MongoDB client settings
        var clientSettings = try MongoClientSettings(connectionString: mongoURI)
        
        // Configure connection pool
        clientSettings.connectionPoolSettings = ConnectionPoolSettings(
            maxConnections: 10,
            minConnections: 1,
            timeoutMilliseconds: 5000
        )
        
        // Configure read and write concerns
        clientSettings.readConcern = ReadConcern(.majority)
        clientSettings.writeConcern = WriteConcern(w: .majority)
        
        // Add event hooks for monitoring
        clientSettings.addCommandEventHandler { event in
            switch event {
            case .started(let command):
                app.logger.debug("MongoDB command started: \(command.commandName)")
            case .succeeded(let command):
                app.logger.debug("MongoDB command succeeded: \(command.commandName) (\(command.duration)ms)")
            case .failed(let command):
                app.logger.error("MongoDB command failed: \(command.commandName) - \(command.failure)")
            }
        }
        
        // Configure MongoDB for Vapor
        try app.mongoDB.configure(clientSettings)
        
        // Register MongoDB repositories
        try configureRepositories(app)
    }
    
    private static func configureRepositories(_ app: Application) throws {
        // Initialize repositories
        app.repositories.use { _ in
            UserRepository(database: app.mongoDB.db("gaabi_db"))
        }
        
        app.repositories.use { _ in
            TaskRepository(database: app.mongoDB.db("gaabi_db"))
        }
        
        app.repositories.use { _ in
            HabitRepository(database: app.mongoDB.db("gaabi_db"))
        }
        
        app.repositories.use { _ in
            VoiceNoteRepository(database: app.mongoDB.db("gaabi_db"))
        }
    }
}

// Extension to register repositories
extension Application {
    struct RepositoriesKey: StorageKey {
        typealias Value = Repositories
    }
    
    var repositories: Repositories {
        get {
            if let existing = storage[RepositoriesKey.self] {
                return existing
            }
            let new = Repositories()
            storage[RepositoriesKey.self] = new
            return new
        }
        set {
            storage[RepositoriesKey.self] = newValue
        }
    }
}

// Repositories container
final class Repositories {
    private var storage: [ObjectIdentifier: Any] = [:]
    
    func use<R>(_ make: @escaping (Application) -> R) where R: Repository {
        storage[ObjectIdentifier(R.self)] = make
    }
    
    func get<R>(_ type: R.Type = R.self) -> R? where R: Repository {
        storage[ObjectIdentifier(type)] as? R
    }
} 