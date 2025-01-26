import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    @AppStorage("selectedAIModel") private var selectedAIModelRaw: String = AIModel.gpt4.rawValue
    @AppStorage("selectedMapsProvider") private var selectedMapsProviderRaw: String = MapsProvider.googleMaps.rawValue
    @AppStorage("selectedWeatherProvider") private var selectedWeatherProviderRaw: String = WeatherProvider.openWeather.rawValue
    @AppStorage("locationServicesEnabled") var locationServicesEnabled: Bool = false
    @AppStorage("backgroundUpdatesEnabled") var backgroundUpdatesEnabled: Bool = false
    @AppStorage("pushNotificationsEnabled") var pushNotificationsEnabled: Bool = false
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("defaultView") private var defaultViewRaw: String = DefaultView.tasks.rawValue
    
    @Published var apiKeys: [String: String] = [:]
    @Published private(set) var cacheSize: String = "0 MB"
    
    var selectedAIModel: AIModel {
        get { AIModel(rawValue: selectedAIModelRaw) ?? .gpt4 }
        set { selectedAIModelRaw = newValue.rawValue }
    }
    
    var selectedMapsProvider: MapsProvider {
        get { MapsProvider(rawValue: selectedMapsProviderRaw) ?? .googleMaps }
        set { selectedMapsProviderRaw = newValue.rawValue }
    }
    
    var selectedWeatherProvider: WeatherProvider {
        get { WeatherProvider(rawValue: selectedWeatherProviderRaw) ?? .openWeather }
        set { selectedWeatherProviderRaw = newValue.rawValue }
    }
    
    var selectedTheme: AppTheme {
        get { AppTheme(rawValue: selectedThemeRaw) ?? .system }
        set { selectedThemeRaw = newValue.rawValue }
    }
    
    var defaultView: DefaultView {
        get { DefaultView(rawValue: defaultViewRaw) ?? .tasks }
        set { defaultViewRaw = newValue.rawValue }
    }
    
    var isConfigurationComplete: Bool {
        validateConfiguration()
    }
    
    init() {
        loadAPIKeys()
        calculateCacheSize()
    }
    
    func loadAPIKeys() {
        if let keys = UserDefaults.standard.dictionary(forKey: "apiKeys") as? [String: String] {
            apiKeys = keys
        }
    }
    
    func saveAPIKey(_ key: String, for provider: APIProvider) {
        apiKeys[provider.rawValue] = key
        UserDefaults.standard.set(apiKeys, forKey: "apiKeys")
    }
    
    func getAPIKey(for provider: APIProvider) -> String? {
        return apiKeys[provider.rawValue]
    }
    
    func hasAPIKey(for provider: APIProvider) -> Bool {
        return (apiKeys[provider.rawValue]?.isEmpty == false)
    }
    
    private func calculateCacheSize() {
        // In a real app, calculate actual cache size
        // For now, return a mock value
        DispatchQueue.main.async {
            self.cacheSize = "24.5 MB"
        }
    }
    
    func clearCache() {
        // In a real app, implement cache clearing logic
        DispatchQueue.main.async {
            self.cacheSize = "0 MB"
        }
    }
    
    private func validateConfiguration() -> Bool {
        let requiredProviders: [APIProvider] = [
            .openai,
            selectedMapsProvider.requiresAPIKey ? .googleMaps : nil,
            selectedWeatherProvider.requiresAPIKey ? .openWeather : nil
        ].compactMap { $0 }
        
        return requiredProviders.allSatisfy { hasAPIKey(for: $0) }
    }
} 