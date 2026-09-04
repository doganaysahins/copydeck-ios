import Foundation

/// Bellekteki aktif string'ler.
///
/// Lookup her `Text` render'inda cagrilir; hizli ve senkron olmali, ayrica
/// herhangi bir thread'den guvenli olmali. Bu yuzden basit bir kilit
/// kullaniliyor — actor olsaydi lookup async olurdu ve SwiftUI govdesinden
/// cagrilamazdi.
final class LocalizationStore: @unchecked Sendable {
    private let lock = NSLock()
    private var strings: [String: String] = [:]
    private var currentRelease: Int?
    private var currentLocale: String?

    var release: Int? {
        lock.lock(); defer { lock.unlock() }
        return currentRelease
    }

    var locale: String? {
        lock.lock(); defer { lock.unlock() }
        return currentLocale
    }

    var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return strings.isEmpty
    }

    /// Icerik gercekten degistiyse `true` doner.
    ///
    /// Cagiran taraf UI'yi yalnizca o zaman tazeler: ayni paket tekrar
    /// uygulandiginda gorunumu yeniden olusturmak bos yere goz kirpmasina
    /// yol acar.
    @discardableResult
    func apply(_ bundle: LocalizationBundle) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let changed = currentRelease != bundle.release
            || currentLocale != bundle.locale
            || strings != bundle.strings

        strings = bundle.strings
        currentRelease = bundle.release
        currentLocale = bundle.locale

        return changed
    }

    func reset() {
        lock.lock()
        strings = [:]
        currentRelease = nil
        currentLocale = nil
        lock.unlock()
    }

    /// docs/IOS_SDK.md §7 — lookup sirasi:
    ///
    ///     bellekteki deger -> fallback -> key
    ///
    /// Asla varsayilan olarak bos string donmez.
    func string(forKey key: String, fallback: String?) -> String {
        lock.lock()
        let value = strings[key]
        lock.unlock()

        if let value, !value.isEmpty { return value }
        if let fallback, !fallback.isEmpty { return fallback }

        return key
    }
}
