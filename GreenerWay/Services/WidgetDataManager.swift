import Foundation

// MARK: - Widget Data Manager
// Bu sınıf ana uygulama ve widget arasında veri paylaşımını yönetir

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // App Group identifier - Xcode'da Signing & Capabilities'te eklemeniz gerekiyor
    private let appGroupIdentifier = "group.com.greenerway.app"
    
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    private init() {}
    
    // MARK: - Keys
    
    private enum Keys {
        static let todayEmission = "todayEmission"
        static let todaySaved = "todaySaved"
        static let todayJourneyCount = "todayJourneyCount"
        static let lastMode = "lastMode"
        static let lastUpdateDate = "lastUpdateDate"
        static let weeklyEmission = "weeklyEmission"
        static let weeklySaved = "weeklySaved"
        static let totalPoints = "totalPoints"
        static let currentLevel = "currentLevel"
    }
    
    // MARK: - Today's Data
    
    func updateTodayEmission(emission: Double, saved: Double, mode: String) {
        guard let defaults = defaults else {
            print("❌ App Group UserDefaults erişilemedi")
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Eğer yeni bir gün ise verileri sıfırla
        if let lastUpdate = defaults.object(forKey: Keys.lastUpdateDate) as? Date {
            let lastUpdateDay = calendar.startOfDay(for: lastUpdate)
            if today > lastUpdateDay {
                resetDailyData()
            }
        }
        
        // Mevcut değerlere ekle
        let currentEmission = defaults.double(forKey: Keys.todayEmission)
        let currentSaved = defaults.double(forKey: Keys.todaySaved)
        let currentCount = defaults.integer(forKey: Keys.todayJourneyCount)
        
        defaults.set(currentEmission + emission, forKey: Keys.todayEmission)
        defaults.set(currentSaved + saved, forKey: Keys.todaySaved)
        defaults.set(currentCount + 1, forKey: Keys.todayJourneyCount)
        defaults.set(mode, forKey: Keys.lastMode)
        defaults.set(Date(), forKey: Keys.lastUpdateDate)
        
        // Widget'ı güncelle
        refreshWidget()
        
        print("✅ Widget verileri güncellendi: Emisyon=\(currentEmission + emission), Tasarruf=\(currentSaved + saved)")
    }
    
    func getTodayData() -> (emission: Double, saved: Double, journeyCount: Int, lastMode: String) {
        guard let defaults = defaults else {
            return (0, 0, 0, "walking")
        }
        
        return (
            emission: defaults.double(forKey: Keys.todayEmission),
            saved: defaults.double(forKey: Keys.todaySaved),
            journeyCount: defaults.integer(forKey: Keys.todayJourneyCount),
            lastMode: defaults.string(forKey: Keys.lastMode) ?? "walking"
        )
    }
    
    // MARK: - Weekly Data
    
    func updateWeeklyData(emission: Double, saved: Double) {
        guard let defaults = defaults else { return }
        
        let currentEmission = defaults.double(forKey: Keys.weeklyEmission)
        let currentSaved = defaults.double(forKey: Keys.weeklySaved)
        
        defaults.set(currentEmission + emission, forKey: Keys.weeklyEmission)
        defaults.set(currentSaved + saved, forKey: Keys.weeklySaved)
    }
    
    func getWeeklyData() -> (emission: Double, saved: Double) {
        guard let defaults = defaults else {
            return (0, 0)
        }
        
        return (
            emission: defaults.double(forKey: Keys.weeklyEmission),
            saved: defaults.double(forKey: Keys.weeklySaved)
        )
    }
    
    // MARK: - Points & Level
    
    func updatePointsAndLevel(points: Int, level: Int) {
        guard let defaults = defaults else { return }
        
        defaults.set(points, forKey: Keys.totalPoints)
        defaults.set(level, forKey: Keys.currentLevel)
        
        refreshWidget()
    }
    
    func getPointsAndLevel() -> (points: Int, level: Int) {
        guard let defaults = defaults else {
            return (0, 1)
        }
        
        return (
            points: defaults.integer(forKey: Keys.totalPoints),
            level: max(1, defaults.integer(forKey: Keys.currentLevel))
        )
    }
    
    // MARK: - Reset
    
    func resetDailyData() {
        guard let defaults = defaults else { return }
        
        defaults.set(0.0, forKey: Keys.todayEmission)
        defaults.set(0.0, forKey: Keys.todaySaved)
        defaults.set(0, forKey: Keys.todayJourneyCount)
        defaults.set(Date(), forKey: Keys.lastUpdateDate)
        
        refreshWidget()
        
        print("✅ Günlük widget verileri sıfırlandı")
    }
    
    func resetWeeklyData() {
        guard let defaults = defaults else { return }
        
        defaults.set(0.0, forKey: Keys.weeklyEmission)
        defaults.set(0.0, forKey: Keys.weeklySaved)
        
        refreshWidget()
    }
    
    func resetAllData() {
        guard let defaults = defaults else { return }
        
        for key in [Keys.todayEmission, Keys.todaySaved, Keys.todayJourneyCount,
                    Keys.lastMode, Keys.lastUpdateDate, Keys.weeklyEmission,
                    Keys.weeklySaved, Keys.totalPoints, Keys.currentLevel] {
            defaults.removeObject(forKey: key)
        }
        
        refreshWidget()
    }
    
    // MARK: - Widget Refresh
    
    func refreshWidget() {
        // Widget target'ınız varsa bu kodu etkinleştirin:
        // WidgetCenter.shared.reloadAllTimelines()
        // Şimdilik sadece log yazıyoruz
        print("🔄 Widget yenileme tetiklendi")
    }
}

// MARK: - RouteViewModel Extension

extension RouteViewModel {
    /// Yolculuk kaydedildiğinde widget verilerini güncelle
    func updateWidgetData(emission: Double, saved: Double, mode: TransportMode) {
        WidgetDataManager.shared.updateTodayEmission(
            emission: emission,
            saved: saved,
            mode: mode.rawValue
        )
        
        WidgetDataManager.shared.updateWeeklyData(
            emission: emission,
            saved: saved
        )
    }
}
