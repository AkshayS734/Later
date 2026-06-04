import SwiftUI

struct SettingsView: View {
    @AppStorage("useBiometrics") private var useBiometrics = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Security")) {
                    Toggle("Use Face ID / Touch ID", isOn: $useBiometrics)
                        .tint(.cyan)
                    
                    Text("When enabled, Later requires biometric authentication to view your time capsules.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("Notifications")) {
                    Button("Manage Notifications") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.cyan)
                    
                    Text("We use notifications to alert you when a capsule is ready to open.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}
