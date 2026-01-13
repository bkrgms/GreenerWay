import SwiftUI

struct ProfileSettings: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var profileVM = ProfileSettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showValidationWarning = false
    @State private var ageText: String = ""
    
    // Validasyon kontrolü
    private var isProfileValid: Bool {
        guard let age = Int(ageText) else { return false }
        return age > 0 && age < 120
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // MARK: - Profil Bilgileri
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        Text("Profil Bilgileri")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    // Yaş (Zorunlu)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Yaş")
                                .foregroundColor(.secondary)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
                        TextField("Yaşınızı giriniz", text: $ageText)
                            .keyboardType(.numberPad)
                            .font(.body)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isProfileValid || ageText.isEmpty ? Color.primary.opacity(0.1) : Color.red.opacity(0.5), lineWidth: 1)
                            )
                        
                        if !ageText.isEmpty && !isProfileValid {
                            Text("Lütfen 1-119 arası geçerli bir yaş giriniz")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                // MARK: - Kaydet Butonu
                Button {
                    if isProfileValid {
                        if let age = Int(ageText) {
                            profileVM.age = age
                            Task {
                                await profileVM.saveUserProfile()
                                dismiss()
                            }
                        }
                    } else {
                        showValidationWarning = true
                    }
                } label: {
                    Text("Kaydet")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isProfileValid ? Color.primary : Color(.systemGray4))
                        .foregroundColor(isProfileValid ? Color(.systemBackground) : .secondary)
                        .cornerRadius(12)
                }
                .disabled(!isProfileValid)
                
                Spacer().frame(height: 20)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profil Ayarları")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    authViewModel.signOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Geçersiz Bilgi", isPresented: $showValidationWarning) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Lütfen geçerli bir yaş giriniz (1-119 arası).")
        }
        .onAppear {
            Task {
                await profileVM.loadUserProfile()
                ageText = "\(profileVM.age)"
            }
        }
    }
}

#Preview {
    NavigationView {
        ProfileSettings()
            .environmentObject(AuthViewModel())
    }
}
