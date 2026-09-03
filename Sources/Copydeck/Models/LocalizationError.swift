import Foundation

/// Bu hatalarin hicbiri uygulamayi durdurmaz. Hepsi "yeni paket alinamadi"
/// anlamina gelir ve sonuc her zaman aynidir: eldeki gecerli cache korunur.
public enum LocalizationError: Error, Equatable {
    case notConfigured
    case httpStatus(Int)
    case decodingFailed
    case unsupportedSchemaVersion(Int)
    case localeMismatch(expected: String, received: String)
    case releaseMismatch(expected: Int, received: Int)
    case emptyBundle
    case emptyValue(key: String)
}
