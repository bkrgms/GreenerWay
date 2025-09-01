import Foundation

struct EmissionFactors {
    static let walking: Double = 0.0
    static let car: Double = 0.192
    static let transit: Double = 0.105

}

struct EmissionCalculator {
    func kgCO2(distanceMeters: Double, mode: TransportMode) -> Double {
        let km = distanceMeters / 1000.0
        let factor: Double
        
        switch mode {
        case .walking: factor = EmissionFactors.walking
        case .car: factor = EmissionFactors.car
        case .transit: factor = EmissionFactors.transit
        }
        return km * factor
    }
}
