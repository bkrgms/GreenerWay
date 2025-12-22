import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var dailyReminderEnabled = true
    @State private var weeklyReportEnabled = true
    @State private var badgeNotificationsEnabled = true
    @State private var trafficAlertsEnabled = true
    @State private var reminderTime = Date()
    @State private var showPermissionAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Permission Card
                permissionCard
                
                // Notification Settings
                if notificationManager.isAuthorized {
                    notificationSettingsCard
                    reminderTimeCard
                }
            }
            .padding()
        }
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
        .alert("Bildirim İzni Gerekli", isPresented: $showPermissionAlert) {
            Button("Ayarlara Git") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Bildirimleri etkinleştirmek için ayarlardan izin vermeniz gerekiyor.")
        }
    }
    
    // MARK: - Permission Card
    
    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: notificationManager.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                    .font(.title2)
                    .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bildirim İzni")
                        .font(.headline)
                    Text(notificationManager.isAuthorized ? "Bildirimler etkin" : "Bildirimler kapalı")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !notificationManager.isAuthorized {
                    Button("Etkinleştir") {
                        Task {
                            let granted = await notificationManager.requestPermission()
                            if !granted {
                                showPermissionAlert = true
                            }
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Notification Settings Card
    
    private var notificationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bildirim Türleri")
                .font(.headline)
            
            // Daily Reminder
            Toggle(isOn: $dailyReminderEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Günlük Hatırlatma")
                            .font(.subheadline)
                        Text("Her gün karbon ayak izini hatırlat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
            .onChange(of: dailyReminderEnabled) { _, enabled in
                if enabled {
                    Task { await notificationManager.scheduleDailySummaryNotification() }
                } else {
                    notificationManager.cancelNotification(identifier: NotificationType.dailySummary.rawValue)
                }
            }
            
            Divider()
            
            // Weekly Report
            Toggle(isOn: $weeklyReportEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haftalık Rapor")
                            .font(.subheadline)
                        Text("Her pazar haftalık özet gönder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
            .onChange(of: weeklyReportEnabled) { _, enabled in
                if enabled {
                    Task { await notificationManager.scheduleWeeklySummaryNotification() }
                } else {
                    notificationManager.cancelNotification(identifier: NotificationType.weeklySummary.rawValue)
                }
            }
            
            Divider()
            
            // Badge Notifications
            Toggle(isOn: $badgeNotificationsEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rozet Bildirimleri")
                            .font(.subheadline)
                        Text("Yeni rozet kazandığında bildir")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
            
            Divider()
            
            // Traffic Alerts
            Toggle(isOn: $trafficAlertsEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "car.fill")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trafik Uyarıları")
                            .font(.subheadline)
                        Text("Yoğun trafik durumlarında bildir")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Reminder Time Card
    
    private var reminderTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hatırlatma Saati")
                .font(.headline)
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
                
                DatePicker(
                    "Hatırlatma Saati",
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            }
            
            Text("Günlük hatırlatma bu saatte gönderilecek")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
}
