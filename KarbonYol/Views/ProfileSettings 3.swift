import SwiftUI

struct ProfileSettings: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var profileVM = ProfileSettingsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(authViewModel: authViewModel, showBack: true)

            Text("👤 Profil Ayarları")
                .font(.title)
                .bold()
                .padding(.top, 10)

            Form {
                Section(header: Text("Kişisel Bilgiler")) {
                    TextField("Yaş", value: $profileVM.age, formatter: NumberFormatter.intFormatter)
                        .keyboardType(.numberPad)

                    Picker("Sağlık Durumu", selection: $profileVM.healthStatus) {
                        Text("Normal").tag("Normal")
                        Text("Hassas").tag("Hassas")
                        Text("Kronik Rahatsızlık").tag("Kronik Rahatsızlık")
                    }

                    Toggle("Çocuk ile Seyahat", isOn: $profileVM.travellingWithChild)
                }

                Section(header: Text("Çevre Duyarlılığı")) {
                    Slider(value: $profileVM.carbonSensitivity, in: 0...1, step: 0.1) {
                        Text("Karbon Duyarlılığı")
                    }
                    Text("Seviye: \(String(format: "%.1f", profileVM.carbonSensitivity))")
                }

                Section {
                    Button {
                        Task { await profileVM.saveUserProfile() }
                    } label: {
                        Text("Profili Güncelle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task { await profileVM.loadUserProfile() }
        }
    }
}

private extension NumberFormatter {
    static let intFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        return nf
    }()
}
