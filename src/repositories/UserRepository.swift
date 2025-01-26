import Foundation
import MongoDBVapor
import Vapor

final class UserRepository: BaseMongoRepository<User> {
    func findByEmail(_ email: String) async throws -> User? {
        return try await findOne(where: "email", equals: .string(email))
    }
    
    func findByRole(_ role: String) async throws -> [User] {
        return try await find(where: "role", equals: .string(role))
    }
    
    func updatePassword(for id: String, newPassword: String) async throws -> Bool {
        guard let objectId = try? BSONObjectID(id) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }
        
        let hashedPassword = try Bcrypt.hash(newPassword)
        let result = try await database[collection].updateOne(
            filter: ["_id": objectId],
            update: ["$set": ["password": hashedPassword, "updatedAt": Date()]]
        )
        
        return result.modifiedCount > 0
    }
    
    func authenticate(email: String, password: String) async throws -> User? {
        guard let user = try await findByEmail(email) else {
            return nil
        }
        
        guard try Bcrypt.verify(password, created: user.password) else {
            return nil
        }
        
        return user
    }
} 