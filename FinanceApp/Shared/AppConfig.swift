import Foundation

/// Build imkoniyatlarini bitta joydan boshqaradi.
///
/// `FREE_TIER` compiler flagi `project-free.yml` orqali yoqiladi (bepul Apple ID uchun):
/// App Group, CloudKit va Widget'siz — chunki bular pullik Developer hisobini talab qiladi.
/// Flag yoʻq boʻlsa (asosiy `project.yml`) — barcha imkoniyatlar yoqilgan.
enum AppConfig {
    #if FREE_TIER
    /// Bepul hisob: umumiy konteyner yoʻq (widget/intents alohida store'ni ulashmaydi).
    static let useAppGroup = false
    /// Bepul hisob: CloudKit sinxronizatsiya yoʻq.
    static let useCloudKit = false
    #else
    static let useAppGroup = true
    static let useCloudKit = true
    #endif
}
