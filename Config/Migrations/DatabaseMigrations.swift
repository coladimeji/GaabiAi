import Foundation
import MongoDBVapor
import Vapor

struct DatabaseMigrations {
    static func configure(_ app: Application) throws {
        // Register migrations
        app.migrations.add(CreateIndexesMigration())
        app.migrations.add(CreateAdminUserMigration())
        
        // Run migrations
        try app.autoMigrate().wait()
    }
}

// MARK: - Migrations
struct CreateIndexesMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        let db = database as! MongoDatabase
        
        // Users collection indexes
        try await db["users"].createIndex(["email": 1], indexOptions: .init(unique: true))
        try await db["users"].createIndex(["createdAt": 1])
        
        // Tasks collection indexes
        try await db["tasks"].createIndex(["userId": 1])
        try await db["tasks"].createIndex(["userId": 1, "dueDate": 1])
        try await db["tasks"].createIndex(["userId": 1, "status": 1])
        
        // Habits collection indexes
        try await db["habits"].createIndex(["userId": 1])
        try await db["habits"].createIndex(["userId": 1, "frequency": 1])
        try await db["habits"].createIndex(["userId": 1, "lastCompletedDate": 1])
        
        // Voice notes collection indexes
        try await db["voice_notes"].createIndex(["userId": 1])
        try await db["voice_notes"].createIndex(["userId": 1, "category": 1])
        try await db["voice_notes"].createIndex(["userId": 1, "createdAt": 1])
    }
    
    func revert(on database: Database) async throws {
        let db = database as! MongoDatabase
        
        try await db["users"].dropIndexes()
        try await db["tasks"].dropIndexes()
        try await db["habits"].dropIndexes()
        try await db["voice_notes"].dropIndexes()
    }
}

struct CreateAdminUserMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        let db = database as! MongoDatabase
        
        // Check if admin user exists
        guard try await db["users"].find("email" == "admin@gaabi.app").toArray().isEmpty else {
            return
        }
        
        // Create admin user
        let adminUser = User(
            email: "admin@gaabi.app",
            passwordHash: try await BCryptDigest().hash("admin"),
            firstName: "Admin",
            lastName: "User",
            settings: UserSettings()
        )
        
        try await db["users"].insertOne(adminUser)
    }
    
    func revert(on database: Database) async throws {
        let db = database as! MongoDatabase
        try await db["users"].deleteOne("email" == "admin@gaabi.app")
    }
} 