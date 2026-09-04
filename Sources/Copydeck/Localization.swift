import Foundation

#if canImport(Combine)
import Combine
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Paket kimligi.
public enum Copydeck {
    public static let version = "0.7.0"

    /// Konsola tani bilgisi yazar.
    ///
    /// Varsayilan kapali: bir SDK, entegre edildigi uygulamanin loguna
    /// davetsiz yazmaz. Bir sey beklendigi gibi calismadiginda aciliyor ve
    /// hangi adimda ne oldugu gorunur oluyor - "neden degismedi" sorusunu
    /// tahminle degil kayitla cevapliyoruz.
    ///
    ///     Copydeck.isLoggingEnabled = true
    public static var isLoggingEnabled = false

    static func log(_ message: @autoclosure () -> String) {
        guard isLoggingEnabled else { return }

        print("[Copydeck] \(message())")
    }

    /// Varsayilan sunucu.
    ///
    /// Adres cagiran taraftan istenmiyor: bu bizim altyapi detayimiz, entegre
    /// eden gelistiricinin karari degil.
    ///
    /// DIKKAT — burasi musterinin binary'sine gomuluyor. Sunucuyu tasimak
    /// gerektiginde her musterinin yeni surum cikarmasi gerekmesin diye
    /// buranin bizim yonlendirebildigimiz bir alan adi olmasi sart. Su an
    /// dogrudan dagitim adresi; ilk dis entegrasyondan once degismeli.
    public static let defaultBaseURL = URL(string: "https://localize-app-theta.vercel.app")!

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
/// `.localize` duz String dondugu icin yeni paket geldiginde SwiftUI'nin
/// yeniden degerlendirmesi gerekir. Paket her degistiginde `version` artar.
///
/// Cogu uygulamanin buna dogrudan dokunmasi gerekmez: `CopyText` ve
/// `.copydeckUpdates()` bunu kendi icinde yapar.
public final class LocalizationObserver: ObservableObject {
    @Published public private(set) var version: Int = 0

    func invalidate() {
        // SwiftUI @Published degisikliklerini ana thread'de bekliyor.
        if Thread.isMainThread {
            version &+= 1
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.version &+= 1
            }
        }
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
    private let reporter = PreviewReporter()

    private var client: LocalizationClient?
    private var cache: LocalizationCache?
    private var activeLocale: String?
    private var refreshTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewRevision: Int?
    private var testMode: TestModeState = .off
    private var foregroundObserver: NSObjectProtocol?

    /// Yayinlanmis icerigi izleyen gelistirme sorgusu.
    private static let pollInterval: UInt64 = 2_000_000_000

    /// Test Mode sorgusu. docs/IMPLEMENTATION_PLAN.md Faz 25: panelden dil
    /// degistirildiginde acik ekran yaklasik bir saniye icinde donmeli.
    private static let previewInterval: UInt64 = 1_000_000_000

    /// Test Mode acilmadan once gorunen yayinlanmis paket.
    ///
    /// Oturum bittiginde geri yuklemek icin saklaniyor: taslak metin
    /// cihazda kalmamali.
    private var publishedBundle: LocalizationBundle?

    #if canImport(Combine)
    public let observer = LocalizationObserver()
    #endif

    init() {}

    // MARK: - Kurulum

    /// Uygulama acilisinda bir kere cagrilir.
    ///
    /// Disk cache senkron yuklenir, boylece ilk render dogru metinle cikar.
    /// Ag istegi arka planda baslar ve donusu beklenmez.
    /// - Parameters:
    ///   - projectKey: Panelden alinan yayinlanabilir anahtar (`pk_...`).
    ///   - baseURL: Kendi sunucunu kullaniyorsan. Normalde bos birakilir.
    ///   - locale: Dili sabitlemek istersen. Bos birakilirsa cihazin dili
    ///     projenin dilleriyle eslestirilir.
    ///   - livePolling: Gelistirme sirasinda panelde yayinladigin
    ///     degisikligi uygulamayi arka plana atmadan gormek icin. Iki
    ///     saniyede bir sunucuya sorar.
    ///
    ///     Yalnizca **yayinlanmis** icerigi gosterir. Panelden baslatilan,
    ///     taslak metinleri gosteren Test Mode ayri bir is:
    ///     `startTestMode(token:)`.
    ///
    ///     Uretim derlemesinde acik birakma.
    public func configure(
        projectKey: String,
        baseURL: URL? = nil,
        locale: String? = nil,
        livePolling: Bool = false,
        transport: LocalizationTransport = URLSessionTransport()
    ) {
        let baseURL = baseURL ?? Copydeck.defaultBaseURL
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
            Copydeck.log(
                "acilis: diskten \(cached.locale) v\(cached.release), \(cached.strings.count) key"
            )
            lock.withLock { publishedBundle = cached }
            // notifyUI cagrilmiyor: store ilk render'dan once doluyor.
            // Burada observer'i tetiklemek gorunumu bos yere yeniden
            // olusturur — icerik zaten dogru.
            store.apply(cached)
        }

