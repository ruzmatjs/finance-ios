import SwiftUI

/// Bitta tranzaksiya qatori — roʻyxatlarda qayta ishlatiladi.
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            CategoryIconView(
                symbol: transaction.category?.symbol ?? transaction.type.systemImage,
                color: transaction.category?.color ?? Theme.Colors.secondaryText
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.merchant.isEmpty
                         ? (transaction.category?.name ?? transaction.type.title)
                         : transaction.merchant)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .lineLimit(1)
                    if transaction.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.warning)
                    }
                    if transaction.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if transaction.hasReceipt {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
                HStack(spacing: 4) {
                    if let account = transaction.account {
                        Text(account.name)
                        Text("·")
                    }
                    Text(transaction.date.relativeShort)
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.xs)

            AmountText(
                amount: transaction.amount,
                currencyCode: transaction.currencyCode,
                type: transaction.type,
                font: .callout.weight(.semibold)
            )
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}
