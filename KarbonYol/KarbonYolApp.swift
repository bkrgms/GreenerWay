import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct KarbonYolApp: App {
    @StateObject var authVM = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
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
