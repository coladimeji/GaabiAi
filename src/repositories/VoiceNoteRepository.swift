import Foundation
import MongoDBVapor
import Vapor

final class VoiceNoteRepository: BaseMongoRepository<VoiceNote> {
    func findByUser(userId: String) async throws -> [VoiceNote] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        return try await find(where: "userId", equals: .objectID(objectId))
    }
    
    func findByCategory(userId: String, category: String) async throws -> [VoiceNote] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let documents = try await database[collection].find([
            "userId": .objectID(objectId),
            "category": .string(category)
        ]).toArray()
        
        return try documents.map { try BSONDecoder().decode(VoiceNote.self, from: $0) }
    }
    
    func searchTranscriptions(userId: String, query: String) async throws -> [VoiceNote] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let documents = try await database[collection].find([
            "userId": .objectID(objectId),
            "transcription": [
                "$regex": query,
                "$options": "i"
            ]
        ]).toArray()
        
        return try documents.map { try BSONDecoder().decode(VoiceNote.self, from: $0) }
    }
    
    func updateTranscription(_ id: String, userId: String, transcription: String) async throws -> Bool {
        guard let noteId = try? BSONObjectID(id),
              let userObjectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        let result = try await database[collection].updateOne(
            filter: [
                "_id": noteId,
                "userId": userObjectId
            ],
            update: [
                "$set": [
                    "transcription": transcription,
                    "updatedAt": Date()
                ]
            ]
        )
        
        return result.modifiedCount > 0
    }
    
    func getVoiceNoteStats(userId: String) async throws -> [String: Any] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let pipeline: [Document] = [
            ["$match": ["userId": .objectID(objectId)]],
            ["$group": [
                "_id": nil,
                "totalCount": ["$sum": 1],
                "totalDuration": ["$sum": "$duration"],
                "averageDuration": ["$avg": "$duration"],
                "categories": ["$addToSet": "$category"]
            ]]
        ]
        
        let results = try await database[collection].aggregate(pipeline).toArray()
        guard let result = results.first else {
            return ["totalCount": 0, "totalDuration": 0, "averageDuration": 0, "categories": []]
        }
        
        return [
            "totalCount": result["totalCount"]?.intValue ?? 0,
            "totalDuration": result["totalDuration"]?.intValue ?? 0,
            "averageDuration": Int(result["averageDuration"]?.doubleValue ?? 0),
            "categories": result["categories"]?.arrayValue?.compactMap { $0.stringValue } ?? []
        ]
    }
    
    func findRecentNotes(userId: String, limit: Int = 10) async throws -> [VoiceNote] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let documents = try await database[collection].find(
            ["userId": .objectID(objectId)],
            options: FindOptions(
                sort: ["createdAt": -1],
                limit: limit
            )
        ).toArray()
        
        return try documents.map { try BSONDecoder().decode(VoiceNote.self, from: $0) }
    }
} 