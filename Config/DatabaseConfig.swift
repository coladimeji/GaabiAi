import Foundation
import MongoDBVapor
import Vapor

struct DatabaseConfig {
    static func configure(_ app: Application) throws {
        // Load environment variables
        let mongodbURI = Environment.get("MONGODB_URI") ?? "mongodb://gaabi_admin:gaabi_password@localhost:27017/gaabi_db?authSource=admin"
        
        try app.mongoDB.configure(Environment.get("MONGODB_URI") ?? mongodbURI)
        
        // Set up database event hooks
        app.mongoDB.onConnected { client in
            app.logger.info("✅ MongoDB connected successfully")
        }
        
        app.mongoDB.onDisconnected { client in
            app.logger.warning("⚠️ MongoDB disconnected")
        }
        
        // Configure connection pool settings
        app.mongoDB.pool.maximumConnectionCount = 10
        app.mongoDB.pool.minimumConnectionCount = 2
        app.mongoDB.pool.connectionTimeout = .seconds(30)
        
        // Configure read/write concerns
        app.mongoDB.readConcern = .majority
        app.mongoDB.writeConcern = .majority
    }
    
    // Database repositories
    static func repositories(_ app: Application) throws {
        app.repositories.use(.mongo)
    }
} 