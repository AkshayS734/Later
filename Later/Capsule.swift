import Foundation
import SwiftData

@Model
final class Capsule: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var mediaPath: String?
    var mediaType: String?
    var creationDate: Date
    var unlockDate: Date
    var isOpened: Bool
    var isSurprise: Bool = false
    
    init(id: UUID = UUID(), title: String, note: String, mediaPath: String? = nil, mediaType: String? = nil, creationDate: Date = Date(), unlockDate: Date, isOpened: Bool = false, isSurprise: Bool = false) {
        self.id = id
        self.title = title
        self.note = note
        self.mediaPath = mediaPath
        self.mediaType = mediaType
        self.creationDate = creationDate
        self.unlockDate = unlockDate
        self.isOpened = isOpened
        self.isSurprise = isSurprise
    }
    
    @Transient
    var isUnlockable: Bool {
        return Date() >= unlockDate
    }
    
    @Transient
    var timeRemaining: TimeInterval? {
        let remaining = unlockDate.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
}
