import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @EnvironmentObject var storageManager: StorageManager
    @State private var currentStep = 0
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.1), Color.black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            TabView(selection: $currentStep) {
                // Slide 1
                VStack(spacing: 20) {
                    Image(systemName: "timer")
                        .font(.system(size: 80))
                        .foregroundColor(.cyan)
                        .padding(.bottom, 20)
                    Text("Welcome to Later")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Reclaim the joy of anticipation. In a world of instant gratification, some memories are worth waiting for.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                }
                .tag(0)
                
                // Slide 2
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                        .padding(.bottom, 20)
                    Text("Seal Your Memories")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Write a note, attach a photo or video, and lock it away. It stays hidden until the exact date you choose.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                }
                .tag(1)
                
                // Slide 3
                VStack(spacing: 20) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .padding(.bottom, 20)
                    Text("Stay Notified")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("We'll let you know the moment your capsule is ready to be opened. Please enable notifications so you don't miss out.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                    
                    Spacer().frame(height: 40)
                    
                    Button(action: {
                        storageManager.requestNotificationPermissionIfNeeded()
                        withAnimation {
                            hasSeenOnboarding = true
                        }
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.cyan)
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                    }
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle())
            
            VStack {
                Spacer()
                if currentStep < 2 {
                    Button("Skip") {
                        withAnimation {
                            hasSeenOnboarding = true
                        }
                    }
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
