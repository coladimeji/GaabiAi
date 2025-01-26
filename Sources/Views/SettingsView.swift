import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingAPIKeyAlert = false
    @State private var selectedProvider: APIProvider?
    @State private var apiKeyInput = ""
    
    var body: some View {
        NavigationView {
            Form {
                // AI Models Section
                Section("AI Models") {
                    Picker("Selected Model", selection: $viewModel.selectedAIModel) {
                        ForEach(AIModel.allCases, id: \.self) { model in
                            Text(model.description).tag(model)
                        }
                    }
                    
                    Button {
                        selectedProvider = .openai
                        apiKeyInput = viewModel.getAPIKey(for: .openai) ?? ""
                        showingAPIKeyAlert = true
                    } label: {
                        HStack {
                            Text("OpenAI API Key")
                            Spacer()
                            Image(systemName: viewModel.hasAPIKey(for: .openai) ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(viewModel.hasAPIKey(for: .openai) ? .green : .red)
                        }
                    }
                }
                
                // Maps Section
                Section("Maps") {
                    Picker("Selected Provider", selection: $viewModel.selectedMapsProvider) {
                        ForEach(MapsProvider.allCases, id: \.self) { provider in
                            Text(provider.description).tag(provider)
                        }
                    }
                    
                    if viewModel.selectedMapsProvider.requiresAPIKey {
                        Button {
                            selectedProvider = .googleMaps
                            apiKeyInput = viewModel.getAPIKey(for: .googleMaps) ?? ""
                            showingAPIKeyAlert = true
                        } label: {
                            HStack {
                                Text("Google Maps API Key")
                                Spacer()
                                Image(systemName: viewModel.hasAPIKey(for: .googleMaps) ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(viewModel.hasAPIKey(for: .googleMaps) ? .green : .red)
                            }
                        }
                    }
                }
                
                // Weather Section
                Section("Weather") {
                    Picker("Selected Provider", selection: $viewModel.selectedWeatherProvider) {
                        ForEach(WeatherProvider.allCases, id: \.self) { provider in
                            Text(provider.description).tag(provider)
                        }
                    }
                    
                    if viewModel.selectedWeatherProvider.requiresAPIKey {
                        Button {
                            selectedProvider = .openWeather
                            apiKeyInput = viewModel.getAPIKey(for: .openWeather) ?? ""
                            showingAPIKeyAlert = true
                        } label: {
                            HStack {
                                Text("OpenWeather API Key")
                                Spacer()
                                Image(systemName: viewModel.hasAPIKey(for: .openWeather) ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(viewModel.hasAPIKey(for: .openWeather) ? .green : .red)
                            }
                        }
                    }
                }
                
                // App Settings Section
                Section("App Settings") {
                    Toggle("Location Services", isOn: $viewModel.locationServicesEnabled)
                    Toggle("Background Updates", isOn: $viewModel.backgroundUpdatesEnabled)
                    Toggle("Push Notifications", isOn: $viewModel.pushNotificationsEnabled)
                    
                    Picker("Theme", selection: $viewModel.selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.description).tag(theme)
                        }
                    }
                    
                    Picker("Default View", selection: $viewModel.defaultView) {
                        ForEach(DefaultView.allCases, id: \.self) { view in
                            Text(view.description).tag(view)
                        }
                    }
                }
                
                // Cache Section
                Section("Cache") {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(viewModel.cacheSize)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        viewModel.clearCache()
                    } label: {
                        Text("Clear Cache")
                    }
                }
                
                // Status Section
                Section {
                    if viewModel.isConfigurationComplete {
                        Label("Configuration Complete", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Missing API Keys", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Enter API Key", isPresented: $showingAPIKeyAlert) {
                TextField("API Key", text: $apiKeyInput)
                
                Button("Cancel", role: .cancel) {
                    apiKeyInput = ""
                }
                
                Button("Save") {
                    if let provider = selectedProvider {
                        viewModel.saveAPIKey(apiKeyInput, for: provider)
                    }
                    apiKeyInput = ""
                }
            } message: {
                if let provider = selectedProvider {
                    Text("Enter your \(provider.description) API key.")
                }
            }
        }
    }
}

enum APIProvider: String, CaseIterable {
    case openai
    case googleMaps
    case openWeather
    
    var description: String {
        switch self {
        case .openai: return "OpenAI"
        case .googleMaps: return "Google Maps"
        case .openWeather: return "OpenWeather"
        }
    }
}

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark
    
    var description: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum DefaultView: String, CaseIterable {
    case tasks
    case habits
    case voiceNotes
    
    var description: String {
        switch self {
        case .tasks: return "Tasks"
        case .habits: return "Habits"
        case .voiceNotes: return "Voice Notes"
        }
    }
}

extension MapsProvider {
    var requiresAPIKey: Bool {
        switch self {
        case .googleMaps, .mapbox: return true
        case .appleMaps, .openStreetMap: return false
        }
    }
}

extension WeatherProvider {
    var requiresAPIKey: Bool {
        switch self {
        case .openWeather, .weatherAPI, .tomorrow: return true
        case .weatherKit: return false
        }
    }
}

#Preview {
    SettingsView()
} 