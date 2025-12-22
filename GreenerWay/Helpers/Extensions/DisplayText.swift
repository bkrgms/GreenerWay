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
