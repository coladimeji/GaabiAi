import Foundation
import CoreLocation
import SwiftUI

actor OpenWeatherClient {
    private let settingsViewModel: SettingsViewModel
    private let networkUtility = NetworkUtility.shared
    
    init(settingsViewModel: SettingsViewModel) {
        self.settingsViewModel = settingsViewModel
    }
    
    func getCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let apiKey = settingsViewModel.getAPIKey(for: "OPENWEATHER_API_KEY")
        guard !apiKey.isEmpty else {
            throw NetworkError.missingAPIKey
        }
        
        let urlString = "https://api.openweathermap.org/data/3.0/onecall?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await networkUtility.performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let weatherData = try decoder.decode(WeatherData.self, from: data)
            return weatherData
        case 401:
            throw NetworkError.unauthorized
        case 429:
            throw NetworkError.rateLimitExceeded
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }
    
    func generateWeatherVisualization(weatherData: WeatherData) -> some View {
        VStack(spacing: 20) {
            // Current Weather
            HStack {
                Image(systemName: weatherData.current.getWeatherIcon())
                    .font(.system(size: 40))
                VStack(alignment: .leading) {
                    Text("\(Int(round(weatherData.current.temp)))°C")
                        .font(.title)
                    Text(weatherData.current.weather.first?.description.capitalized ?? "")
                        .font(.subheadline)
                }
            }
            
            // Hourly Forecast
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(weatherData.hourly.prefix(24), id: \.dt) { hourly in
                        VStack {
                            Text(formatHour(hourly.dt))
                                .font(.caption)
                            Image(systemName: hourly.getWeatherIcon())
                            Text("\(Int(round(hourly.temp)))°")
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Daily Forecast
            VStack(spacing: 10) {
                ForEach(weatherData.daily.prefix(7), id: \.dt) { daily in
                    HStack {
                        Text(formatDay(daily.dt))
                            .frame(width: 100, alignment: .leading)
                        Image(systemName: daily.getWeatherIcon())
                        Spacer()
                        Text("L: \(Int(round(daily.temp.min)))°")
                        Text("H: \(Int(round(daily.temp.max)))°")
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func formatHour(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
    
    private func formatDay(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// Weather Data Models
struct WeatherData: Codable {
    let current: CurrentWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}

struct CurrentWeather: Codable {
    let temp: Double
    let weather: [WeatherCondition]
    
    func getWeatherIcon() -> String {
        guard let condition = weather.first?.main.lowercased() else { return "sun.max" }
        switch condition {
        case _ where condition.contains("clear"): return "sun.max"
        case _ where condition.contains("cloud"): return "cloud"
        case _ where condition.contains("rain"): return "cloud.rain"
        case _ where condition.contains("snow"): return "cloud.snow"
        case _ where condition.contains("thunderstorm"): return "cloud.bolt.rain"
        default: return "sun.max"
        }
    }
}

struct HourlyForecast: Codable {
    let dt: TimeInterval
    let temp: Double
    let weather: [WeatherCondition]
    
    func getWeatherIcon() -> String {
        guard let condition = weather.first?.main.lowercased() else { return "sun.max" }
        switch condition {
        case _ where condition.contains("clear"): return "sun.max"
        case _ where condition.contains("cloud"): return "cloud"
        case _ where condition.contains("rain"): return "cloud.rain"
        case _ where condition.contains("snow"): return "cloud.snow"
        case _ where condition.contains("thunderstorm"): return "cloud.bolt.rain"
        default: return "sun.max"
        }
    }
}

struct DailyForecast: Codable {
    let dt: TimeInterval
    let temp: DailyTemperature
    let weather: [WeatherCondition]
    
    func getWeatherIcon() -> String {
        guard let condition = weather.first?.main.lowercased() else { return "sun.max" }
        switch condition {
        case _ where condition.contains("clear"): return "sun.max"
        case _ where condition.contains("cloud"): return "cloud"
        case _ where condition.contains("rain"): return "cloud.rain"
        case _ where condition.contains("snow"): return "cloud.snow"
        case _ where condition.contains("thunderstorm"): return "cloud.bolt.rain"
        default: return "sun.max"
        }
    }
}

struct DailyTemperature: Codable {
    let min: Double
    let max: Double
}

struct WeatherCondition: Codable {
    let main: String
    let description: String
} 