import Foundation

final class VehicleManager {
    static let shared = VehicleManager()
    private init() {}

    private let key = "selectedVehicleType"

    func saveVehicleType(_ type: VehicleType) {
        UserDefaults.standard.set(type.rawValue, forKey: key)
    }

    func getSelectedVehicleType() -> VehicleType {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let type = VehicleType(rawValue: raw) else {
            return .unknown
        }
        return type
    }
}
