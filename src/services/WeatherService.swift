import Foundation
import Vapor

struct WeatherData: Content {
    let temperature: Double
    let feelsLike: Double
    let humidity: Double
    let windSpeed: Double
    let windDirection: Double
    let precipitation: Double
    let condition: String
    let icon: String
    let timestamp: Date
}

struct WeatherForecast: Content {
    let hourly: [WeatherData]
    let daily: [DailyForecast]
}

struct DailyForecast: Content {
    let date: Date
    let temperatureHigh: Double
    let temperatureLow: Double
    let precipitation: Double
    let condition: String
    let icon: String
}

struct WeatherAlert: Content {
    let title: String
    let description: String
    let severity: String
    let startTime: Date
    let endTime: Date
}

final class WeatherService {
    private let configService: AIConfigurationService
    private var openWeatherClient: OpenWeatherClient?
    private var weatherAPIClient: WeatherAPIClient?
    
    init(configService: AIConfigurationService) {
        self.configService = configService
        setupClients()
    }
    
    private func setupClients() {
        let config = configService.getCurrentConfiguration()
        
        switch config.weatherProvider {
        case .openWeather:
            openWeatherClient = OpenWeatherClient(apiKey: config.apiKeys["openweather"] ?? "")
        case .weatherAPI:
            weatherAPIClient = WeatherAPIClient(apiKey: config.apiKeys["weatherapi"] ?? "")
        }
    }
    
    func getCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let config = configService.getCurrentConfiguration()
        
        switch config.weatherProvider {
        case .openWeather:
            guard let client = openWeatherClient else {
                throw Abort(.internalServerError, reason: "OpenWeather client not configured")
            }
            return try await client.getCurrentWeather(latitude: latitude, longitude: longitude)
            
        case .weatherAPI:
            guard let client = weatherAPIClient else {
                throw Abort(.internalServerError, reason: "WeatherAPI client not configured")
            }
            return try await client.getCurrentWeather(latitude: latitude, longitude: longitude)
        }
    }
    
    func getForecast(latitude: Double, longitude: Double, days: Int = 7) async throws -> WeatherForecast {
        let config = configService.getCurrentConfiguration()
        
        switch config.weatherProvider {
        case .openWeather:
            guard let client = openWeatherClient else {
                throw Abort(.internalServerError, reason: "OpenWeather client not configured")
            }
            return try await client.getForecast(latitude: latitude, longitude: longitude, days: days)
            
        case .weatherAPI:
            guard let client = weatherAPIClient else {
                throw Abort(.internalServerError, reason: "WeatherAPI client not configured")
            }
            return try await client.getForecast(latitude: latitude, longitude: longitude, days: days)
        }
    }
    
    func getAlerts(latitude: Double, longitude: Double) async throws -> [WeatherAlert] {
        let config = configService.getCurrentConfiguration()
        
        switch config.weatherProvider {
        case .openWeather:
            guard let client = openWeatherClient else {
                throw Abort(.internalServerError, reason: "OpenWeather client not configured")
            }
            return try await client.getAlerts(latitude: latitude, longitude: longitude)
            
        case .weatherAPI:
            guard let client = weatherAPIClient else {
                throw Abort(.internalServerError, reason: "WeatherAPI client not configured")
            }
            return try await client.getAlerts(latitude: latitude, longitude: longitude)
        }
    }
    
    func updateConfiguration() {
        setupClients()
    }
}

// Protocol for Weather clients
protocol WeatherClient {
    func getCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherData
    func getForecast(latitude: Double, longitude: Double, days: Int) async throws -> WeatherForecast
    func getAlerts(latitude: Double, longitude: Double) async throws -> [WeatherAlert]
}

// OpenWeather client implementation
final class OpenWeatherClient: WeatherClient {
    private let apiKey: String
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func getCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        guard let url = URL(string: "\(baseURL)/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric") else {
            throw NetworkError.invalidURL
        }
        
        let response: OpenWeatherResponse = try await NetworkUtility.shared.performRequest(url: url)
        
