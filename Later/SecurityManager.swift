import LocalAuthentication
import SwiftUI
import Combine

@MainActor
class SecurityManager: ObservableObject {
    @Published var isUnlocked = false
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // Check if device supports biometrics or passcode
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock your time capsules."
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    }
                }
            }
        } else {
            // No biometrics or passcode available, default to unlocked
            isUnlocked = true
        }
    }
    
    func lock() {
        isUnlocked = false
    }
}