        #if canImport(UIKit)
        // Uygulama one geldiginde yeni release'i SDK kendisi ariyor.
        // Bunu cagiran tarafa biraktigimizda her entegrasyonun ayni sey
        // icin ayni kodu yazmasi gerekiyordu.
        registerForegroundRefresh()
        #endif

        if startupLocale == nil {
            Copydeck.log("acilis: diskte kayitli dil yok, ilk render fallback ile cikacak")
        } else if cache.load(locale: startupLocale!) == nil {
            Copydeck.log("acilis: \(startupLocale!) icin disk cache yok")
        }

        refreshInBackground()

        if livePolling {
            startPolling()
        }
    }

    // MARK: - Test modu

    private func startPolling() {
        let task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Localization.pollInterval)
                guard !Task.isCancelled else { return }

                // Hata yutuluyor: ag kesilirse polling durmamali, bir sonraki
                // turda yeniden denenir.
                try? await self?.refresh()
            }
        }

        lock.withLock {
            pollTask?.cancel()
            pollTask = task
        }
    }

    /// Gelistirme sorgusunu kapatir. Eldeki metinler oldugu gibi kalir.
    public func stopLivePolling() {
        lock.withLock {
            pollTask?.cancel()
            pollTask = nil
        }
    }

    // MARK: - QA takibi

    /// `CopyText` ekrana geldiginde bildiriyor.
    ///
    /// Test Mode kapaliyken de toplaniyor ama hicbir yere gonderilmiyor:
    /// oturum acildiginda QA'nin o an baktigi ekran zaten biliniyor olsun.
    func noteAppeared(_ key: String) {
        reporter.appeared(key)
    }

    func noteDisappeared(_ key: String) {
        reporter.disappeared(key)
    }

    // MARK: - Test Mode

    /// Panelden baslatilan Test Mode oturumuna baglanir.
    ///
    /// Token panelde QR olarak gorunur. Oturum boyunca cihaz **yayinlanmamis**
    /// taslak metinleri gosterir ve panelde yapilan her degisiklik yaklasik
    /// bir saniye icinde ekrana duser.
    ///
    /// Taslak metinler diske yazilmaz. Yazilsaydi oturum bittikten sonra da
    /// cihazda kalirlardi — yani QA seansi biter, yayinlanmamis metin
    /// kullanicinin karsisina cikardi.
    /// Test Mode'un o anki hali.
    ///
    /// Uygulama bunu okuyup gostermeli, kendi tuttugu bir bayragi degil:
    /// oturum panelden bitirilebilir ya da suresi dolabilir ve o zaman
    /// uygulamanin bayragi yalan soylerdi.
    ///
    /// Deger degistiginde gorunum tazeleniyor, yani SwiftUI'de dogrudan
    /// okunabilir.
    public var testModeState: TestModeState {
        lock.withLock { testMode }
    }

    public var isTestModeActive: Bool {
        testModeState != .off
    }

    public func startTestMode(token: String) {
        // Sayac gorevden once sifirlaniyor: gorev hemen calismaya basliyor ve
        // ilk turu bittikten sonra sifirlarsak o turun sonucu unutulur.
        reporter.reset()

        lock.withLock {
            previewRevision = nil
            testMode = .connecting
        }

        Copydeck.log("test: oturuma baglaniliyor")
        notifyUI()

        let task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                do {
                    try await self.pollPreview(token: token)
                } catch LocalizationError.httpStatus(404) {
                    // Oturum panelden bitirildi ya da suresi doldu.
                    // Yayinlanmis hale don ve dongusu kapat.
                    self.leaveTestMode()
                    return
                } catch {
                    // Gecici ag hatasi: bir sonraki turda yeniden denenir.
                }

                try? await Task.sleep(nanoseconds: Localization.previewInterval)
            }
        }

        lock.withLock {
            previewTask?.cancel()
            previewTask = task
        }
    }

    /// Test Mode'u kapatir ve cihazi yayinlanmis hale dondurur.
    public func stopTestMode() {
        leaveTestMode()
    }

    // Testler bu ikisini dogrudan cagiriyor: aksi halde her testin bir
    // saniyelik sorgu turunu beklemesi gerekirdi.
    func pollPreview(token: String) async throws {
        let client = lock.withLock { self.client }

        guard let client else { throw LocalizationError.notConfigured }

        let report = reporter.pendingReport()
        let state = try await client.fetchPreview(token: token, report: report)

        // Yalnizca istek basariyla dondugunde isaretleniyor: bir ag hatasi
        // kapsam bilgisini sessizce dusurmemeli.
        if let report { reporter.commit(report) }

        // Dil degistiyse bu dilde hicbir sey gorulmemis sayilir.
        reporter.localeChanged(to: state.locale)

        // Sunucu revision'i icerikten turetiyor: ayni degerse ekranda
        // degisecek bir sey yok.
        let unchanged = lock.withLock { previewRevision == state.revision }

        guard !unchanged else {
            Copydeck.log("test: degisiklik yok (rev \(state.revision))")
            return
        }

        Copydeck.log(
            "test: \(state.locale) rev \(state.revision), \(state.strings.count) key uygulaniyor"
        )

        let becameLive = lock.withLock { () -> Bool in
            previewRevision = state.revision

            let next = TestModeState.live(locale: state.locale)
            let changed = testMode != next
            testMode = next

            return changed
        }

        // release 0: bu icerik yayinlanmadi, bir surum numarasi yok.
        let draft = LocalizationBundle(
            schemaVersion: LocalizationSchema.supportedVersion,
            release: 0,
            locale: state.locale,
            strings: state.strings
        )

        // Yalnizca bellege. cache.save cagrilmiyor, kasitli.
        if store.apply(draft) || becameLive {
            notifyUI()
        }
    }

    func leaveTestMode() {
        Copydeck.log("test: oturum kapandi, yayinlanmis hale donuluyor")

        let published = lock.withLock { () -> LocalizationBundle? in
            previewTask?.cancel()
            previewTask = nil
            previewRevision = nil
            testMode = .off

            return publishedBundle
        }

        notifyUI()

        if let published, store.apply(published) {
            notifyUI()
        }

        // Elde yayinlanmis paket yoksa ya da eskiyse sunucudan al.
        refreshInBackground()
    }

    #if canImport(UIKit)
    private func registerForegroundRefresh() {
        let alreadyRegistered = lock.withLock { foregroundObserver != nil }
        guard !alreadyRegistered else { return }

        let token = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshInBackground()
        }

        lock.withLock { foregroundObserver = token }
    }
    #endif

    /// Ilk render'i kisa bir sure ag icin bekletir.
    ///
    /// Cozdugu sorun sudur: cache'te release 4, sunucuda 5 varsa uygulama
    /// once 4'u cizer, ~200ms sonra 5 gelir ve metin gozun onunde degisir.
    /// Bu her publish'ten sonraki her acilista olur.
    ///
    /// Normal baglantida manifest 100-150ms'de donuyor, yani bu pencereyle
    /// ziplama hic gorunmez. Ag yoksa ya da yavassa sure dolar ve elde ne
    /// varsa onunla devam edilir — uygulama takilmaz.
    ///
    ///     await Localization.shared.warmUp()
    ///
    /// `timeout` 0 verilirse hicbir sey beklenmez; bu, bu fonksiyon hic
    /// cagrilmamis gibi davranmaktir.
    ///
    /// Hata firlatmaz: acilisi bir ag hatasina baglamanin anlami yok.
    public func warmUp(timeout: TimeInterval = 0.3) async {
        guard timeout > 0 else { return }

        // Yeni bir istek baslatmiyoruz: configure zaten birini baslatti.
        // Ikincisi ayni manifest'i bosuna cekerdi.
        let pending = lock.withLock { refreshTask }

        guard let pending else { return }

        let gate = WarmUpGate()

        let waiter = Task {
            await pending.value
            gate.finish()
        }

        let timer = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            gate.finish()
        }

        await gate.wait()

        timer.cancel()

        // waiter bilerek iptal edilmiyor: yenileme arka planda tamamlanip
        // metni guncellemeli. Yalnizca beklemekten vazgectik.
        _ = waiter

        Copydeck.log("acilis: bekleme penceresi kapandi")
    }

    /// Elle yenileme. Normalde gerekmez — SDK uygulama one geldiginde
    /// kendisi yeniliyor.
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
        // Test Mode acikken yayinlanmis paket uygulanmaz. Cihazda taslak
        // gorunuyor; uygulama one geldiginde tetiklenen yenileme onu silip
        // atardi ve QA baktigi metni kaybederdi.
        if lock.withLock({ previewTask != nil }) {
            Copydeck.log("yenileme atlandi: Test Mode acik")
            return nil
        }

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
            Copydeck.log("yenileme gereksiz: zaten \(locale) v\(manifest.release)")
            return nil
        }

        Copydeck.log(
            "yenileme: \(store.locale ?? "-") v\(store.release.map(String.init) ?? "-")"
                + " -> \(locale) v\(manifest.release)"
        )

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

        lock.withLock { publishedBundle = bundle }

        // UI yalnizca icerik gercekten degistiyse tazeleniyor.
        if store.apply(bundle) {
            notifyUI()
        }

        return bundle
    }

    // MARK: - Lookup

    public func string(forKey key: String, fallback: String? = nil) -> String {
        if let value = store.value(forKey: key) { return value }

        // Pakette yok. Bunu not aliyoruz cunku panel baska turlu
        // ogrenemiyor: kodda hangi key'lerin gectigini gormuyor.
        //
        // Yalnizca eksik durumda kilit aliniyor; bulunan degerlerde
        // -- yani neredeyse her cagride -- fazladan is yok.
        reporter.noteMissing(key)

        if let fallback, !fallback.isEmpty { return fallback }

        return key
    }

    // MARK: - Durum

    public var currentRelease: Int? { store.release }
    public var currentLocale: String? { store.locale }

    // MARK: - Ic

    private func notifyUI() {
        #if canImport(Combine)
        observer.invalidate()
        #endif
    }
}
