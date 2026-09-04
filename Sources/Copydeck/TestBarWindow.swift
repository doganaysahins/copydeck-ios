#if canImport(UIKit) && canImport(SwiftUI) && !os(watchOS)
import SwiftUI
import UIKit

/// QA cubugunu uygulamanin ustunde, kendi penceresinde gosterir.
///
/// Sebebi: cubugu gostermek icin entegre eden gelistiriciden bir satir
/// istemek unutulur, ve unutuldugunda tam da en cok gereken yerde olmaz.
/// QA'ya ozel bir arac, kurulumunu QA'nin yapamayacagi bir yere birakmak
/// dogru degil.
///
/// Yalnizca Test Mode acikken pencere yaratiliyor; oturum bitince
/// kaldiriliyor. Uretimde hicbir zaman gorunmuyor, cunku acilmasi icin
/// birinin o uygulamaya oturum kodu girmis olmasi gerekiyor.
///
/// Dokunmalar alttaki uygulamaya geciyor: pencere yalnizca cubugun kendi
/// alanini yakaliyor, geri kalan her yerde seffaf. QA uygulamada normal
/// sekilde gezinebilmeli.
@MainActor
final class TestBarWindow {
    static let shared = TestBarWindow()

    private var window: UIWindow?

    private init() {}

    /// Idempotent: her sorgu turunda cagrilabilir.
    ///
    /// Boyle olmasi gerekiyor cunku oturum baslarken uygulama henuz one
    /// gelmemis olabilir ve o anda tutunacak bir sahne bulunamaz.
    func present() {
        guard window == nil else { return }

        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let host = UIHostingController(
            rootView: VStack(spacing: 0) {
                Spacer(minLength: 0)
                CopydeckTestBar()
            }
            .ignoresSafeArea(.keyboard)
        )

        host.view.backgroundColor = .clear

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = host
        window.isHidden = false

        self.window = window
    }

    func dismiss() {
        window?.isHidden = true
        window = nil
    }
}

/// Yalnizca icindeki gorunumlerin uzerindeki dokunmalari yakalar.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }

        // Kok gorunumun kendisine denk geldiyse bos alandayiz: dokunma
        // alttaki uygulamaya gitmeli.
        return hit == rootViewController?.view ? nil : hit
    }
}
#endif
