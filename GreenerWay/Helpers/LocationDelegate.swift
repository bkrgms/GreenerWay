import Foundation
import CoreLocation
import Combine

final class LocationDelegate: NSObject, ObservableObject {
    static let shared = LocationDelegate()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // Navigasyon için en yüksek doğruluk
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .otherNavigation
    }

    func requestWhenInUse() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestHighAccuracyIfNeeded()
            manager.requestLocation()
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func start() {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            requestHighAccuracyIfNeeded()
            manager.startUpdatingLocation()
        }
    }

    func stop() { manager.stopUpdatingLocation() }

    private func requestHighAccuracyIfNeeded() {
        if #available(iOS 14.0, *) {
            if manager.accuracyAuthorization == .reducedAccuracy {
                manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "LocationPreciseUsage") { error in
                    if let error = error {
                        print("⚠️ Full accuracy request failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

extension LocationDelegate: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            requestHighAccuracyIfNeeded()
            manager.requestLocation()
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // En iyi (en düşük yatay doğruluk) ve taze (≤ 10 sn) fix'i seç
        let now = Date()
        let freshGood = locations.filter {
            $0.horizontalAccuracy > 0 &&
            $0.horizontalAccuracy <= 65 && // kaba eşik: 65 m'den iyi
            now.timeIntervalSince($0.timestamp) <= 10
        }
        if let best = freshGood.min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }) ?? locations.last {
            lastLocation = best
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
}
