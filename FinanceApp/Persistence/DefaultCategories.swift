import Foundation

/// Spec'dagi default kategoriyalar roʻyxati.
/// Ilova birinchi ochilganda bir marta bazaga yoziladi (seeding).
enum DefaultCategories {

    /// (nom, SF Symbol, hex rang)
    static let income: [(String, String, String)] = [
        ("Salary", "dollarsign.circle.fill", "#34C759"),
        ("Bonus", "gift.fill", "#30D158"),
        ("Freelance", "laptopcomputer", "#00C7BE"),
        ("Investment", "chart.line.uptrend.xyaxis", "#32ADE6"),
        ("Cashback", "arrow.uturn.backward.circle.fill", "#5AC8FA"),
        ("Gift", "gift.circle.fill", "#AF52DE"),
        ("Other", "ellipsis.circle.fill", "#8E8E93")
    ]

    static let expense: [(String, String, String)] = [
        ("Food", "fork.knife", "#FF9500"),
        ("Cafe", "cup.and.saucer.fill", "#FF9F0A"),
        ("Drinks", "drop.fill", "#00C7BE"),
        ("Ichimliklar", "drop.fill", "#00C7BE"),
        ("Restaurant", "wineglass.fill", "#FF375F"),
        ("Transport", "bus.fill", "#0A84FF"),
        ("Taxi", "car.fill", "#FFD60A"),
        ("Fuel", "fuelpump.fill", "#FF453A"),
        ("Shopping", "bag.fill", "#FF2D55"),
        ("Clothing", "tshirt.fill", "#BF5AF2"),
        ("Electronics", "tv.fill", "#5856D6"),
        ("Entertainment", "gamecontroller.fill", "#AF52DE"),
        ("Games", "dice.fill", "#7D7AFF"),
        ("Education", "graduationcap.fill", "#32ADE6"),
        ("Health", "heart.fill", "#FF3B30"),
        ("Pharmacy", "cross.case.fill", "#FF6482"),
        ("Gym", "figure.run", "#30D158"),
        ("Travel", "airplane", "#64D2FF"),
        ("Hotel", "bed.double.fill", "#5E5CE6"),
        ("Family", "person.2.fill", "#FF9500"),
        ("Kids", "figure.and.child.holdinghands", "#FFD60A"),
        ("Pets", "pawprint.fill", "#A2845E"),
        ("Utilities", "bolt.fill", "#FFCC00"),
        ("Internet", "wifi", "#0A84FF"),
        ("Mobile", "iphone", "#30B0C7"),
        ("Rent", "house.fill", "#FF9F0A"),
        ("Insurance", "shield.lefthalf.filled", "#5856D6"),
        ("Taxes", "building.columns.fill", "#8E8E93"),
        ("Gifts", "gift.fill", "#FF2D55"),
        ("Charity", "hands.and.sparkles.fill", "#34C759"),
        ("Other", "ellipsis.circle.fill", "#8E8E93")
    ]
}
