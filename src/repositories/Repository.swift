import Foundation
import MongoDBVapor
import Vapor

protocol Repository {
    associatedtype Model
    associatedtype ID
    
    var database: MongoDatabase { get }
    var collection: String { get }
    
    func create(_ item: Model) async throws -> Model
    func find(by id: ID) async throws -> Model?
    func findAll() async throws -> [Model]
    func update(_ id: ID, with item: Model) async throws -> Model
    func delete(_ id: ID) async throws -> Bool
}

extension Repository {
    var collection: String {
        String(describing: Model.self).lowercased() + "s"
    }
}

// Base MongoDB Repository implementation
class BaseMongoRepository<T: Codable>: Repository {
    typealias Model = T
    typealias ID = String
    
    let database: MongoDatabase
    
    init(database: MongoDatabase) {
        self.database = database
    }
    
    func create(_ item: T) async throws -> T {
        let document = try BSONEncoder().encode(item)
        let result = try await database[collection].insertOne(document)
        guard let id = result.insertedID else {
            throw Abort(.internalServerError, reason: "Failed to get inserted ID")
        }
        return try await find(by: id.stringValue) ?? item
    }
    
    func find(by id: String) async throws -> T? {
        guard let objectId = try? BSONObjectID(id) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        let document = try await database[collection].findOne(["_id": objectId])
        return try document.map { try BSONDecoder().decode(T.self, from: $0) }
    }
    
    func findAll() async throws -> [T] {
        let documents = try await database[collection].find().toArray()
        return try documents.map { try BSONDecoder().decode(T.self, from: $0) }
    }
    
    func update(_ id: String, with item: T) async throws -> T {
        guard let objectId = try? BSONObjectID(id) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        var document = try BSONEncoder().encode(item)
        document["_id"] = .objectID(objectId)
        
        let result = try await database[collection].replaceOne(
            filter: ["_id": objectId],
            replacement: document,
            options: .init(upsert: true)
        )
        
        guard result.matchedCount > 0 || result.upsertedID != nil else {
            throw Abort(.notFound, reason: "Document not found")
        }
        
        return try await find(by: id) ?? item
    }
    
    func delete(_ id: String) async throws -> Bool {
        guard let objectId = try? BSONObjectID(id) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        let result = try await database[collection].deleteOne(["_id": objectId])
        return result.deletedCount > 0
    }
    
    // Helper methods for common queries
    func find(where field: String, equals value: BSON) async throws -> [T] {
        let documents = try await database[collection].find([field: value]).toArray()
        return try documents.map { try BSONDecoder().decode(T.self, from: $0) }
    }
    
    func findOne(where field: String, equals value: BSON) async throws -> T? {
        guard let document = try await database[collection].findOne([field: value]) else {
            return nil
        }
        return try BSONDecoder().decode(T.self, from: document)
    }
    
    func count(where field: String, equals value: BSON) async throws -> Int {
        return try await database[collection].countDocuments([field: value])
    }
} 