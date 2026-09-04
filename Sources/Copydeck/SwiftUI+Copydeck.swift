#if canImport(SwiftUI)
import SwiftUI

/// Panelden yonetilen metin.
///
///     CopyText("paywall.title")
///     CopyText("paywall.title", fallback: "Unlock Premium")
///
/// Kendi kendini tazeler: yeni bir paket yayinlandiginda kok gorunumde
/// hicbir kurulum olmadan guncellenir.
///
/// `Text` gibi davranir; gorunum degistiricileri aynen calisir:
///
///     CopyText("paywall.title")
///         .font(.largeTitle.bold())
public struct CopyText: View {
    @ObservedObject private var observer = Localization.shared.observer

    private let key: String
    private let fallback: String?

    public init(_ key: String, fallback: String? = nil) {
        self.key = key
        self.fallback = fallback
    }

    public var body: some View {
        Text(Localization.shared.string(forKey: key, fallback: fallback))
    }
}

public extension View {
    /// Yeni paket geldiginde bu gorunumu ve altindaki her seyi tazeler.
    ///
    /// `CopyText` kullaniyorsan gerekmez — o kendi kendini tazeler. Bu
    /// modifier `.localize` ile duz `String` aldigin yerler icin: SwiftUI
    /// o String'in degistigini kendiliginden bilemez, cunku ortada
    /// gozlemleyecek bir nesne yok.
    ///
    /// Kok gorunume bir kere uygulanir:
    ///
    ///     WindowGroup {
    ///         PaywallView()
    ///             .copydeckUpdates()
    ///     }
    func copydeckUpdates() -> some View {
        modifier(CopydeckUpdates())
    }
}

private struct CopydeckUpdates: ViewModifier {
    @ObservedObject private var observer = Localization.shared.observer

    func body(content: Content) -> some View {
        // Kimlik degisince SwiftUI agaci yeniden degerlendiriyor. Kaba bir
        // arac, ama observer yalnizca icerik gercekten degistiginde artiyor
        // (bkz. LocalizationStore.apply), yani gereksiz yere tetiklenmiyor.
        content.id(observer.version)
    }
}
#endif
