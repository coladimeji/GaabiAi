import Foundation
import MongoDBVapor
import Vapor

struct MongoRepositories {
    let app: Application
    let database: MongoDatabase
    
    init(app: Application) {
        self.app = app
        self.database = app.mongoDB.client.db("gaabi_db")
    }
    
    var userRepository: UserRepository {
        MongoUserRepository(database: database)
    }
    
    var taskRepository: TaskRepository {
        MongoTaskRepository(database: database)
    }
    
    var habitRepository: HabitRepository {
        MongoHabitRepository(database: database)
    }
    
    var voiceNoteRepository: VoiceNoteRepository {
        MongoVoiceNoteRepository(database: database)
    }
}

// MARK: - User Repository
struct MongoUserRepository: UserRepository {
    let database: MongoDatabase
    let collection = "users"
    
    func create(_ user: User) async throws -> User {
        try await database[collection].insertOne(user)
        return user
    }
    
    func find(id: BSONObjectID) async throws -> User? {
        try await database[collection].findOne("_id" == id)
    }
    
    func findByEmail(_ email: String) async throws -> User? {
        try await database[collection].findOne("email" == email)
    }
    
    func findAll() async throws -> [User] {
        try await database[collection].find().toArray()
    }
    
    func update(id: BSONObjectID, with user: User) async throws -> User {
        let result = try await database[collection].updateOne(
            filter: ["_id": .objectID(id)],
            update: ["$set": try BSONEncoder().encode(user)]
        )
        guard result.modifiedCount == 1 else {
            throw Abort(.notFound)
        }
        return user
    }
    
    func delete(id: BSONObjectID) async throws -> Bool {
        let result = try await database[collection].deleteOne("_id" == id)
        return result.deletedCount == 1
    }
}

// MARK: - Task Repository
struct MongoTaskRepository: TaskRepository {
    let database: MongoDatabase
    let collection = "tasks"
    
    func create(_ task: Task) async throws -> Task {
        try await database[collection].insertOne(task)
        return task
    }
    
    func find(id: BSONObjectID) async throws -> Task? {
        try await database[collection].findOne("_id" == id)
    }
    
    func findAll() async throws -> [Task] {
        try await database[collection].find().toArray()
    }
    
    func findByUser(userId: BSONObjectID) async throws -> [Task] {
        try await database[collection].find("userId" == userId).toArray()
    }
    
    func update(id: BSONObjectID, with task: Task) async throws -> Task {
        let result = try await database[collection].updateOne(
            filter: ["_id": .objectID(id)],
            update: ["$set": try BSONEncoder().encode(task)]
        )
        guard result.modifiedCount == 1 else {
            throw Abort(.notFound)
        }
        return task
    }
    
    func delete(id: BSONObjectID) async throws -> Bool {
        let result = try await database[collection].deleteOne("_id" == id)
        return result.deletedCount == 1
    }
}

// MARK: - Habit Repository
struct MongoHabitRepository: HabitRepository {
    let database: MongoDatabase
    let collection = "habits"
    
    func create(_ habit: Habit) async throws -> Habit {
        try await database[collection].insertOne(habit)
        return habit
    }
    
    func find(id: BSONObjectID) async throws -> Habit? {
        try await database[collection].findOne("_id" == id)
    }
    
    func findAll() async throws -> [Habit] {
        try await database[collection].find().toArray()
    }
    
    func findByUser(userId: BSONObjectID) async throws -> [Habit] {
        try await database[collection].find("userId" == userId).toArray()
    }
    
    func update(id: BSONObjectID, with habit: Habit) async throws -> Habit {
        let result = try await database[collection].updateOne(
            filter: ["_id": .objectID(id)],
            update: ["$set": try BSONEncoder().encode(habit)]
        )
        guard result.modifiedCount == 1 else {
            throw Abort(.notFound)
        }
        return habit
    }
    
    func delete(id: BSONObjectID) async throws -> Bool {
        let result = try await database[collection].deleteOne("_id" == id)
        return result.deletedCount == 1
    }
}

// MARK: - VoiceNote Repository
struct MongoVoiceNoteRepository: VoiceNoteRepository {
    let database: MongoDatabase
    let collection = "voice_notes"
    
    func create(_ note: VoiceNote) async throws -> VoiceNote {
        try await database[collection].insertOne(note)
        return note
    }
    
    func find(id: BSONObjectID) async throws -> VoiceNote? {
        try await database[collection].findOne("_id" == id)
    }
    
    func findAll() async throws -> [VoiceNote] {
        try await database[collection].find().toArray()
    }
    
    func findByUser(userId: BSONObjectID) async throws -> [VoiceNote] {
        try await database[collection].find("userId" == userId).toArray()
    }
    
    func update(id: BSONObjectID, with note: VoiceNote) async throws -> VoiceNote {
        let result = try await database[collection].updateOne(
            filter: ["_id": .objectID(id)],
            update: ["$set": try BSONEncoder().encode(note)]
        )
        guard result.modifiedCount == 1 else {
            throw Abort(.notFound)
        }
        return note
    }
    
    func delete(id: BSONObjectID) async throws -> Bool {
        let result = try await database[collection].deleteOne("_id" == id)
        return result.deletedCount == 1
    }
} 