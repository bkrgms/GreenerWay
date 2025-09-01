import Foundation

struct WeatherInfo: Codable {
    let condition: Condition
    let temperatureC: Double       // Anlık sıcaklık
    let feelsLikeC: Double         // Hissedilen sıcaklık
    let humidity: Int              // Nem (%)
    let windSpeed: Double          // Rüzgar hızı (m/s)
    let precipitationChance: Double // Yağış ihtimali (0.0 - 1.0)
    
    enum Condition: String, Codable {
        case clear
        case clouds
        case rain
        case snow
        case unknown
    }
}
