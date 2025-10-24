import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    let viewModel: RouteViewModel

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .includingAll

        // Başlangıçta kullanıcıyı takip et
        map.setUserTrackingMode(.follow, animated: false)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Kullanıcı konumu dışındaki annotation/overlay'leri temizle
        let toRemoveAnno = map.annotations.filter { !($0 is MKUserLocation) }
        if !toRemoveAnno.isEmpty { map.removeAnnotations(toRemoveAnno) }
        if !map.overlays.isEmpty { map.removeOverlays(map.overlays) }

        // Başlangıç & varış pinleri (varsa)
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

        // Rota çizgisi (varsa rotaya sığdır)
        if let poly = viewModel.routePolyline {
            map.addOverlay(poly)
            let edge = UIEdgeInsets(top: 100, left: 80, bottom: 120, right: 80)
            map.setVisibleMapRect(poly.boundingMapRect, edgePadding: edge, animated: true)

            // Rotaya geçtiysek bir daha "ilk zoom" yapmayalım
            context.coordinator.didZoomToUserOnce = true
            return
        }

        // Rota yoksa ve henüz "ilk zoom" yapılmadıysa kullanıcıya yakınlaş
        if context.coordinator.didZoomToUserOnce == false {
            if let loc = map.userLocation.location {
                let c = loc.coordinate
                if CLLocationCoordinate2DIsValid(c) && !(abs(c.latitude) < 0.0001 && abs(c.longitude) < 0.0001) {
                    let region = MKCoordinateRegion(
                        center: c,
                        span: MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)
                    )
                    map.setRegion(region, animated: true)
                    map.setUserTrackingMode(.follow, animated: true)
                    context.coordinator.didZoomToUserOnce = true
                    return
                }
            }

            // userLocation henüz düşmediyse, originCoordinate varsa ona yakınlaş
            if let from = viewModel.originCoordinate {
                let region = MKCoordinateRegion(
                    center: from,
                    span: MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)
                )
                map.setRegion(region, animated: true)
                map.setUserTrackingMode(.follow, animated: true)
                context.coordinator.didZoomToUserOnce = true
            }
        }

        // ÖNEMLİ: Rota yokken kullanıcı haritayı sürüklese bile tekrar takip moduna dön.
        // Bu sayede harita mevcut konuma yeniden yakınlar.
        if viewModel.routePolyline == nil, map.userTrackingMode != .follow {
            map.setUserTrackingMode(.follow, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapView
        var didZoomToUserOnce = false

        init(_ parent: MapView) {
            self.parent = parent
        }

        // Kullanıcının mavi nokta konumu güncellendiğinde, ilk defa görüyorsak süper yakın zoom yap
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard didZoomToUserOnce == false, let loc = userLocation.location else { return }
            let c = loc.coordinate
            guard CLLocationCoordinate2DIsValid(c),
                  !(abs(c.latitude) < 0.0001 && abs(c.longitude) < 0.0001) else { return }

            DispatchQueue.main.async {
                let region = MKCoordinateRegion(
                    center: c,
                    span: MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)
                )
                mapView.setRegion(region, animated: true)
                if mapView.userTrackingMode != .follow {
                    mapView.setUserTrackingMode(.follow, animated: true)
                }
                self.didZoomToUserOnce = true
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
