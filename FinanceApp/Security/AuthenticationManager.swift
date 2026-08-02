import Foundation
import LocalAuthentication
import Observation

/// Ilova qulfi boshqaruvi — Face ID / Touch ID / qurilma paroli (`LocalAuthentication`).
///
/// Nega alohida manager? Autentifikatsiya holati (qulflangan/ochiq) butun ilova
/// darajasida kerak va View'lardan ajratilgan boʻlishi lozim (SOLID, testlanuvchi).
@MainActor
@Observable
final class AuthenticationManager {

    enum State { case locked, authenticating, unlocked }

    private(set) var state: State = .unlocked
    var isLocked: Bool { state != .unlocked }

    func lock() { if state != .authenticating { state = .locked } }
    func unlock() { state = .unlocked }

    /// Qurilmadagi biometriya turini insonoʻqiydigan matn sifatida qaytaradi.
    func biometryLabel() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Parol"
        }
    }

    /// Foydalanuvchini autentifikatsiya qiladi. Muvaffaqiyatda `unlock`, aks holda `locked`.
    func authenticate(useBiometrics: Bool) async {
        guard state != .authenticating else { return }
        state = .authenticating

        let context = LAContext()
        context.localizedFallbackTitle = "Qurilma paroli"

        // Biometriya afzal koʻrilsa uni sinaymiz, mavjud boʻlmasa parolga tushamiz.
        var policy: LAPolicy = useBiometrics ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        var error: NSError?
        if !context.canEvaluatePolicy(policy, error: &error) {
            policy = .deviceOwnerAuthentication
            if !context.canEvaluatePolicy(policy, error: &error) {
                // Qurilmada hech qanday himoya yoʻq — ilovani ochib qoʻyamiz.
                state = .unlocked
                return
            }
        }

        let reason = "Ilovaga kirish uchun oʻzingizni tasdiqlang"
        let success: Bool = await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
        state = success ? .unlocked : .locked
    }
}
