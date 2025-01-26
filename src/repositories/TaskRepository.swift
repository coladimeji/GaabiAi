import Foundation
import MongoDBVapor
import Vapor

final class TaskRepository: BaseMongoRepository<Task> {
    func findByUser(userId: String) async throws -> [Task] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        return try await find(where: "userId", equals: .objectID(objectId))
    }
    
    func findIncomplete(for userId: String) async throws -> [Task] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let documents = try await database[collection].find([
            "userId": .objectID(objectId),
            "completed": false
        ]).toArray()
        
        return try documents.map { try BSONDecoder().decode(Task.self, from: $0) }
    }
    
    func findDueToday(for userId: String) async throws -> [Task] {
        guard let objectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID format")
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let documents = try await database[collection].find([
            "userId": .objectID(objectId),
            "dueDate": [
                "$gte": .datetime(today),
                "$lt": .datetime(tomorrow)
            ],
            "completed": false
        ]).toArray()
        
        return try documents.map { try BSONDecoder().decode(Task.self, from: $0) }
    }
    
    func markAsComplete(_ id: String, userId: String) async throws -> Bool {
        guard let taskId = try? BSONObjectID(id),
              let userObjectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        let result = try await database[collection].updateOne(
            filter: [
                "_id": taskId,
                "userId": userObjectId
            ],
            update: [
                "$set": [
                    "completed": true,
                    "updatedAt": Date()
                ]
            ]
        )
        
        return result.modifiedCount > 0
    }
    
    func updateDueDate(_ id: String, userId: String, to dueDate: Date) async throws -> Bool {
        guard let taskId = try? BSONObjectID(id),
              let userObjectId = try? BSONObjectID(userId) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        let result = try await database[collection].updateOne(
            filter: [
                "_id": taskId,
                "userId": userObjectId
            ],
            update: [
                "$set": [
                    "dueDate": dueDate,
                    "updatedAt": Date()
                ]
            ]
        )
        
        return result.modifiedCount > 0
    }
} 