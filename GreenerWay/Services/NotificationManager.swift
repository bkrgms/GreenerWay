import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Types

enum NotificationType: String {
    case dailySummary = "daily_summary"
    case weeklySummary = "weekly_summary"
    case badgeUnlocked = "badge_unlocked"
    case goalProgress = "goal_progress"
    case goalCompleted = "goal_completed"
    case trafficAlert = "traffic_alert"
    case reminder = "reminder"
}

// MARK: - Notification Manager

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                print("✅ Bildirim izni verildi")
                await scheduleDailySummaryNotification()
            } else {
                print("❌ Bildirim izni reddedildi")
            }
            
            return granted
        } catch {
            print("❌ Bildirim izni hatası: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Daily Summary Notification
    
    func scheduleDailySummaryNotification() async {
        guard isAuthorized else { return }
        
        // Mevcut daily summary bildirimini kaldır
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [NotificationType.dailySummary.rawValue])
        
        let content = UNMutableNotificationContent()
        content.title = "🌱 Günlük Özet"
        content.body = "Bugünkü karbon ayak izini kontrol etmeyi unutma!"
        content.sound = .default
        content.badge = 1
        
        // Her gün saat 20:00'de bildirim
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationType.dailySummary.rawValue, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Günlük özet bildirimi planlandı")
        } catch {
            print("❌ Bildirim planlanamadı: \(error)")
        }
    }
    
    // MARK: - Weekly Summary Notification
    
    func scheduleWeeklySummaryNotification() async {
        guard isAuthorized else { return }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [NotificationType.weeklySummary.rawValue])
        
        let content = UNMutableNotificationContent()
        content.title = "📊 Haftalık Rapor"
        content.body = "Bu haftaki karbon tasarrufunu görmeye ne dersin?"
        content.sound = .default
        
        // Her pazar saat 18:00'de
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Pazar
        dateComponents.hour = 18
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationType.weeklySummary.rawValue, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Haftalık özet bildirimi planlandı")
        } catch {
            print("❌ Bildirim planlanamadı: \(error)")
        }
    }
    
    // MARK: - Instant Notifications
    
    /// Rozet kazanıldığında bildirim gönder
    func sendBadgeUnlockedNotification(badgeTitle: String, points: Int) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🏆 Yeni Rozet!"
        content.body = "\(badgeTitle) rozetini kazandın! +\(points) puan"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "\(NotificationType.badgeUnlocked.rawValue)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Rozet bildirimi gönderilemedi: \(error)")
        }
    }
    
    /// Hedef ilerleme bildirimi
    func sendGoalProgressNotification(goalTitle: String, progress: Double) async {
        guard isAuthorized else { return }
        
        let percentage = Int(progress * 100)
        
        let content = UNMutableNotificationContent()
        content.title = "🎯 Hedef İlerlemesi"
        content.body = "\(goalTitle) hedefinde %\(percentage) ilerleme! Devam et!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "\(NotificationType.goalProgress.rawValue)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Hedef bildirimi gönderilemedi: \(error)")
        }
    }
    
    /// Hedef tamamlandı bildirimi
    func sendGoalCompletedNotification(goalTitle: String) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 Hedef Tamamlandı!"
        content.body = "\(goalTitle) hedefine ulaştın! Harika iş!"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "\(NotificationType.goalCompleted.rawValue)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Hedef tamamlama bildirimi gönderilemedi: \(error)")
        }
    }
    
    /// Trafik uyarı bildirimi
    func sendTrafficAlertNotification(severity: TrafficSeverity, routeDescription: String) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        
        switch severity {
        case .heavy:
            content.title = "⚠️ Trafik Yoğun"
            content.body = "\(routeDescription) güzergahında yoğun trafik var. Alternatif rota düşünebilirsin."
        case .severe:
            content.title = "🚨 Trafik Çok Yoğun!"
            content.body = "\(routeDescription) güzergahında çok yoğun trafik! Toplu taşıma önerilir."
        default:
            return // Düşük ve orta trafik için bildirim gönderme
        }
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "\(NotificationType.trafficAlert.rawValue)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Trafik bildirimi gönderilemedi: \(error)")
        }
    }
    
    /// Günlük tasarruf özet bildirimi
    func sendDailySavingsSummary(savedKg: Double, journeyCount: Int) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🌱 Günün Özeti"
        
        if savedKg > 0 {
            content.body = "Bugün \(journeyCount) yolculukta \(String(format: "%.2f", savedKg)) kg CO₂ tasarruf ettin! 🎉"
        } else {
            content.body = "Bugün \(journeyCount) yolculuk yaptın. Yarın daha yeşil rotalar dene!"
        }
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "\(NotificationType.dailySummary.rawValue)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Günlük özet bildirimi gönderilemedi: \(error)")
        }
    }
    
    // MARK: - Reminder Notifications
    
    /// Belirli bir zamanda hatırlatma bildirimi
    func scheduleReminderNotification(title: String, body: String, date: Date) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: "\(NotificationType.reminder.rawValue)_\(UUID().uuidString)", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Hatırlatma planlandı: \(date)")
        } catch {
            print("❌ Hatırlatma planlanamadı: \(error)")
        }
    }
    
    // MARK: - Management
    
    /// Tüm bekleyen bildirimleri listele
    func fetchPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        await MainActor.run {
            self.pendingNotifications = requests
        }
    }
    
    /// Belirli bir bildirimi iptal et
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Tüm bildirimleri iptal et
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    /// Badge sayısını sıfırla
    func resetBadgeCount() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("❌ Badge sıfırlanamadı: \(error)")
            }
        }
    }
}
