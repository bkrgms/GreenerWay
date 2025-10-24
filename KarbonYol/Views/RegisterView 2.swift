import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var age = ""
    @State private var carbonSensitivity: Double = 0.5
    @State private var healthStatus = "Normal"
    @State private var travellingWithChild = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Kayıt Ol")
                    .font(.largeTitle).bold()
                    .foregroundColor(.green)

                TextField("E-posta", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                SecureField("Şifre", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                TextField("Yaş", text: $age)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                VStack(alignment: .leading) {
                    Text("Karbon Hassasiyeti: \(Int(carbonSensitivity * 100))%")
                    Slider(value: $carbonSensitivity, in: 0...1)
                }

                Picker("Sağlık Durumu", selection: $healthStatus) {
                    Text("Normal").tag("Normal")
                    Text("Kötü").tag("Kötü")
                }
                .pickerStyle(.segmented)

                Toggle("Çocuk ile seyahat ediyorum", isOn: $travellingWithChild)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button("Kayıt Ol") {
                    Task {
                        do {
                            let user = try await authVM.signUp(email: email, password: password)

                            let profile = UserProfile(
                                age: Int(age) ?? 18,
                                carbonSensitivity: carbonSensitivity,
                                healthStatus: healthStatus,
                                travellingWithChild: travellingWithChild
                            )

                            try await FirestoreManager.shared.saveUserProfile(uid: user.uid, profile: profile)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
            .padding()
        }
    }
}
