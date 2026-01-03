gitimport SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GoalsView: View {
    @StateObject private var viewModel = GoalsViewModel()
    @State private var showAddGoal = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Üst Bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Hedeflerim")
                    .font(.headline)
                
                Spacer()
                
                Button { showAddGoal = true } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding()
            
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.goals.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary)
                    
                    Text("Henüz hedef yok")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Kendine bir CO₂ tasarruf hedefi belirle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        showAddGoal = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Hedef Ekle")
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.primary)
                        .foregroundColor(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(viewModel.goals) { goal in
                            GoalCard(goal: goal, viewModel: viewModel)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadGoals()
        }
    }
}

// MARK: - Goal Card
private struct GoalCard: View {
    let goal: Goal
    @ObservedObject var viewModel: GoalsViewModel
    
    private var progress: Double {
        min(goal.currentValue / goal.targetValue, 1.0)
    }
    
    private var progressPercent: Int {
        Int(progress * 100)
    }
    
    private var isCompleted: Bool {
        goal.currentValue >= goal.targetValue
    }
    
    private var daysRemaining: Int {
        let calendar = Calendar.current
        let remaining = calendar.dateComponents([.day], from: Date(), to: goal.endDate).day ?? 0
        return max(0, remaining)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Başlık ve Durum
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(daysRemaining) gün kaldı")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    Text("\(progressPercent)%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isCompleted ? Color.green : Color.primary)
                        .frame(width: geo.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)
            
            // Değerler
            HStack {
                VStack(alignment: .leading) {
                    Text("Mevcut")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f kg", goal.currentValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Hedef")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f kg", goal.targetValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Add Goal Sheet
private struct AddGoalSheet: View {
    @ObservedObject var viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var targetValue: Double = 20
    @State private var duration: GoalDuration = .monthly
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Başlık
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hedef Adı")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Örn: Aylık CO₂ Tasarrufu", text: $title)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                // Hedef Değer
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hedef CO₂ Tasarrufu (kg)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Slider(value: $targetValue, in: 5...100, step: 5)
                        Text("\(Int(targetValue)) kg")
                            .font(.headline)
                            .frame(width: 60)
                    }
                }
                
                // Süre
                VStack(alignment: .leading, spacing: 8) {
                    Text("Süre")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Süre", selection: $duration) {
                        ForEach(GoalDuration.allCases, id: \.self) { d in
                            Text(d.title).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Spacer()
                
                // Kaydet Butonu
                Button {
                    Task {
                        await viewModel.addGoal(
                            title: title.isEmpty ? "CO₂ Tasarruf Hedefi" : title,
                            targetValue: targetValue,
                            duration: duration
                        )
                        dismiss()
                    }
                } label: {
                    Text("Hedef Oluştur")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary)
                        .foregroundColor(Color(.systemBackground))
                        .cornerRadius(14)
                }
            }
            .padding()
            .navigationTitle("Yeni Hedef")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Goal Model
struct Goal: Identifiable, Codable {
    var id: String
    var title: String
    var targetValue: Double
    var currentValue: Double
    var startDate: Date
    var endDate: Date
    var isCompleted: Bool
    
    init(id: String = UUID().uuidString, title: String, targetValue: Double, currentValue: Double = 0, startDate: Date = Date(), endDate: Date, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
    }
}

// MARK: - Goal Duration
enum GoalDuration: String, CaseIterable {
    case weekly, monthly, quarterly
    
    var title: String {
        switch self {
        case .weekly: return "Haftalık"
        case .monthly: return "Aylık"
        case .quarterly: return "3 Aylık"
        }
    }
    
    var days: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 90
        }
    }
}

// MARK: - Goals ViewModel
@MainActor
class GoalsViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    func loadGoals() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        do {
            let snapshot = try await db.collection("goals")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            var loadedGoals: [Goal] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                
                let startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
                let endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()
                
                let goal = Goal(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    targetValue: data["targetValue"] as? Double ?? 0,
                    currentValue: data["currentValue"] as? Double ?? 0,
                    startDate: startDate,
                    endDate: endDate,
                    isCompleted: data["isCompleted"] as? Bool ?? false
                )
                loadedGoals.append(goal)
            }
            
            goals = loadedGoals.sorted { $0.endDate < $1.endDate }
            
            // Mevcut ilerlemeyi güncelle
            await updateGoalsProgress()
            
        } catch {
            print("❌ Goals hata: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func addGoal(title: String, targetValue: Double, duration: GoalDuration) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: duration.days, to: Date()) ?? Date()
        
        let goalData: [String: Any] = [
            "userId": userId,
            "title": title,
            "targetValue": targetValue,
            "currentValue": 0,
            "startDate": Timestamp(date: Date()),
            "endDate": Timestamp(date: endDate),
            "isCompleted": false
        ]
        
        do {
            try await db.collection("goals").addDocument(data: goalData)
            await loadGoals()
            print("✅ Hedef eklendi: \(title)")
        } catch {
            print("❌ Hedef eklenemedi: \(error.localizedDescription)")
        }
    }
    
    private func updateGoalsProgress() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Her hedef için ilgili dönemdeki tasarrufu hesapla
        for i in 0..<goals.count {
            let goal = goals[i]
            
            do {
                let snapshot = try await db.collection("journeys")
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                var totalSaved: Double = 0
                
                for doc in snapshot.documents {
                    let data = doc.data()
                    if let timestamp = data["date"] as? Timestamp {
                        let journeyDate = timestamp.dateValue()
                        
                        // Hedef tarih aralığında mı?
                        if journeyDate >= goal.startDate && journeyDate <= goal.endDate {
                            let emission = data["emissionKg"] as? Double ?? 0
                            let mode = data["mode"] as? String ?? "car"
                            let distance = data["distanceKm"] as? Double ?? 0
                            
                            // Araba yerine yürüyüş/otobüs kullanıldıysa tasarruf
                            if mode == "walking" {
                                totalSaved += distance * 0.17 // Araba emisyonu tasarrufu
                            } else if mode == "transit" {
                                totalSaved += distance * 0.09 // Kısmi tasarruf
                            }
                        }
                    }
                }
                
                goals[i].currentValue = totalSaved
                
                // Firebase'i güncelle
                if totalSaved > 0 {
                    try await db.collection("goals").document(goal.id).updateData([
                        "currentValue": totalSaved,
                        "isCompleted": totalSaved >= goal.targetValue
                    ])
                }
                
            } catch {
                print("❌ Hedef güncelleme hatası: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    GoalsView()
}
