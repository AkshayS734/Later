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
                // App Header
                Section {
                    VStack(spacing: AppTheme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.12))
                                .frame(width: 64, height: 64)
                            Image(systemName: "clock.badge.plus")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(AppTheme.accent)
                        }

                        VStack(spacing: AppTheme.Spacing.xs) {
                            Text("Later")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.label)
                            Text("Memories worth waiting for.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.secondaryLabel)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .listRowBackground(Color.clear)
                }

                // Security
                Section {
                    Toggle(isOn: $useBiometrics) {
                        Label {
                            Text("Face ID / Touch ID")
                        } icon: {
                            Image(systemName: "faceid")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Require biometric authentication to view your time capsules.")
                }

                // Notifications
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label {
                                Text("Manage Notifications")
                                    .foregroundStyle(AppTheme.label)
                            } icon: {
                                Image(systemName: "bell.badge")
                                    .foregroundStyle(AppTheme.accent)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.tertiaryLabel)
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Used to alert you when a capsule is ready to open.")
                }

                // About
                Section {
                    HStack {
                        Label {
                            Text("Version")
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(AppTheme.accent)
                        }
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(AppTheme.secondaryLabel)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, AppTheme.Spacing.xs)
                            .background(Color(.tertiarySystemFill), in: SwiftUI.Capsule())
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Later helps you seal messages, photos, and videos for your future self — because some memories are worth the wait.")
                        .padding(.top, AppTheme.Spacing.sm)
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
