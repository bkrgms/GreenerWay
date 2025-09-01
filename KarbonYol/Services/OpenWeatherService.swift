import Foundation
import CoreLocation

struct OpenWeatherService: WeatherProviding {
    private let apiKey = "dd7d88986c82efd79a7c486d03c41b70"

    func current(at coordinate: CLLocationCoordinate2D) async throws -> WeatherInfo {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) } 
        
        let (data, _) = try await URLSession.shared.data(from: url)

        // debug için gelen JSON'u yazdır
        if let json = String(data: data, encoding: .utf8) {
            print("🌍 OpenWeather Response: \(json)")
        }

        let decoded = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)

        let main = decoded.weather.first?.main.lowercased() ?? "clear"
        let condition: WeatherInfo.Condition
        if main.contains("rain") {
            condition = .rain
        } else if main.contains("snow") {
            condition = .snow
        } else if main.contains("clouds") {
            condition = .clouds
        } else if main.contains("clear") {
            condition = .clear
        } else {
            condition = .unknown
        }
        
        return WeatherInfo(
            condition: condition,
            temperatureC: decoded.main.temp,
            feelsLikeC: decoded.main.feelsLike,
            humidity: decoded.main.humidity,
            windSpeed: decoded.wind.speed,
            precipitationChance: 0.0
        )
    }
}


// MARK: - OpenWeather JSON modelleri
struct OpenWeatherResponse: Codable {
    let weather: [WeatherCondition]
    let main: WeatherMain
    let wind: WeatherWind
}

struct WeatherCondition: Codable {
    let main: String
}

struct WeatherMain: Codable {
    let temp: Double
    let feelsLike: Double
    let humidity: Int
    
    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case humidity
    }
}

struct WeatherWind: Codable {
    let speed: Double
}
