import Combine
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

@MainActor
class StorageManager: ObservableObject {
    @Published private var dummyState = false
    
    // MARK: - Notifications
    
    /// Called once when the user seals their first capsule — permission context is clear at this point.
    func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }
    
    func scheduleNotification(for capsule: Capsule) {
        let content = UNMutableNotificationContent()
        content.title = "Capsule Unlocked!"
        content.body = "Your memory '\(capsule.title)' is now ready to view."
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: capsule.unlockDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: capsule.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(for capsule: Capsule) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [capsule.id.uuidString])
    }
    
    // MARK: - File Paths
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getMediaURL(for path: String) -> URL {
        documentsDirectory.appendingPathComponent(path)
    }
    
    // MARK: - Media Operations
    
    /// Copies a media file from a temporary URL and returns the local file name.
    func copyMedia(from sourceURL: URL, mediaType: String?, capsuleId: UUID) -> String? {
        guard let mediaType = mediaType else { return nil }
        
        let fileExtension = UTType(mediaType)?.preferredFilenameExtension ?? "data"
        let mediaFileName = "\(capsuleId.uuidString).\(fileExtension)"
        let destURL = getMediaURL(for: mediaFileName)
        
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: sourceURL, to: destURL)
            
            // Clean up temporary source file
            try? fm.removeItem(at: sourceURL)
            return mediaFileName
        } catch {
            print("Error saving media: \(error)")
            return nil
        }
    }
    
    func deleteMedia(for capsule: Capsule) {
        if let mediaPath = capsule.mediaPath {
            let mediaURL = getMediaURL(for: mediaPath)
            try? FileManager.default.removeItem(at: mediaURL)
        }
    }
    
    // MARK: - Helpers
    
    func fullMediaURL(for capsule: Capsule) -> URL? {
        guard let path = capsule.mediaPath else { return nil }
        return getMediaURL(for: path)
    }
}
