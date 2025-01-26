import Foundation
import MongoDBVapor
import Vapor

struct DatabaseMigrations {
    static func configure(_ app: Application) throws {
        // Register migrations in order
        app.migrations.add(CreateIndexesMigration())
        app.migrations.add(SchemaValidationMigration())
        app.migrations.add(CreateAdminUserMigration())
        
        // Auto-migrate on app start if in development
        if app.environment == .development {
            try app.autoMigrate().wait()
        }
    }
}

// Migration to create indexes for collections
struct CreateIndexesMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let db = database as? MongoDatabase else {
            throw Abort(.internalServerError, reason: "Database must be MongoDB")
        }
        
        // Users collection indexes
        try await db.createIndex("users", keys: ["email": 1], options: .init(unique: true))
        try await db.createIndex("users", keys: ["createdAt": -1])
        
        // Tasks collection indexes
        try await db.createIndex("tasks", keys: ["userId": 1])
        try await db.createIndex("tasks", keys: ["userId": 1, "completed": 1])
        try await db.createIndex("tasks", keys: ["userId": 1, "dueDate": 1])
        
        // Habits collection indexes
        try await db.createIndex("habits", keys: ["userId": 1])
        try await db.createIndex("habits", keys: ["userId": 1, "category": 1])
        try await db.createIndex("habits", keys: ["userId": 1, "createdAt": -1])
        
        // Voice notes collection indexes
        try await db.createIndex("voice_notes", keys: ["userId": 1])
        try await db.createIndex("voice_notes", keys: ["userId": 1, "category": 1])
        try await db.createIndex("voice_notes", keys: ["userId": 1, "createdAt": -1])
    }
    
    func revert(on database: Database) async throws {
        guard let db = database as? MongoDatabase else {
            throw Abort(.internalServerError, reason: "Database must be MongoDB")
        }
        
        // Drop all indexes except _id
        try await db.drop("users")
        try await db.drop("tasks")
        try await db.drop("habits")
        try await db.drop("voice_notes")
    }
}

// Migration to create admin user if it doesn't exist
struct CreateAdminUserMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let db = database as? MongoDatabase else {
            throw Abort(.internalServerError, reason: "Database must be MongoDB")
        }
        
        // Check if admin user exists
        let adminExists = try await db["users"].find(["role": "admin"]).firstResult != nil
        
        if !adminExists {
            // Create admin user
            let adminUser: Document = [
                "email": "admin@gaabi.app",
                "password": try Bcrypt.hash("admin"), // Remember to change this in production
                "role": "admin",
                "createdAt": Date(),
                "updatedAt": Date()
            ]
            
            try await db["users"].insertOne(adminUser)
        }
    }
    
    func revert(on database: Database) async throws {
        guard let db = database as? MongoDatabase else {
            throw Abort(.internalServerError, reason: "Database must be MongoDB")
        }
        
        // Remove admin user
        try await db["users"].deleteOne(["role": "admin"])
    }
} 