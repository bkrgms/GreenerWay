import SwiftUI
import MapKit

struct RouteSearchView: View {
    @StateObject private var viewModel = RouteViewModel()
    @State private var showDetail = false

    // "Nereye" boşsa buton pasif olsun; diğer tüm mevcut koşullar aynı kalsın
    private var canCreateRouteFromInputs: Bool {
        let destIsEmpty = viewModel.destinationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !destIsEmpty && viewModel.canCreateRoute
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                MapView(viewModel: viewModel)
                    .frame(height: 280)
                    .cornerRadius(12)

                TextField("Nereden? (canlı konum otomatik dolar)", text: $viewModel.originText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Nereye? (adres yaz ya da haritadan seç)", text: $viewModel.destinationText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                HStack(spacing: 12) {
                    TransportModeChip(title: "Yürüyüş", system: "figure.walk", color: .orange,
                                      mode: .walking, selected: $viewModel.selectedMode)
                    TransportModeChip(title: "Araba", system: "car.fill", color: .blue,
                                      mode: .car, selected: $viewModel.selectedMode)
                    TransportModeChip(title: "Otobüs", system: "bus.fill", color: .green,
                                      mode: .transit, selected: $viewModel.selectedMode)
                }

                Button {
                    Task {
                        await viewModel.buildRoute()
                        showDetail = true
                    }
                } label: {
                    Text("Rota Oluştur")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canCreateRouteFromInputs ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!canCreateRouteFromInputs)

                NavigationLink(
                    destination: RouteDetailView(viewModel: viewModel),
                    isActive: $showDetail
                ) { EmptyView() }

                Spacer()
            }
            .padding()
            .navigationBarTitle("Rota Ara", displayMode: .inline)
            .onAppear {
                // Canlı konum iznini iste; MapView yakın takip için konuma ihtiyaç duyuyor.
                LocationDelegate.shared.requestWhenInUse()
            }
        }
    }
}

struct TransportModeChip: View {
    let title: String
    let system: String
    let color: Color
    let mode: TransportMode
    @Binding var selected: TransportMode

    var body: some View {
        Button { selected = mode } label: {
            VStack(spacing: 6) {
                Image(systemName: system).font(.title2)
                Text(title).font(.caption)
            }
            .frame(width: 90, height: 64)
            .background(selected == mode ? color.opacity(0.9) : Color.gray.opacity(0.25))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}
