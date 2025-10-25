import Foundation

struct RecommendationEngine {
    func recommend(weather: WeatherInfo,
                   traffic: TrafficLevel,
                   distanceKm: Double,
                   profile: UserProfile) -> TransportMode {
        
        var scores: [TransportMode: Double] = [
            .car: 0,
            .walking: 0
        ]
        
        // Hava durumu
        switch weather.condition {
        case .rain, .snow:
            scores[.car]! += 2
        case .clear:
            scores[.walking]! += 1
        default:
            break
        }

        
        // Trafik
        switch traffic {
        case .low:
            scores[.car]! += 1
        case .high:
            scores[.walking]! += 1
        default:
            break
        }
        

        if distanceKm < 1.2 {
            scores[.walking]! += 2
        } else if distanceKm < 4 {
            scores[.walking]! += 1
        } else if distanceKm > 12 {
            scores[.car]! += 0.5
        }
        

        if profile.travellingWithChild {
            scores[.car]! += 1
        }
        

        return scores.max(by: { $0.value < $1.value })?.key ?? .car
    }
}