        return WeatherData(
            temperature: response.main.temp,
            feelsLike: response.main.feelsLike,
            humidity: response.main.humidity,
            windSpeed: response.wind.speed,
            windDirection: response.wind.deg,
            precipitation: response.rain?.oneHour ?? 0.0,
            condition: response.weather.first?.main ?? "Unknown",
            icon: response.weather.first?.icon ?? "",
            timestamp: Date(timeIntervalSince1970: response.dt)
        )
    }
    
    func getForecast(latitude: Double, longitude: Double, days: Int) async throws -> WeatherForecast {
        guard let url = URL(string: "\(baseURL)/forecast?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric") else {
            throw NetworkError.invalidURL
        }
        
        let response: OpenWeatherForecastResponse = try await NetworkUtility.shared.performRequest(url: url)
        
        // Process hourly data
        let hourlyData = response.list.map { item in
            WeatherData(
                temperature: item.main.temp,
                feelsLike: item.main.feelsLike,
                humidity: item.main.humidity,
                windSpeed: item.wind.speed,
                windDirection: item.wind.deg,
                precipitation: item.rain?.oneHour ?? 0.0,
                condition: item.weather.first?.main ?? "Unknown",
                icon: item.weather.first?.icon ?? "",
                timestamp: Date(timeIntervalSince1970: item.dt)
            )
        }
        
        // Group by day for daily forecast
        let dailyData = Dictionary(grouping: response.list) { item in
            Calendar.current.startOfDay(for: Date(timeIntervalSince1970: item.dt))
        }.map { (date, items) in
            let maxTemp = items.map { $0.main.tempMax }.max() ?? 0
            let minTemp = items.map { $0.main.tempMin }.min() ?? 0
            let totalPrecip = items.reduce(0.0) { $0 + ($1.rain?.oneHour ?? 0.0) }
            let mostCommonCondition = Dictionary(grouping: items) { $0.weather.first?.main ?? "Unknown" }
                .max(by: { $0.value.count < $1.value.count })?.key ?? "Unknown"
            let mostCommonIcon = Dictionary(grouping: items) { $0.weather.first?.icon ?? "" }
                .max(by: { $0.value.count < $1.value.count })?.key ?? ""
            
            return DailyForecast(
                date: date,
                temperatureHigh: maxTemp,
                temperatureLow: minTemp,
                precipitation: totalPrecip,
                condition: mostCommonCondition,
                icon: mostCommonIcon
            )
        }
        
        return WeatherForecast(hourly: hourlyData, daily: dailyData)
    }
    
    func getAlerts(latitude: Double, longitude: Double) async throws -> [WeatherAlert] {
        guard let url = URL(string: "\(baseURL)/onecall?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&exclude=current,minutely,hourly,daily") else {
            throw NetworkError.invalidURL
        }
        
        let response: OpenWeatherOneCallResponse = try await NetworkUtility.shared.performRequest(url: url)
        
        return response.alerts?.map { alert in
            WeatherAlert(
                title: alert.event,
                description: alert.description,
                severity: alert.severity,
                startTime: Date(timeIntervalSince1970: alert.start),
                endTime: Date(timeIntervalSince1970: alert.end)
            )
        } ?? []
    }
    
    // Generate weather visualization data
    func generateWeatherVisualization(forecast: WeatherForecast) -> VisualizationData {
        // Create temperature chart data
        let temperatureData = forecast.hourly.map { $0.temperature }
        let precipitationData = forecast.hourly.map { $0.precipitation }
        let labels = forecast.hourly.map { formatDate($0.timestamp) }
        
        // Generate SVG chart
        let svg = generateWeatherChart(
            temperatures: temperatureData,
            precipitation: precipitationData,
            labels: labels
        )
        
        return VisualizationData(
            id: UUID().uuidString,
            type: "weather_forecast",
            svgContent: svg,
            title: "Weather Forecast",
            description: "Temperature and precipitation forecast",
            timestamp: Date(),
            interactiveElements: createInteractiveElements(forecast: forecast),
            rawData: [
                "temperature": temperatureData,
                "precipitation": precipitationData
            ]
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func generateWeatherChart(temperatures: [Double], precipitation: [Double], labels: [String]) -> String {
        // Chart dimensions
        let width = 800
        let height = 400
        let padding = 40
        
        // Calculate scales
        let tempMin = temperatures.min() ?? 0
        let tempMax = temperatures.max() ?? 30
        let precipMax = precipitation.max() ?? 1
        
        // Generate SVG path for temperature line
        let tempPath = generateLinePath(
            data: temperatures,
            minValue: tempMin,
            maxValue: tempMax,
            width: width - 2 * padding,
            height: height - 2 * padding,
            padding: padding
        )
        
        // Generate SVG path for precipitation bars
        let precipBars = generatePrecipitationBars(
            data: precipitation,
            maxValue: precipMax,
            width: width - 2 * padding,
            height: height - 2 * padding,
            padding: padding
        )
        
        // Generate SVG with both visualizations
        return """
        <svg width="\(width)" height="\(height)" xmlns="http://www.w3.org/2000/svg">
            <style>
                .temp-line { fill: none; stroke: #ff6b6b; stroke-width: 2; }
                .precip-bar { fill: #4dabf7; opacity: 0.6; }
                .axis-line { stroke: #dee2e6; stroke-width: 1; }
                .label { font-family: -apple-system, system-ui; font-size: 12px; fill: #495057; }
            </style>
            <!-- Grid lines -->
            \(generateGrid(width: width, height: height, padding: padding))
            <!-- Precipitation bars -->
            \(precipBars)
            <!-- Temperature line -->
            <path d="\(tempPath)" class="temp-line"/>
            <!-- Axis labels -->
            \(generateAxisLabels(labels: labels, width: width, height: height, padding: padding))
        </svg>
        """
    }
    
    private func generateLinePath(data: [Double], minValue: Double, maxValue: Double, width: Int, height: Int, padding: Int) -> String {
        let points = data.enumerated().map { (index, value) in
            let x = padding + (width * index) / (data.count - 1)
            let y = padding + height - Int((height * (value - minValue)) / (maxValue - minValue))
            return "\(x),\(y)"
        }
        
        return "M" + points.joined(separator: " L")
    }
    
    private func generatePrecipitationBars(data: [Double], maxValue: Double, width: Int, height: Int, padding: Int) -> String {
        let barWidth = (width / data.count) - 2
        
        return data.enumerated().map { (index, value) in
            let x = padding + (width * index) / data.count
            let barHeight = Int((height * value) / maxValue)
            let y = padding + height - barHeight
            return """
            <rect
                x="\(x)"
                y="\(y)"
                width="\(barWidth)"
                height="\(barHeight)"
                class="precip-bar"
            />
            """
        }.joined()
    }
    
    private func generateGrid(width: Int, height: Int, padding: Int) -> String {
        let horizontalLines = stride(from: padding, through: height - padding, by: (height - 2 * padding) / 4)
            .map { y in
                """
                <line
                    x1="\(padding)"
                    y1="\(y)"
                    x2="\(width - padding)"
                    y2="\(y)"
                    class="axis-line"
                />
                """
            }
        
        let verticalLines = stride(from: padding, through: width - padding, by: (width - 2 * padding) / 6)
            .map { x in
                """
                <line
                    x1="\(x)"
                    y1="\(padding)"
                    x2="\(x)"
                    y2="\(height - padding)"
                    class="axis-line"
                />
                """
            }
        
        return (horizontalLines + verticalLines).joined()
    }
    
    private func generateAxisLabels(labels: [String], width: Int, height: Int, padding: Int) -> String {
        let step = labels.count / 6
        return labels.enumerated()
            .filter { $0.offset % step == 0 }
            .map { (index, label) in
                let x = padding + (width - 2 * padding) * index / (labels.count - 1)
                let y = height - padding + 20
                return """
                <text
                    x="\(x)"
                    y="\(y)"
                    text-anchor="middle"
                    class="label"
                >\(label)</text>
                """
            }
            .joined()
    }
    
    private func createInteractiveElements(forecast: WeatherForecast) -> [InteractiveElement] {
        return forecast.hourly.enumerated().map { index, data in
            InteractiveElement(
                elementId: "weather_point_\(index)",
                type: .hoverable,
                data: [
                    "temperature": String(format: "%.1f°C", data.temperature),
                    "precipitation": String(format: "%.1f mm", data.precipitation),
                    "humidity": String(format: "%.0f%%", data.humidity),
                    "wind": String(format: "%.1f m/s", data.windSpeed)
                ]
            )
        }
    }
}

// OpenWeather API response models
private struct OpenWeatherResponse: Codable {
    let weather: [Weather]
    let main: Main
    let wind: Wind
    let rain: Rain?
    let dt: TimeInterval
    
    struct Weather: Codable {
        let main: String
        let description: String
        let icon: String
    }
    
    struct Main: Codable {
        let temp: Double
        let feelsLike: Double
        let tempMin: Double
        let tempMax: Double
        let humidity: Double
        
        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case tempMin = "temp_min"
            case tempMax = "temp_max"
            case humidity
        }
    }
    
    struct Wind: Codable {
        let speed: Double
        let deg: Double
    }
    
    struct Rain: Codable {
        let oneHour: Double
        
        enum CodingKeys: String, CodingKey {
            case oneHour = "1h"
        }
    }
}

