import Foundation
import SwiftUI

extension WeatherInfo.Condition {
    var displayText: String {
        switch self {
        case .clear: return "Açık"
        case .clouds: return "Bulutlu"
        case .rain: return "Yağmurlu"
        case .snow: return "Karlı"
        case .unknown: return "Bilinmiyor"
        }
    }
}

extension TrafficLevel {
    var displayText: String {
        switch self {
        case .low: return "Düşük"
        case .medium: return "Orta"
        case .high: return "Yüksek"
        case .unknown: return "Bilinmiyor"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .unknown: return .gray
        }
    }
}
