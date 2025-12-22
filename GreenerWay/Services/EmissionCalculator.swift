import Foundation

struct EmissionFactors {
    static let walking: Double = 0.0
    static let car: Double = 0.192
    static let transit: Double = 0.105

    // Yeni: Araç tipine göre emisyon faktörü (kg/km)
    static func factor(for type: VehicleType) -> Double {
        switch type {
        case .petrol:      return 0.190
        case .diesel:      return 0.170
        case .hybrid:      return 0.110
        case .electric:    return 0.0
        case .motorcycle:  return 0.100
        case .unknown:     return EmissionFactors.car // 0.192 ile geriye uyum
        }
    }
}

struct EmissionCalculator {
    func kgCO2(distanceMeters: Double, mode: TransportMode) -> Double {
        let km = distanceMeters / 1000.0
        let factor: Double

        switch mode {
        case .walking:
            factor = EmissionFactors.walking
        case .car:
            // Kullanıcının seçtiği araç tipine göre dinamik faktör
            let selected = VehicleManager.shared.getSelectedVehicleType()
            factor = EmissionFactors.factor(for: selected)
        case .transit:
            factor = EmissionFactors.transit
        }
        return km * factor
    }
}
