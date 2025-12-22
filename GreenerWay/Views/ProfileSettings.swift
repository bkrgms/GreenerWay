import SwiftUI

struct ProfileSettings: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var profileVM = ProfileSettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showValidationWarning = false
    
    // Validasyon kontrolü
    private var isProfileValid: Bool {
        profileVM.age > 0 && profileVM.age < 120
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // MARK: - Kişisel Bilgiler
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeaderView(title: "Kişisel Bilgiler", icon: "person.fill")
                    
                    // Yaş (Zorunlu)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Yaş")
                                .foregroundColor(.secondary)
                            Text("*")
                                .foregroundColor(.red)
                            Spacer()
                            TextField("", value: $profileVM.age, formatter: NumberFormatter.intFormatter)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                        if profileVM.age <= 0 || profileVM.age >= 120 {
                            Text("Geçerli bir yaş giriniz")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(profileVM.age > 0 && profileVM.age < 120 ? Color.clear : Color.red.opacity(0.5), lineWidth: 1)
                    )
                    
                // Sağlık Durumu
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sağlık Durumu")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    Picker("Sağlık Durumu", selection: $profileVM.healthStatus) {
                        Text("Normal").tag("Normal")
                        Text("Hassas").tag("Hassas")
                        Text("Kronik Rahatsızlık").tag("Kronik Rahatsızlık")
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                    
                    // Çocukla Seyahat
                    Toggle(isOn: $profileVM.travellingWithChild) {
                        HStack {
                            Image(systemName: "figure.and.child.holdinghands")
                                .foregroundColor(.secondary)
                            Text("Çocuk ile Seyahat")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // MARK: - Araç Bilgileri
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeaderView(title: "Araç Bilgileri", icon: "car.fill")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Araç Tipi")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        
                        Picker("Araç Tipi", selection: $profileVM.selectedVehicleType) {
                            ForEach(VehicleType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // MARK: - Çevre Duyarlılığı
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeaderView(title: "Çevre Duyarlılığı", icon: "leaf.fill")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Karbon Duyarlılığı")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(profileVM.carbonSensitivity * 100))%")
                                .fontWeight(.medium)
                        }
                        Slider(value: $profileVM.carbonSensitivity, in: 0...1, step: 0.1)
                            .tint(.primary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // MARK: - Rozetler
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeaderView(title: "Kazanılan Rozetler", icon: "medal.fill")
                    
                    if profileVM.earnedBadges.isEmpty {
                        HStack {
                            Image(systemName: "trophy")
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Henüz rozet kazanılmadı")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(profileVM.earnedBadges, id: \.self) { badgeId in
                                BadgeRowView(badgeId: badgeId)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // MARK: - Kaydet Butonu
                Button {
                    if isProfileValid {
                        Task {
                            await profileVM.saveUserProfile()
                            dismiss()
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
                
                Spacer().frame(height: 20)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Geçersiz Bilgi", isPresented: $showValidationWarning) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Lütfen geçerli bir yaş giriniz (1-119 arası).")
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profil")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    authViewModel.signOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .alert("Eksik Bilgi", isPresented: $showValidationWarning) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Lütfen geçerli bir yaş giriniz (1-119 arası).")
        }
        .onAppear {
            Task { await profileVM.loadUserProfile() }
        }
    }
}

// MARK: - Section Header
private struct SectionHeaderView: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.primary.opacity(0.6))
            Text(title)
                .font(.headline)
        }
    }
}

// MARK: - Badge Row
private struct BadgeRowView: View {
    let badgeId: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: badge?.icon ?? "medal.fill")
                .foregroundColor(.primary.opacity(0.7))
            Text(badge?.title ?? badgeId)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green.opacity(0.7))
        }
    }
    
    private var badge: Badge? {
        BadgeDefinitions.getBadge(by: badgeId)
    }
}

private extension NumberFormatter {
    static let intFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        return formatter
    }()
}

#Preview {
    NavigationView {
        ProfileSettings()
            .environmentObject(AuthViewModel())
    }
}
