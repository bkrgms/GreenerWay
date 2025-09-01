import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @ObservedObject var viewModel: RouteViewModel

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.showsUserLocation = true

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        mv.addGestureRecognizer(tap)
        return mv
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        if let from = viewModel.originCoordinate {
            let a = MKPointAnnotation()
            a.coordinate = from
            a.title = "Başlangıç"
            mapView.addAnnotation(a)

            if viewModel.routePolyline == nil && viewModel.destinationCoordinate == nil {
                let region = MKCoordinateRegion(center: from,
                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                mapView.setRegion(region, animated: true)
            }
        }

        if let to = viewModel.destinationCoordinate {
            let a = MKPointAnnotation()
            a.coordinate = to
            a.title = "Hedef"
            mapView.addAnnotation(a)
        }

        if let poly = viewModel.routePolyline {
            mapView.addOverlay(poly)
            mapView.setVisibleMapRect(poly.boundingMapRect,
                                      edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                                      animated: true)
        } else if let f = viewModel.originCoordinate, let t = viewModel.destinationCoordinate {
            let rect = boundingRectForPins(from: f, to: t)
            mapView.setVisibleMapRect(rect,
                                      edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                                      animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapView
        init(parent: MapView) { self.parent = parent }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let pt = gesture.location(in: mapView)
            let coord = mapView.convert(pt, toCoordinateFrom: mapView)
            Task { @MainActor in
                parent.viewModel.destinationCoordinate = coord
                await parent.viewModel.buildRoute()
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolyline else { return MKOverlayRenderer() }
            let r = MKPolylineRenderer(polyline: poly)
            r.strokeColor = .systemBlue
            r.lineWidth = 5
            return r
        }
    }

    private func boundingRectForPins(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> MKMapRect {
        let p1 = MKMapPoint(from)
        let p2 = MKMapPoint(to)
        return MKMapRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                         width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
    }
}
