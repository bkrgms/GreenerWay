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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Başlık
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.primary.opacity(0.7))
                    Text("Kayıt Ol")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)

                // Form
                VStack(spacing: 16) {
                    // Email
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        TextField("E-posta", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                    // Şifre
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        SecureField("Şifre", text: $password)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                    // Yaş
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        TextField("Yaş", text: $age)
                            .keyboardType(.numberPad)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                }

                // Karbon Hassasiyeti
                VStack(alignment: .leading, spacing: 8) {
                    Text("Karbon Hassasiyeti")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("Düşük")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $carbonSensitivity, in: 0...1)
                            .tint(.primary)
                        Text("Yüksek")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Seviye: \(Int(carbonSensitivity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Sağlık Durumu
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sağlık Durumu")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("Sağlık", selection: $healthStatus) {
                        Text("Normal").tag("Normal")
                        Text("Hassas").tag("Hassas")
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Çocuklu Seyahat
                Toggle(isOn: $travellingWithChild) {
                    HStack {
                        Image(systemName: "figure.and.child.holdinghands")
                            .foregroundColor(.secondary)
                        Text("Çocuk ile seyahat ediyorum")
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                // Kayıt Butonu
                Button {
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
                } label: {
                    Text("Kayıt Ol")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary)
                        .foregroundColor(Color(.systemBackground))
                        .cornerRadius(12)
                }
                
                Spacer().frame(height: 20)
            }
            .padding()
        }
        .navigationTitle("Kayıt")
        .navigationBarTitleDisplayMode(.inline)
    }
}
