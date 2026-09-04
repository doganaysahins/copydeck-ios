import Foundation

#if canImport(Combine)
import Combine
#endif

/// Paket kimligi.
public enum Copydeck {
    public static let version = "0.1.1"

    static var userAgent: String {
        #if os(iOS)
        let platform = "iOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "unknown"
        #endif

        return "Copydeck/\(version) (\(platform))"
    }
}

#if canImport(Combine)
/// SwiftUI'nin dinledigi nesne.
///
/// docs/IOS_SDK.md §9: `.localize` duz String dondugu icin yeni paket
/// geldiginde SwiftUI'nin yeniden degerlendirmesi gerekir. Paket her
/// degistiginde `version` artar; root view bunu observe eder.
@MainActor
public final class LocalizationObserver: ObservableObject {
    @Published public private(set) var version: Int = 0

    func invalidate() {
        version &+= 1
    }
}
#endif

/// Public cephe: configure, refresh, lookup.
///
/// Baslangic (docs/IOS_SDK.md §5):
///
///     configure -> disk cache -> bellek -> UI hemen render -> async refresh
///
/// Ag hicbir zaman ilk render'i bekletmez.
public final class Localization: @unchecked Sendable {
    public static let shared = Localization()

    private let lock = NSLock()
    private let store = LocalizationStore()

    private var client: LocalizationClient?
    private var cache: LocalizationCache?
    private var activeLocale: String?
    private var refreshTask: Task<Void, Never>?

    #if canImport(Combine)
    /// `@StateObject private var localization = Localization.shared.observer`
    @MainActor public private(set) lazy var observer = LocalizationObserver()
    #endif

    init() {}

    // MARK: - Kurulum

    /// Uygulama acilisinda bir kere cagrilir.
    ///
    /// Disk cache senkron yuklenir, boylece ilk render dogru metinle cikar.
    /// Ag istegi arka planda baslar ve donusu beklenmez.
    public func configure(
        projectKey: String,
        baseURL: URL,
        locale: String? = nil,
        transport: LocalizationTransport = URLSessionTransport()
    ) {
        let cache = LocalizationCache(projectKey: projectKey)
        let client = LocalizationClient(
            baseURL: baseURL,
            projectKey: projectKey,
            transport: transport
        )

        // Sabitlenmis locale yoksa diskteki son dili kullan.
        let startupLocale = locale ?? cache.lastLocale()

        lock.withLock {
            self.cache = cache
            self.client = client
            self.activeLocale = locale
        }

        // Locale sabitlenmemisse en son gosterilen dile don. Cihazin dilini
        // projenin dillerine eslemek manifest'i, yani agi gerektiriyor; bu
        // adim olmasa her acilista once fallback, ag donunce gercek metin
        // gorunur ve metinler ziplar.
        //
        // Diskteki dil eskimis olabilir (kullanici cihaz dilini degistirmis
        // olabilir). Sorun degil: manifest gelince dogrusuna gecilir. Bir
        // acilislik gecikme, her acilista ziplamaya yeglenir.
        if let startupLocale, let cached = cache.load(locale: startupLocale) {
            // notifyUI cagrilmiyor: store ilk render'dan once doluyor.
            // Burada observer'i tetiklemek gorunumu bos yere yeniden
            // olusturur — icerik zaten dogru.
            store.apply(cached)
        }

        refreshInBackground()
    }

    /// Uygulama one geldiginde cagrilir.
    public func refreshInBackground() {
        lock.withLock {
            refreshTask?.cancel()
            refreshTask = Task { [weak self] in
                _ = try? await self?.refresh()
            }
        }
    }

    // MARK: - Yenileme

    /// docs/IOS_SDK.md §6.
    ///
    /// Karsilastirma `!=` ile yapilir, `>` ile degil — yoksa rollback
    /// calismaz: sunucu v3'ten v1'e dondugunde cihaz v3'te kalirdi.
    @discardableResult
    public func refresh() async throws -> LocalizationBundle? {
        let (client, cache, pinnedLocale) = lock.withLock {
            (self.client, self.cache, self.activeLocale)
        }

        guard let client, let cache else {
            throw LocalizationError.notConfigured
        }

        let manifest = try await client.fetchManifest()

        let locale = pinnedLocale ?? LocaleResolver.deviceLocale(
            available: manifest.availableLocales,
            sourceLocale: manifest.sourceLocale
        )

        // Locale ilk kez belli olduysa once diskte var mi diye bak; boylece
        // ag yavassa bile eldeki metin gorunur.
        if pinnedLocale == nil {
            lock.withLock { activeLocale = locale }

            if store.isEmpty, let cached = cache.load(locale: locale),
               store.apply(cached) {
                notifyUI()
            }
        }

        if store.release == manifest.release, store.locale == locale {
            return nil
        }

        let bundle = try await client.fetchBundle(release: manifest.release, locale: locale)

        try BundleValidator.validate(
            bundle,
            expectedRelease: manifest.release,
            expectedLocale: locale
        )

        // Diske yazma basarisiz olursa bellegi de guncelleme: iki taraf
        // ayrisirsa bir sonraki acilista eski metne donulur.
        try cache.save(bundle)
        cache.saveLastLocale(bundle.locale)

        // UI yalnizca icerik gercekten degistiyse tazeleniyor.
        if store.apply(bundle) {
            notifyUI()
        }

        return bundle
    }

    // MARK: - Lookup

    public func string(forKey key: String, fallback: String? = nil) -> String {
        store.string(forKey: key, fallback: fallback)
    }

    // MARK: - Durum

    public var currentRelease: Int? { store.release }
    public var currentLocale: String? { store.locale }

    // MARK: - Ic

    private func notifyUI() {
        #if canImport(Combine)
        Task { @MainActor [weak self] in
            self?.observer.invalidate()
        }
        #endif
    }
}
