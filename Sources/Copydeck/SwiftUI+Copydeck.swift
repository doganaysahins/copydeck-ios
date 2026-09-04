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

/// Panelden yonetilen metni duz `String` olarak verir.
///
///     struct PaywallView: View {
///         @Localized("paywall.cta.start_trial") var cta
///
///         var body: some View {
///             Button(cta) { startTrial() }
///         }
///     }
///
/// `Text` tipinin kendisi gerektiginde bunu kullan: `Button` basligi,
/// `Label`, `Text + Text` birlestirmesi, `accessibilityLabel`.
///
/// `DynamicProperty` oldugu icin SwiftUI bunu iceren gorunumun bagimliligi
/// sayiyor: yeni paket geldiginde **yalnizca o gorunum** yeniden
/// degerlendiriliyor. Kimlik degismedigi icin `@State`, scroll pozisyonu ve
/// navigasyon oldugu gibi kaliyor.
@propertyWrapper
public struct Localized: DynamicProperty {
    @ObservedObject private var observer = Localization.shared.observer

    private let key: String
    private let fallback: String?

    public init(_ key: String, fallback: String? = nil) {
        self.key = key
        self.fallback = fallback
    }

    public var wrappedValue: String {
        Localization.shared.string(forKey: key, fallback: fallback)
    }
}

public extension View {
    /// Yeni paket geldiginde bu gorunumu ve **altindaki her seyi** tazeler.
    ///
    /// Son care. Once `CopyText` ve `@Localized`'i dusun; ikisi de yalnizca
    /// ilgili gorunumu tazeliyor.
    ///
    /// Bunun bedeli agir: altta `.id()` var, yani SwiftUI alt agacin
    /// kimligini degistiriyor ve onu yok edip yeniden kuruyor. Alt agactaki
    /// `@State` sifirlanir, `@StateObject`'ler yeniden yaratilir, scroll
    /// pozisyonu basa doner, navigasyon sifirlanabilir. Kullanicinin
    /// doldurdugu bir form publish aninda bosalir.
    ///
    /// Kullanacaksan **kokte degil**, etkilenen metinleri iceren en kucuk
    /// alt agacta kullan.
    func copydeckUpdates() -> some View {
        modifier(CopydeckUpdates())
    }
}

private struct CopydeckUpdates: ViewModifier {
    @ObservedObject private var observer = Localization.shared.observer

    func body(content: Content) -> some View {
        content.id(observer.version)
    }
}
#endif
