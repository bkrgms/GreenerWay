import Foundation
import CoreLocation

// Ortak protokol
protocol WeatherProviding {
    func current(at coordinate: CLLocationCoordinate2D) async throws -> WeatherInfo
}

struct StubWeatherService: WeatherProviding {
    func current(at coordinate: CLLocationCoordinate2D) async throws -> WeatherInfo {
        return WeatherInfo(
            condition: .clear,
            temperatureC: 22,
            feelsLikeC: 23,
            humidity: 60,
            windSpeed: 3.5,
            precipitationChance: 0.1
        )
    }
}
