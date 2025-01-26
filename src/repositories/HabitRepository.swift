import Foundation
import MongoDBVapor
import Vapor

final class HabitRepository: BaseMongoRepository<Habit> {
    func findByUser(userId: String) async throws -> [Habit] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        return try await find(where: "userId", equals: .objectID(objectId))
    }
    
    func findByCategory(userId: String, category: String) async throws -> [Habit] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let documents = try await database[collection].find([
            "userId": .objectID(objectId),
            "category": .string(category)
        ]).toArray()
        
        return try documents.map { try BSONDecoder().decode(Habit.self, from: $0) }
    }
    
    func findDueHabits(for userId: String) async throws -> [Habit] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let now = Date()
        let documents = try await database[collection].find([
            "userId": .objectID(objectId),
            "reminder": ["$lte": .datetime(now)]
        ]).toArray()
        
        return try documents.map { try BSONDecoder().decode(Habit.self, from: $0) }
    }
    
    func updateReminder(_ id: String, userId: String, to reminderDate: Date) async throws -> Bool {
        guard let habitId = try? BSONObjectID(id),
              let userObjectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        let result = try await database[collection].updateOne(
            filter: [
                "_id": habitId,
                "userId": userObjectId
            ],
            update: [
                "$set": [
                    "reminder": reminderDate,
                    "updatedAt": Date()
                ]
            ]
        )
        
        return result.modifiedCount > 0
    }
    
    func updateFrequency(_ id: String, userId: String, to frequency: String) async throws -> Bool {
        guard let habitId = try? BSONObjectID(id),
              let userObjectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        let result = try await database[collection].updateOne(
            filter: [
                "_id": habitId,
                "userId": userObjectId
            ],
            update: [
                "$set": [
                    "frequency": frequency,
                    "updatedAt": Date()
                ]
            ]
        )
        
        return result.modifiedCount > 0
    }
    
    func getHabitStats(userId: String) async throws -> [String: Int] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let pipeline: [Document] = [
            ["$match": ["userId": .objectID(objectId)]],
            ["$group": [
                "_id": "$frequency",
                "count": ["$sum": 1]
            ]]
        ]
        
        let results = try await database[collection].aggregate(pipeline).toArray()
        var stats: [String: Int] = [:]
        
        for result in results {
            if let frequency = result["_id"]?.stringValue,
               let count = result["count"]?.intValue {
                stats[frequency] = count
            }
        }
        
        return stats
    }
} 