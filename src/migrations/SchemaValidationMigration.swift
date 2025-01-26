import Foundation
import MongoDBVapor
import Vapor

struct SchemaValidationMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let db = database as? MongoDatabase else {
            throw Abort(.internalServerError, reason: "Database must be MongoDB")
        }
        
        // User Schema Validation
        try await db.runCommand([
            "collMod": "users",
            "validator": [
                "$jsonSchema": [
                    "bsonType": "object",
                    "required": ["email", "password", "role", "createdAt", "updatedAt"],
                    "properties": [
                        "email": ["bsonType": "string", "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"],
                        "password": ["bsonType": "string", "minLength": 6],
                        "role": ["enum": ["user", "admin"]],
                        "createdAt": ["bsonType": "date"],
                        "updatedAt": ["bsonType": "date"]
                    ]
                ]
            ],
            "validationLevel": "strict"
        ])
        
        // Task Schema Validation
        try await db.runCommand([
            "collMod": "tasks",
            "validator": [
                "$jsonSchema": [
                    "bsonType": "object",
                    "required": ["userId", "title", "completed", "createdAt", "updatedAt"],
                    "properties": [
                        "userId": ["bsonType": "objectId"],
                        "title": ["bsonType": "string", "minLength": 1],
                        "description": ["bsonType": "string"],
                        "completed": ["bsonType": "bool"],
                        "dueDate": ["bsonType": "date"],
                        "createdAt": ["bsonType": "date"],
                        "updatedAt": ["bsonType": "date"]
                    ]
                ]
            ],
            "validationLevel": "strict"
        ])
        
        // Habit Schema Validation
        try await db.runCommand([
            "collMod": "habits",
            "validator": [
                "$jsonSchema": [
                    "bsonType": "object",
                    "required": ["userId", "name", "category", "frequency", "createdAt", "updatedAt"],
                    "properties": [
                        "userId": ["bsonType": "objectId"],
                        "name": ["bsonType": "string", "minLength": 1],
                        "category": ["bsonType": "string"],
                        "frequency": ["bsonType": "string", "enum": ["daily", "weekly", "monthly"]],
                        "reminder": ["bsonType": "date"],
                        "createdAt": ["bsonType": "date"],
                        "updatedAt": ["bsonType": "date"]
                    ]
                ]
            ],
            "validationLevel": "strict"
        ])
        
        // Voice Note Schema Validation
        try await db.runCommand([
            "collMod": "voice_notes",
            "validator": [
                "$jsonSchema": [
                    "bsonType": "object",
                    "required": ["userId", "title", "audioUrl", "duration", "createdAt", "updatedAt"],
                    "properties": [
                        "userId": ["bsonType": "objectId"],
                        "title": ["bsonType": "string", "minLength": 1],
                        "audioUrl": ["bsonType": "string"],
                        "duration": ["bsonType": "int"],
                        "category": ["bsonType": "string"],
                        "transcription": ["bsonType": "string"],
                        "createdAt": ["bsonType": "date"],
                        "updatedAt": ["bsonType": "date"]
                    ]
                ]
            ],
            "validationLevel": "strict"
        ])
    }
    
    func revert(on database: Database) async throws {
        guard let db = database as? MongoDatabase else {
            throw Abort(.internalServerError, reason: "Database must be MongoDB")
        }
        
        // Remove schema validation for all collections
        for collection in ["users", "tasks", "habits", "voice_notes"] {
            try await db.runCommand([
                "collMod": collection,
                "validator": [:],
                "validationLevel": "off"
            ])
        }
    }
} 