import Foundation
import CoreLocation

@MainActor
final class LocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    // delegate → konum güncellendiğinde tetiklenir
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            lastLocation = loc.coordinate
            manager.stopUpdatingLocation() // tek seferlik almak istiyorsan durdur
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Konum alınamadı: \(error)")
    }
}
