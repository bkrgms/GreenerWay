import Foundation

enum VehicleType: String, CaseIterable, Identifiable {
    case petrol = "Benzinli"
    case diesel = "Dizel"
    case hybrid = "Hibrit"
    case electric = "Elektrikli"
    case motorcycle = "Motosiklet"
    case unknown = "Belirtilmedi"

    var id: String { rawValue }
}
