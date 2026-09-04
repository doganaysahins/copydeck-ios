import Foundation

/// Test Mode oturumunun o anki hali.
///
/// Yayinlanmis bir paket degil: bu icerik hic yayinlanmadi, dolayisiyla bir
/// release numarasi da yok. "Degisti mi" sorusunu `revision` cevapliyor ve
/// sunucu onu icerikten turetiyor — yani panelde bir metin degistiginde ya
/// da dil secildiginde deger degisiyor.
public struct PreviewState: Codable, Equatable, Sendable {
    public let locale: String
    public let sourceLocale: String
    public let availableLocales: [String]
    public let revision: Int
    public let strings: [String: String]

    public init(
        locale: String,
        sourceLocale: String,
        availableLocales: [String],
        revision: Int,
        strings: [String: String]
    ) {
        self.locale = locale
        self.sourceLocale = sourceLocale
        self.availableLocales = availableLocales
        self.revision = revision
        self.strings = strings
    }
}

/// Test Mode'un cihazdaki hali.
///
/// Uygulama bunu gosterir, kendi tuttugu bir bayragi degil: oturum panelden
/// bitirilebilir ya da suresi dolabilir, o zaman uygulamanin bayragi yalan
/// soylerdi.
public enum TestModeState: Equatable, Sendable {
    /// Baglanti yok; cihaz yayinlanmis metinleri gosteriyor.
    case off

    /// Kod girildi ama sunucudan henuz cevap gelmedi. Gecersiz bir kod
    /// girildiginde de burada kalinir.
    case connecting

    /// Baglanti kuruldu; ekranda taslak metinler var.
    case live(locale: String)
}