private struct OpenWeatherForecastResponse: Codable {
    let list: [ForecastItem]
    
    struct ForecastItem: Codable {
        let dt: TimeInterval
        let main: OpenWeatherResponse.Main
        let weather: [OpenWeatherResponse.Weather]
        let wind: OpenWeatherResponse.Wind
        let rain: OpenWeatherResponse.Rain?
    }
}

private struct OpenWeatherOneCallResponse: Codable {
    let alerts: [Alert]?
    
    struct Alert: Codable {
        let event: String
        let description: String
        let start: TimeInterval
        let end: TimeInterval
        let severity: String
    }
}

// WeatherAPI client implementation
final class WeatherAPIClient: WeatherClient {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func getCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        // Implement WeatherAPI current weather API call
        return WeatherData(temperature: 0, feelsLike: 0, humidity: 0,
                         windSpeed: 0, windDirection: 0, precipitation: 0,
                         condition: "", icon: "", timestamp: Date())
    }
    
    func getForecast(latitude: Double, longitude: Double, days: Int) async throws -> WeatherForecast {
        // Implement WeatherAPI forecast API call
        return WeatherForecast(hourly: [], daily: [])
    }
    
    func getAlerts(latitude: Double, longitude: Double) async throws -> [WeatherAlert] {
        // Implement WeatherAPI alerts API call
        return []
    }
} 