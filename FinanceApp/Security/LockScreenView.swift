import SwiftUI

/// Qulf ekrani — ilova qulflanganda koʻrinadi. Premium gradient + biometriya tugmasi.
struct LockScreenView: View {
    @Environment(AuthenticationManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1C1C2E"), Color(hex: "#0A0A14")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                Image(systemName: auth.state == .authenticating ? "faceid" : "lock.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: auth.state == .authenticating)

                Text("Finance qulflangan")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Davom etish uchun tasdiqlang")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Button {
                    Task { await authenticate() }
                } label: {
                    Label("\(auth.biometryLabel()) bilan ochish", systemImage: "faceid")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.15), in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.xxl)
                .disabled(auth.state == .authenticating)
            }
        }
        // Ekran paydo boʻlishi bilan avtomatik soʻraladi.
        .task { await authenticate() }
    }

    private func authenticate() async {
        await auth.authenticate(useBiometrics: settings.biometricsEnabled)
    }
}
