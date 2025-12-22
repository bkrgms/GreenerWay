import SwiftUI

struct BadgesView: View {
    @StateObject private var viewModel = BadgeViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: Badge.BadgeCategory? = nil
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // MARK: - Profil Özet Kartı
                    profileSummaryCard
                    
                    // MARK: - İstatistikler
                    statsGrid
                    
                    // MARK: - Kategori Filtreleri
                    categoryFilter
                    
                    // MARK: - Rozetler
                    badgesSection
                }
                .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Rozetler & Puanlar")
                    .font(.headline)
            }
        }
        .task {
            await viewModel.loadUserStats()
        }
        .alert("🎉 Yeni Rozet!", isPresented: $viewModel.showBadgeUnlockedAlert) {
            Button("Harika!", role: .cancel) {}
        } message: {
            if let badge = viewModel.recentlyUnlocked {
                Text("\(badge.title) rozetini kazandın!\n+\(badge.points) puan")
            }
        }
    }
    
    // MARK: - Profil Özet Kartı
    private var profileSummaryCard: some View {
        VStack(spacing: 16) {
            // Seviye ve Avatar
            HStack(spacing: 16) {
                // Level Badge
                ZStack {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 70, height: 70)
                    
                    Text("\(viewModel.currentLevel)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.systemBackground))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.levelTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(viewModel.totalPoints) Puan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // İlerleme Çubuğu
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary)
                                .frame(width: geo.size.width * viewModel.progressToNextLevel, height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    if viewModel.currentLevel < 10 {
                        Text("Sonraki seviye: \(viewModel.nextLevelPoints) puan")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Maksimum seviyeye ulaştın!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            
            // Rozet Özeti
            HStack {
                Spacer()
                VStack {
                    Text("\(viewModel.unlockedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Açılan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Divider()
                    .frame(height: 40)
                
                Spacer()
                VStack {
                    Text("\(viewModel.totalBadges)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Toplam")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Divider()
                    .frame(height: 40)
                
                Spacer()
                VStack {
                    Text("\(viewModel.userStats.consecutiveDays)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Gün Seri")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - İstatistikler Grid
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("İstatistikler")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatItemView(
                    icon: "map.fill",
                    value: "\(viewModel.userStats.totalJourneys)",
                    label: "Yolculuk"
                )
                StatItemView(
                    icon: "leaf.fill",
                    value: String(format: "%.1f", viewModel.userStats.totalEmissionSaved),
                    label: "kg CO₂"
                )
                StatItemView(
                    icon: "road.lanes",
                    value: String(format: "%.1f", viewModel.userStats.totalDistance),
                    label: "km"
                )
                StatItemView(
                    icon: "figure.walk",
                    value: String(format: "%.1f", viewModel.userStats.walkingDistance),
                    label: "km Yürü"
                )
                StatItemView(
                    icon: "bus.fill",
                    value: "\(viewModel.userStats.transitCount)",
                    label: "Otobüs"
                )
                StatItemView(
                    icon: "brain.fill",
                    value: "\(viewModel.userStats.aiRecommendationUsed)",
                    label: "AI"
                )
            }
        }
    }
    
    // MARK: - Kategori Filtreleri
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "Tümü",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                
                ForEach(Badge.BadgeCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    // MARK: - Rozetler Section
    private var badgesSection: some View {
        let filteredBadges = selectedCategory == nil
            ? viewModel.allBadges
            : viewModel.allBadges.filter { $0.category == selectedCategory }
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Rozetler")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(filteredBadges) { badge in
                    BadgeCardView(
                        badge: badge,
                        progress: viewModel.getProgress(for: badge)
                    )
                }
            }
        }
    }
}

// MARK: - Stat Item View
private struct StatItemView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.primary : Color(.systemGray6))
                .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge Card View
private struct BadgeCardView: View {
    let badge: Badge
    let progress: Double
    
    var body: some View {
        VStack(spacing: 10) {
            // İkon
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? Color.primary : Color(.systemGray4))
                    .frame(width: 50, height: 50)
                
                Image(systemName: badge.icon)
                    .font(.title2)
                    .foregroundColor(badge.isUnlocked ? Color(.systemBackground) : Color(.systemGray2))
            }
            
            // Başlık
            Text(badge.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            // Açıklama
            Text(badge.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // İlerleme veya Puan
            if badge.isUnlocked {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("+\(badge.points)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            } else {
                // İlerleme çubuğu
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary.opacity(0.5))
                                .frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .opacity(badge.isUnlocked ? 1 : 0.7)
    }
}

#Preview {
    BadgesView()
}
