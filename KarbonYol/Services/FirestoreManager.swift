import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestore

final class FirestoreManager {
    static let shared = FirestoreManager()
    let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Profile
    
    func saveUserProfile(uid: String, profile: UserProfile) async throws {
        try db.collection("users").document(uid).setData(from: profile)
    }
    
    func fetchUserProfile() async throws -> UserProfile? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let doc = try await db.collection("users").document(uid).getDocument()
        return try doc.data(as: UserProfile.self)
    }
    
    // MARK: - Journeys
    
    func saveJourney(_ journey: Journey) async throws {
        try db.collection("journeys").addDocument(from: journey)
    }
    
    func fetchJourneys(for userId: String) async throws -> [Journey] {
        let snapshot = try await db.collection("journeys")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Journey.self)
        }
    }
    
    func clearJourneys(for userId: String) async throws {
        let snapshot = try await db.collection("journeys")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
}
