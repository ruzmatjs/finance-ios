import Foundation
import SwiftData

/// SwiftData ModelContainer'ni sozlaydi va boshlangʻich maʼlumotlarni ekadi.
///
/// CloudKit'ga tayyorgarlik: kelajakda `ModelConfiguration`'ga
/// `cloudKitDatabase: .automatic` qoʻshilsa, sync avtomatik yoqiladi.
enum PersistenceController {

    static let schema = Schema([
        Account.self,
        Category.self,
        Transaction.self,
        Tag.self,
        Budget.self,
        Goal.self,
        RecurringTransaction.self,
        Debt.self
    ])

    /// iCloud container identifikatori (entitlements bilan mos boʻlishi shart).
    static let cloudContainerID = "iCloud.com.ruzmat.finance"

    /// iCloud sync yoqilganmi? App Group defaults'da saqlanadi (default: yoqilgan).
    /// Oʻzgartirilsa ilova qayta ishga tushirilganda kuchga kiradi.
    static var isCloudSyncEnabled: Bool {
        AppGroup.defaults.object(forKey: "settings.iCloudSync") as? Bool ?? true
    }

    /// Yagona umumiy konteyner — ilova, Widget va Intents jarayonlari shundan foydalanadi.
    /// App Group konteynerida joylashadi (barcha jarayonlar bitta bazani koʻradi) va
    /// yoqilgan boʻlsa CloudKit orqali qurilmalararo sinxronlanadi.
    static let shared: ModelContainer = {
        let cloudDatabase: ModelConfiguration.CloudKitDatabase =
            (AppConfig.useCloudKit && isCloudSyncEnabled) ? .private(cloudContainerID) : .none

        let config: ModelConfiguration
        if AppConfig.useAppGroup {
            config = ModelConfiguration(schema: schema,
                                        groupContainer: .identifier(AppGroup.identifier),
                                        cloudKitDatabase: cloudDatabase)
        } else {
            // Bepul hisob: App Group yoʻq — oddiy lokal store.
            config = ModelConfiguration(schema: schema, cloudKitDatabase: cloudDatabase)
        }
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // Seeding'ni alohida kontekstda bajaramiz (main-actor'ga bogʻlanmaslik uchun).
            seedIfNeeded(ModelContext(container))
            return container
        } catch {
            fatalError("Umumiy ModelContainer yaratilmadi: \(error)")
        }
    }()

    /// Preview/test uchun xotira konteyneri.
    static func makeContainer(inMemory: Bool = true) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            seedIfNeeded(ModelContext(container))
            return container
        } catch {
            fatalError("ModelContainer yaratilmadi: \(error)")
        }
    }

    /// Preview va testlar uchun — xotirada, namuna maʼlumot bilan.
    @MainActor
    static let preview: ModelContainer = {
        let container = makeContainer(inMemory: true)
        SampleData.populate(container.mainContext)
        return container
    }()

    /// Baza boʻsh boʻlsa default kategoriya va hisoblarni ekadi.
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existing == 0 else { return }

        for (i, item) in DefaultCategories.income.enumerated() {
            context.insert(Category(name: item.0, kind: .income, symbol: item.1,
                                    colorHex: item.2, isDefault: true, sortIndex: i))
        }
        for (i, item) in DefaultCategories.expense.enumerated() {
            context.insert(Category(name: item.0, kind: .expense, symbol: item.1,
                                    colorHex: item.2, isDefault: true, sortIndex: i))
        }

        // Boshlangʻich hisob
        let accounts = (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0
        if accounts == 0 {
            context.insert(Account(name: "Naqd", type: .cash, openingBalance: 0,
                                   colorHex: "#34C759", sortIndex: 0))
            context.insert(Account(name: "Bank karta", type: .bankCard, openingBalance: 0,
                                   colorHex: "#0A84FF", sortIndex: 1))
        }
        try? context.save()
    }
}
