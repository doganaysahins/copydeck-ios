import Foundation

/// Sunucunun urettigi degismez paket.
///
/// Bkz. docs/TECHNICAL_DESIGN.md §10. `schemaVersion` ilk surumden itibaren
/// bulunur; MVP'de deger yalnizca String'dir.
public struct LocalizationBundle: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let release: Int
    public let locale: String
    public let strings: [String: String]

    public init(schemaVersion: Int, release: Int, locale: String, strings: [String: String]) {
        self.schemaVersion = schemaVersion
        self.release = release
        self.locale = locale
        self.strings = strings
    }
}

/// SDK once bunu kontrol eder; degisiklik yoksa paket indirilmez.
public struct LocalizationManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let release: Int
    public let sourceLocale: String
    public let availableLocales: [String]

    public init(schemaVersion: Int, release: Int, sourceLocale: String, availableLocales: [String]) {
        self.schemaVersion = schemaVersion
        self.release = release
        self.sourceLocale = sourceLocale
        self.availableLocales = availableLocales
    }
}

/// SDK'nin destekledigi sema surumu. Sunucu daha yenisini gonderirse paket
/// reddedilir ve eldeki gecerli cache korunur.
public enum LocalizationSchema {
    public static let supportedVersion = 1
}
