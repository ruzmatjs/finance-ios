import Foundation
import CoreData
import Observation

/// CloudKit sync holatini kuzatadi va UI'ga koʻrsatadi.
///
/// SwiftData ichkarida `NSPersistentCloudKitContainer` ustida ishlaydi. Uning
/// global `eventChangedNotification` bildirishnomasini tinglab, import/export
/// jarayoni holatini aniqlaymiz (Apple'ning tavsiya etilgan yondashuvi).
@MainActor
@Observable
final class CloudSyncMonitor {

    enum Status: Equatable {
        case idle          // hech narsa boʻlayotgani yoʻq
        case syncing       // import yoki export ketmoqda
        case synced(Date)  // muvaffaqiyatli yakunlandi
        case error(String) // xatolik

        var title: String {
            switch self {
            case .idle: return "Kutilmoqda"
            case .syncing: return "Sinxronlanmoqda…"
            case .synced: return "Sinxronlandi"
            case .error: return "Xatolik"
            }
        }

        var systemImage: String {
            switch self {
            case .idle: return "icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            }
        }
    }

    private(set) var status: Status = .idle
    // nonisolated(unsafe): deinit (nonisolated) shu token'ni oʻchira olishi uchun.
    // Obyekt deinit boʻlayotganda raqobatli murojaat boʻlmaydi, shuning uchun xavfsiz.
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    /// Sync yoqilgan boʻlsagina kuzatuvni boshlaydi.
    func start(enabled: Bool) {
        guard enabled, observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event
            else { return }
            // MainActor'ga koʻchiramiz.
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            status = .syncing               // hali davom etmoqda
        } else if let error = event.error {
            status = .error(error.localizedDescription)
        } else {
            status = .synced(event.endDate ?? Date())
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
