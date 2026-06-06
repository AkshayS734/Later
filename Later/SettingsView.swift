import SwiftUI

struct SettingsView: View {
    @AppStorage("useBiometrics") private var useBiometrics = true
    @Environment(\.dismiss) var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Face ID / Touch ID", isOn: $useBiometrics)
                } header: {
                    Text("Security")
                } footer: {
                    Text("Require biometric authentication to view your time capsules.")
                }

                Section {
                    Button("Manage Notifications") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Used to alert you when a capsule is ready to open.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(AppTheme.secondaryLabel)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
