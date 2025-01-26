import Foundation
import MongoDBVapor
import Vapor

protocol Repository {
    associatedtype Model
    var database: MongoDatabase { get }
    var collection: String { get }
}

extension Repository {
    func create(_ model: Model) async throws -> Model
    func find(id: BSONObjectID) async throws -> Model?
    func findAll() async throws -> [Model]
    func update(id: BSONObjectID, with model: Model) async throws -> Model
    func delete(id: BSONObjectID) async throws -> Bool
}

// MARK: - Repository Registration
extension Application {
    struct Repositories {
        struct Provider {
            static var mongo: Self {
                .init {
                    $0.repositories.use { app in
                        return MongoRepositories(app: app)
                    }
                }
            }
        }
        
        final class Storage {
            var makeRepositories: ((Application) -> Repositories)?
            init() { }
        }
        
        struct Key: StorageKey {
            typealias Value = Storage
        }
        
        let app: Application
        
        var userRepository: UserRepository {
            guard let makeRepositories = app.storage[Key.self]?.makeRepositories else {
                fatalError("No repository provider configured")
            }
            return makeRepositories(app).userRepository
        }
        
        var taskRepository: TaskRepository {
            guard let makeRepositories = app.storage[Key.self]?.makeRepositories else {
                fatalError("No repository provider configured")
            }
            return makeRepositories(app).taskRepository
        }
        
        var habitRepository: HabitRepository {
            guard let makeRepositories = app.storage[Key.self]?.makeRepositories else {
                fatalError("No repository provider configured")
            }
            return makeRepositories(app).habitRepository
        }
        
        var voiceNoteRepository: VoiceNoteRepository {
            guard let makeRepositories = app.storage[Key.self]?.makeRepositories else {
                fatalError("No repository provider configured")
            }
            return makeRepositories(app).voiceNoteRepository
        }
    }
    
    var repositories: Repositories {
        .init(app: self)
    }
} 