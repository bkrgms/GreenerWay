import SwiftUI
import MapKit
import Combine

struct MapView: UIViewRepresentable {
    let viewModel: RouteViewModel
    private let location = LocationDelegate.shared

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .includingAll

        // Konum izinlerini iste ve yüksek doğrulukta başlat
        location.requestWhenInUse()
        location.start()

        // Başlangıçta kullanıcıyı yönle takip et
        map.setUserTrackingMode(.followWithHeading, animated: false)

        // LocationDelegate'den gelen konumu dinle
        context.coordinator.bindLocationUpdates(to: map, source: location)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let toRemoveAnno = map.annotations.filter { !($0 is MKUserLocation) }
        if !toRemoveAnno.isEmpty { map.removeAnnotations(toRemoveAnno) }
        if !map.overlays.isEmpty { map.removeOverlays(map.overlays) }

        if let from = viewModel.originCoordinate {
            let a = MKPointAnnotation()
            a.coordinate = from
            a.title = "Başlangıç"
            map.addAnnotation(a)
        }
        if let to = viewModel.destinationCoordinate {
            let b = MKPointAnnotation()
            b.coordinate = to
            b.title = "Varış"
            map.addAnnotation(b)
        }

        if let poly = viewModel.routePolyline {
            map.addOverlay(poly)
            let edge = UIEdgeInsets(top: 100, left: 80, bottom: 120, right: 80)
            map.setVisibleMapRect(poly.boundingMapRect, edgePadding: edge, animated: true)
            context.coordinator.didZoomToUserOnce = true
            return
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapView
        var didZoomToUserOnce = false
        private var isRecentering = false
        private var cancellables = Set<AnyCancellable>()

        init(_ parent: MapView) {
            self.parent = parent
        }

        func bindLocationUpdates(to mapView: MKMapView, source: LocationDelegate) {
            source.$lastLocation
                .compactMap { $0 }
                .receive(on: RunLoop.main)
                .sink { [weak self, weak mapView] loc in
                    guard let self = self, let mapView = mapView else { return }
                    let c = loc.coordinate
                    let acc = loc.horizontalAccuracy
                    guard CLLocationCoordinate2DIsValid(c),
                          !(abs(c.latitude) < 0.0001 && abs(c.longitude) < 0.0001),
                          acc > 0, acc <= 35 else { return } // sokak seviyesi

                    if self.didZoomToUserOnce == false, self.parent.viewModel.routePolyline == nil {
                        // Sokak seviyesine yakın zoom
                        let region = MKCoordinateRegion(
                            center: c,
                            span: MKCoordinateSpan(latitudeDelta: 0.0008, longitudeDelta: 0.0008)
                        )
                        mapView.setRegion(region, animated: true)
                        mapView.setUserTrackingMode(.followWithHeading, animated: true)
                        self.didZoomToUserOnce = true
                    } else {
                        if mapView.userTrackingMode == .follow || mapView.userTrackingMode == .followWithHeading {
                            mapView.setCenter(c, animated: true)
                        }
                    }
                }
                .store(in: &cancellables)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isRecentering { return }
            if parent.viewModel.routePolyline != nil { return }

            guard let loc = LocationDelegate.shared.lastLocation else { return }
            let coord = loc.coordinate
            let acc = loc.horizontalAccuracy
            guard CLLocationCoordinate2DIsValid(coord),
                  !(abs(coord.latitude) < 0.0001 && abs(coord.longitude) < 0.0001),
                  acc > 0, acc <= 35 else { return }

            let userPoint = MKMapPoint(coord)
            let isVisible = mapView.visibleMapRect.contains(userPoint)
            guard isVisible == false else { return }

            isRecentering = true
            DispatchQueue.main.async {
                let region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.0008, longitudeDelta: 0.0008)
                )
                if mapView.userTrackingMode != .followWithHeading {
                    mapView.setUserTrackingMode(.followWithHeading, animated: true)
                }
                mapView.setRegion(region, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.isRecentering = false
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(overlay: line)
                r.lineWidth = 5
                r.strokeColor = UIColor.systemBlue
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
