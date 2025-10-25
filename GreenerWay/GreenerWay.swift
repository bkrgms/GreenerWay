import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct KarbonYolApp: App {
    @StateObject var authVM = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
        // Hava durumu servisini uygulama başında ayarla (RouteViewModel bunu kullanıyor)
        _OpenWeatherServiceSingleton.shared = OpenWeatherService()
    }
    
    var body: some Scene {
        WindowGroup {
            if authVM.user != nil {
                RouteSearchView()
                    .environmentObject(authVM)   // ✅ burası önemli
            } else {
                LoginView()
                    .environmentObject(authVM)   // ✅ burası önemli
            }
        }
    }
}
