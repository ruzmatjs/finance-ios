import SwiftUI

/// Animatsion onboarding — spec talabi.
/// 3 sahifa: kirish, imkoniyatlar, boshlash.
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var page = 0

    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("wallet.pass.fill",
         "Pullaringizni nazorat qiling",
         "Daromad va xarajatlaringizni bir joyda kuzating.",
         Color(hex: "#5E5CE6")),
        ("chart.pie.fill",
         "Aqlli hisobotlar",
         "Chiroyli grafiklar bilan sarf-xarajat tahlili.",
         Color(hex: "#0A84FF")),
        ("target",
         "Maqsadlaringizga yeting",
         "Byudjet tuzing, jamgʻarma maqsadlarini belgilang.",
         Color(hex: "#34C759"))
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? "Boshlaymiz" : "Davom etish") {
                withAnimation(.spring) {
                    if page < pages.count - 1 { page += 1 }
                    else { settings.hasCompletedOnboarding = true }
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(pages[page].color.gradient, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.lg)
            .animation(.easeInOut, value: page)
        }
    }

    private func pageView(_ p: (icon: String, title: String, subtitle: String, color: Color)) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: p.icon)
                .font(.system(size: 96, weight: .light))
                .foregroundStyle(p.color.gradient)
                .symbolEffect(.bounce, value: page)
            Text(p.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(p.subtitle)
                .font(.title3)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer(); Spacer()
        }
        .padding()
    }
}
