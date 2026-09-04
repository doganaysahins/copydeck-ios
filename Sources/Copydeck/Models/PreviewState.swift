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
