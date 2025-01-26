import Foundation
import Vapor

struct AppConfig {
    static func configure(_ app: Application) throws {
        // Configure MongoDB
        try MongoConfig.configure(app)
        
        // Register repositories
        let taskRepository = app.repositories.get(TaskRepository.self)!
        let habitRepository = app.repositories.get(HabitRepository.self)!
        let userRepository = app.repositories.get(UserRepository.self)!
        
        // Register ML weight store
        app.services.use { app in
            MLWeightStore(database: app.mongoDB.client.db("gaabi_db"))
        }
        
        // Register ML analytics service
        app.services.use { app in
            MLAnalyticsService(
                database: app.mongoDB.client.db("gaabi_db"),
                weightStore: app.services.get(MLWeightStore.self)!,
                taskRepository: taskRepository,
                userRepository: userRepository
            )
        }
        
        // Register ML experiment service
        app.services.use { app in
            MLExperimentService(
                database: app.mongoDB.client.db("gaabi_db"),
                analyticsService: app.services.get(MLAnalyticsService.self)!
            )
        }
        
        // Register weather traffic service
        app.services.use { app in
            WeatherTrafficService(
                client: app.client,
                cache: app.cache,
                weatherApiKey: Environment.get("OPENWEATHER_API_KEY") ?? "",
                trafficApiKey: Environment.get("TOMTOM_API_KEY") ?? ""
            )
        }
        
        // Register weather analysis service
        app.services.use { app in
            WeatherAnalysisService(
                database: app.mongoDB.client.db("gaabi_db")
            )
        }
        
        // Register traffic analysis service
        app.services.use { app in
            TrafficAnalysisService(
                database: app.mongoDB.client.db("gaabi_db")
            )
        }
        
        // Register route optimization service
        app.services.use { app in
            RouteOptimizationService(
                weatherTrafficService: app.services.get(WeatherTrafficService.self)!,
                weatherAnalysisService: app.services.get(WeatherAnalysisService.self)!,
                trafficAnalysisService: app.services.get(TrafficAnalysisService.self)!
            )
        }
        
        // Register weather and traffic alert service
        app.services.use { app in
            WeatherTrafficAlertService(
                weatherTrafficService: app.services.get(WeatherTrafficService.self)!,
                weatherAnalysisService: app.services.get(WeatherAnalysisService.self)!,
                trafficAnalysisService: app.services.get(TrafficAnalysisService.self)!,
                routeOptimizationService: app.services.get(RouteOptimizationService.self)!,
                notificationService: app.services.get(NotificationService.self)!
            )
        }
        
        // Register ML service
        app.services.use { app in
            let weightStore = MLWeightStore(database: app.mongoDB.client.db("gaabi_db"))
            let analyticsService = MLAnalyticsService(database: app.mongoDB.client.db("gaabi_db"))
            let experimentService = MLExperimentService(
                database: app.mongoDB.client.db("gaabi_db"),
                analyticsService: analyticsService
            )
            let notificationService = NotificationService(database: app.mongoDB.client.db("gaabi_db"))
            let visualizationService = StatisticsVisualizationService(database: app.mongoDB.client.db("gaabi_db"))
            
            let mlService = TaskMLService(
                taskRepository: taskRepository,
                habitRepository: habitRepository,
                weightStore: weightStore,
                analyticsService: analyticsService,
                experimentService: experimentService,
                notificationService: notificationService,
                visualizationService: visualizationService
            )
            
            return mlService
        }
        
        // Register task prioritization service
        app.services.use { app in
            TaskPrioritizationService(
                taskRepository: taskRepository,
                habitRepository: habitRepository,
                mlService: app.services.get(TaskMLService.self)!
            )
        }
        
        // Register visualization controller
        app.services.use { app in
            VisualizationController(
                visualizationService: app.services.get(StatisticsVisualizationService.self)!
            )
        }
        
        // Register dashboard controller
        app.services.use { app in
            DashboardController(
                dashboardService: app.services.get(DashboardService.self)!
            )
        }
        
        // Register alarm service
        app.services.use { app in
            AlarmService(
                database: app.mongoDB.client.db("gaabi_db"),
                weatherTrafficService: app.services.get(WeatherTrafficService.self)!,
                weatherAnalysisService: app.services.get(WeatherAnalysisService.self)!,
                trafficAnalysisService: app.services.get(TrafficAnalysisService.self)!,
                routeOptimizationService: app.services.get(RouteOptimizationService.self)!,
                notificationService: app.services.get(NotificationService.self)!
            )
        }
        
        // Register alarm controller
        app.services.use { app in
            AlarmController(
                alarmService: app.services.get(AlarmService.self)!
            )
        }
        
        // Register API configuration service
        app.services.use { app in
            AIConfigurationService(
                database: app.mongoDB.client.db("gaabi_db")
            )
        }
        
        // Register API configuration controller
        app.services.use { app in
            APIConfigurationController(
                configService: app.services.get(AIConfigurationService.self)!
            )
        }
        
        // Register AI model service
        app.services.use { app in
            AIModelService(
                configService: app.services.get(AIConfigurationService.self)!
            )
        }
        
        // Register Maps service
        app.services.use { app in
            MapsService(
                configService: app.services.get(AIConfigurationService.self)!
            )
        }
        
        // Register Weather service
        app.services.use { app in
            WeatherService(
                configService: app.services.get(AIConfigurationService.self)!
            )
        }
        
        // Register controllers
        try app.register(collection: TaskPrioritizationController(
            prioritizationService: app.services.get(TaskPrioritizationService.self)!
        ))
        try app.register(collection: app.services.get(VisualizationController.self)!)
        try app.register(collection: app.services.get(DashboardController.self)!)
        try app.register(collection: app.services.get(WeatherTrafficController.self)!)
        try app.register(collection: app.services.get(AlarmController.self)!)
        
        // Configure middleware
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))
        app.middleware.use(FileMiddleware.init(publicDirectory: app.directory.publicDirectory))
        app.middleware.use(SessionsMiddleware(session: app.sessions.driver))
        
        // Configure authentication
        try configureAuth(app)
    }
    
    private static func configureAuth(_ app: Application) throws {
        app.middleware.use(UserAuthenticator())
        app.middleware.use(User.sessionAuthenticator())
    }
}

// Extension to register services
extension Application {
    struct ServicesKey: StorageKey {
        typealias Value = Services
    }
    
    var services: Services {
        get {
            if let existing = storage[ServicesKey.self] {
                return existing
            }
            let new = Services()
            storage[ServicesKey.self] = new
            return new
        }
        set {
            storage[ServicesKey.self] = newValue
        }
    }
}

// Services container
final class Services {
    private var storage: [ObjectIdentifier: Any] = [:]
    
    func use<S>(_ make: @escaping (Application) -> S) {
        storage[ObjectIdentifier(S.self)] = make
    }
    
    func get<S>(_ type: S.Type = S.self) -> S? {
        storage[ObjectIdentifier(type)] as? S
    }
} 