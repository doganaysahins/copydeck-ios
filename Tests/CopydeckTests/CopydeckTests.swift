import XCTest
@testable import Copydeck

/// docs/IOS_SDK.md §12'deki ilk test listesi.

// MARK: - Yardimcilar

/// Sahte tasima: her URL icin ne donecegini test belirler.
final class FakeTransport: LocalizationTransport, @unchecked Sendable {
    struct Reply {
        let status: Int
        let body: Data
    }

    private let lock = NSLock()
    private var replies: [String: Reply] = [:]
    private(set) var requested: [String] = []

    func stub(path: String, status: Int = 200, json: String) {
        lock.withLock { replies[path] = Reply(status: status, body: Data(json.utf8)) }
    }

    func stub(path: String, status: Int) {
        lock.withLock { replies[path] = Reply(status: status, body: Data("{}".utf8)) }
    }

    func get(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        let reply = lock.withLock { () -> Reply? in
            requested.append(url.path)
            return replies[url.path]
        }

        guard let reply else {
            let response = HTTPURLResponse(
                url: url, statusCode: 404, httpVersion: nil, headerFields: nil
            )!
            return (Data(), response)
        }

        let response = HTTPURLResponse(
            url: url, statusCode: reply.status, httpVersion: nil, headerFields: nil
        )!

        return (reply.body, response)
    }
}

private func manifestJSON(release: Int, locales: [String] = ["en", "tr"]) -> String {
    let list = locales.map { "\"\($0)\"" }.joined(separator: ",")
    return """
    {"schemaVersion":1,"release":\(release),"sourceLocale":"en","availableLocales":[\(list)]}
    """
}

private func bundleJSON(release: Int, locale: String, cta: String) -> String {
    """
    {"schemaVersion":1,"release":\(release),"locale":"\(locale)","strings":{"paywall.cta.start_trial":"\(cta)"}}
    """
}

private func temporaryRoot() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("copydeck-tests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

// MARK: - Lookup

final class LookupTests: XCTestCase {
    private func store(with strings: [String: String]) -> LocalizationStore {
        let store = LocalizationStore()
        store.apply(
            LocalizationBundle(schemaVersion: 1, release: 1, locale: "tr", strings: strings)
        )
        return store
    }

    func testKeyExists() {
        let store = store(with: ["paywall.title": "Premium'un Kilidini Aç"])

        XCTAssertEqual(
            store.string(forKey: "paywall.title", fallback: nil),
            "Premium'un Kilidini Aç"
        )
    }

    func testKeyMissingWithoutFallbackReturnsKey() {
        let store = store(with: [:])

        XCTAssertEqual(store.string(forKey: "paywall.title", fallback: nil), "paywall.title")
    }

    func testKeyMissingWithFallbackReturnsFallback() {
        let store = store(with: [:])

        XCTAssertEqual(
            store.string(forKey: "paywall.title", fallback: "Unlock Premium"),
            "Unlock Premium"
        )
    }

    /// Bos string asla gecerli bir sonuc degildir.
    func testNeverReturnsEmptyString() {
        let store = store(with: ["a": ""])

        XCTAssertEqual(store.string(forKey: "a", fallback: ""), "a")
    }
}

// MARK: - Dogrulama

final class ValidatorTests: XCTestCase {
    private func bundle(
        schema: Int = 1, release: Int = 2, locale: String = "tr",
        strings: [String: String] = ["k": "v"]
    ) -> LocalizationBundle {
        LocalizationBundle(
            schemaVersion: schema, release: release, locale: locale, strings: strings
        )
    }

    func testAcceptsValidBundle() {
        XCTAssertNoThrow(
            try BundleValidator.validate(bundle(), expectedRelease: 2, expectedLocale: "tr")
        )
    }

    func testRejectsUnsupportedSchema() {
        XCTAssertThrowsError(
            try BundleValidator.validate(
                bundle(schema: 99), expectedRelease: 2, expectedLocale: "tr"
            )
        ) { error in
            XCTAssertEqual(error as? LocalizationError, .unsupportedSchemaVersion(99))
        }
    }

    func testRejectsLocaleMismatch() {
        XCTAssertThrowsError(
            try BundleValidator.validate(
                bundle(locale: "de"), expectedRelease: 2, expectedLocale: "tr"
            )
        ) { error in
            XCTAssertEqual(
                error as? LocalizationError,
                .localeMismatch(expected: "tr", received: "de")
            )
        }
    }

    func testRejectsReleaseMismatch() {
        XCTAssertThrowsError(
            try BundleValidator.validate(
                bundle(release: 9), expectedRelease: 2, expectedLocale: "tr"
            )
        ) { error in
            XCTAssertEqual(
                error as? LocalizationError,
                .releaseMismatch(expected: 2, received: 9)
            )
        }
    }

    func testRejectsEmptyBundle() {
        XCTAssertThrowsError(
            try BundleValidator.validate(
                bundle(strings: [:]), expectedRelease: 2, expectedLocale: "tr"
            )
        ) { error in
            XCTAssertEqual(error as? LocalizationError, .emptyBundle)
        }
    }

    func testRejectsEmptyValue() {
        XCTAssertThrowsError(
            try BundleValidator.validate(
                bundle(strings: ["k": ""]), expectedRelease: 2, expectedLocale: "tr"
            )
        ) { error in
            XCTAssertEqual(error as? LocalizationError, .emptyValue(key: "k"))
        }
    }
}

// MARK: - Locale cozumleme

final class LocaleResolverTests: XCTestCase {
    func testExactMatch() {
        XCTAssertEqual(
            LocaleResolver.resolve(
                preferred: ["tr"], available: ["en", "tr"], sourceLocale: "en"
            ),
            "tr"
        )
    }

    func testFallsBackToBaseLanguage() {
        XCTAssertEqual(
            LocaleResolver.resolve(
                preferred: ["tr-TR"], available: ["en", "tr"], sourceLocale: "en"
            ),
            "tr"
        )
    }

    func testPrefersExactRegionOverBase() {
        XCTAssertEqual(
            LocaleResolver.resolve(
                preferred: ["pt-BR"], available: ["en", "pt", "pt-BR"], sourceLocale: "en"
            ),
            "pt-BR"
        )
    }

    func testFallsBackToSourceLocale() {
        XCTAssertEqual(
            LocaleResolver.resolve(
                preferred: ["ja"], available: ["en", "tr"], sourceLocale: "en"
            ),
            "en"
        )
    }
}

// MARK: - Cache

final class CacheTests: XCTestCase {
    func testSaveThenLoad() throws {
        let cache = LocalizationCache(projectKey: "pk_test", root: temporaryRoot())
        let bundle = LocalizationBundle(
            schemaVersion: 1, release: 3, locale: "tr", strings: ["a": "b"]
        )

        try cache.save(bundle)

        XCTAssertEqual(cache.load(locale: "tr"), bundle)
    }

    func testLoadReturnsNilWhenMissing() {
        let cache = LocalizationCache(projectKey: "pk_test", root: temporaryRoot())

        XCTAssertNil(cache.load(locale: "tr"))
    }

    func testInvalidCacheIsIgnored() throws {
        let root = temporaryRoot()
        let cache = LocalizationCache(projectKey: "pk_test", root: root)

        try FileManager.default.createDirectory(
            at: cache.directory(for: "tr"), withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: cache.file(for: "tr"))

        XCTAssertNil(cache.load(locale: "tr"))
    }

    /// docs/TECHNICAL_DESIGN.md §19 kural 4.
    func testFailedSaveKeepsPreviousCache() throws {
        let cache = LocalizationCache(projectKey: "pk_test", root: temporaryRoot())
        let good = LocalizationBundle(
            schemaVersion: 1, release: 1, locale: "tr", strings: ["a": "eski"]
        )

        try cache.save(good)

        let bad = LocalizationBundle(
            schemaVersion: 99, release: 2, locale: "tr", strings: ["a": "yeni"]
        )

        XCTAssertThrowsError(try cache.save(bad))
        XCTAssertEqual(cache.load(locale: "tr"), good)
    }
}

// MARK: - Ag ve release kontrolu

final class RefreshTests: XCTestCase {
    private func makeSDK(
        transport: FakeTransport, locale: String? = "tr"
    ) -> Localization {
        let sdk = Localization()
        sdk.configure(
            projectKey: "pk_test",
            baseURL: URL(string: "https://example.test")!,
            locale: locale,
            transport: transport
        )
        return sdk
    }

    func testFetchesBundleOnFirstRefresh() async throws {
        let transport = FakeTransport()
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/manifest", json: manifestJSON(release: 2)
        )
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/releases/2/tr",
            json: bundleJSON(release: 2, locale: "tr", cta: "Ücretsiz dene")
        )

        let sdk = makeSDK(transport: transport)
        _ = try await sdk.refresh()

        XCTAssertEqual(sdk.string(forKey: "paywall.cta.start_trial"), "Ücretsiz dene")
        XCTAssertEqual(sdk.currentRelease, 2)
    }

    func testSameReleaseSkipsDownload() async throws {
        let transport = FakeTransport()
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/manifest", json: manifestJSON(release: 2)
        )
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/releases/2/tr",
            json: bundleJSON(release: 2, locale: "tr", cta: "Ücretsiz dene")
        )

        let sdk = makeSDK(transport: transport)
        _ = try await sdk.refresh()

        let before = transport.requested.count
        let second = try await sdk.refresh()

        XCTAssertNil(second, "Ayni release'te paket tekrar indirilmemeli")
        XCTAssertEqual(transport.requested.count, before + 1, "Yalnizca manifest istenmeli")
    }

    /// Rollback: sunucu v3'ten v1'e donerse cihaz da inmeli.
    /// Karsilastirma `!=` oldugu icin calisir; `>` olsaydi cihaz v3'te kalirdi.
    func testRollbackDownloadsOlderRelease() async throws {
        let transport = FakeTransport()
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/manifest", json: manifestJSON(release: 3)
        )
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/releases/3/tr",
            json: bundleJSON(release: 3, locale: "tr", cta: "Hemen ücretsiz dene")
        )

        let sdk = makeSDK(transport: transport)
        _ = try await sdk.refresh()
        XCTAssertEqual(sdk.currentRelease, 3)

        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/manifest", json: manifestJSON(release: 1)
        )
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/releases/1/tr",
            json: bundleJSON(release: 1, locale: "tr", cta: "Ücretsiz dene")
        )

        _ = try await sdk.refresh()

        XCTAssertEqual(sdk.currentRelease, 1)
        XCTAssertEqual(sdk.string(forKey: "paywall.cta.start_trial"), "Ücretsiz dene")
    }

    func testManifest404Throws() async {
        let transport = FakeTransport()
        transport.stub(path: "/api/sdk/v1/projects/pk_test/manifest", status: 404)

        let sdk = makeSDK(transport: transport)

        do {
            _ = try await sdk.refresh()
            XCTFail("404 hata firlatmali")
        } catch {
            XCTAssertEqual(error as? LocalizationError, .httpStatus(404))
        }
    }

    func testMalformedJSONThrows() async {
        let transport = FakeTransport()
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/manifest", json: "{ bozuk"
        )

        let sdk = makeSDK(transport: transport)

        do {
            _ = try await sdk.refresh()
            XCTFail("Bozuk JSON hata firlatmali")
        } catch {
            XCTAssertEqual(error as? LocalizationError, .decodingFailed)
        }
    }

    /// Yeni paket alinamadiginda eldeki metin korunur.
    func testFailedRefreshKeepsPreviousStrings() async throws {
        let transport = FakeTransport()
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/manifest", json: manifestJSON(release: 1)
        )
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/releases/1/tr",
            json: bundleJSON(release: 1, locale: "tr", cta: "Ücretsiz dene")
        )

        let sdk = makeSDK(transport: transport)
        _ = try await sdk.refresh()

        // Sunucu yeni bir release duyuruyor ama paketi bozuk.
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/manifest", json: manifestJSON(release: 2)
        )
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/releases/2/tr", json: "{ bozuk"
        )

        _ = try? await sdk.refresh()

        XCTAssertEqual(sdk.string(forKey: "paywall.cta.start_trial"), "Ücretsiz dene")
        XCTAssertEqual(sdk.currentRelease, 1)
    }

    func testLocaleResolvedFromManifestWhenNotPinned() async throws {
        let transport = FakeTransport()
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/manifest",
            json: manifestJSON(release: 1, locales: ["en"])
        )
        transport.stub(
            path: "/api/sdk/v1/projects/pk_test/releases/1/en",
            json: bundleJSON(release: 1, locale: "en", cta: "Start free trial")
        )

        let sdk = makeSDK(transport: transport, locale: nil)
        _ = try await sdk.refresh()

        XCTAssertEqual(sdk.currentLocale, "en")
        XCTAssertEqual(sdk.string(forKey: "paywall.cta.start_trial"), "Start free trial")
    }
}

// MARK: - Acilis davranisi

/// Bu sinif tek bir hatanin nobetcisi: uygulama her acildiginda once
/// fallback, sonra ag donunce gercek metin gorunuyordu — yani metinler
/// zipliyordu. Sebep configure'in diskteki paketi yalnizca locale
/// sabitlenmisse yuklemesiydi.
final class StartupTests: XCTestCase {
    private let projectKey = "pk_startup_test"

    override func tearDown() {
        LocalizationCache(projectKey: projectKey).clear(locale: "tr")
        super.tearDown()
    }

    /// Locale sabitlenmemis olsa bile configure donduğunde metin hazir olmali.
    func testConfigureLoadsCachedBundleWithoutPinnedLocale() throws {
        let cache = LocalizationCache(projectKey: projectKey)

        try cache.save(
            LocalizationBundle(
                schemaVersion: 1,
                release: 7,
                locale: "tr",
                strings: ["paywall.cta.start_trial": "Ücretsiz dene"]
            )
        )
        cache.saveLastLocale("tr")

        let sdk = Localization()
        sdk.configure(
            projectKey: projectKey,
            baseURL: URL(string: "https://example.test")!,
            transport: FakeTransport() // stub yok: ag basarisiz olacak
        )

        // Ag beklenmeden, senkron olarak dogru metin.
        XCTAssertEqual(
            sdk.string(forKey: "paywall.cta.start_trial", fallback: "Start free trial"),
            "Ücretsiz dene"
        )
        XCTAssertEqual(sdk.currentRelease, 7)
    }

    /// Hic cache yoksa fallback gorunur — ilk kurulumun dogru davranisi.
    func testConfigureWithoutCacheUsesFallback() {
        let sdk = Localization()
        sdk.configure(
            projectKey: "pk_startup_empty_test",
            baseURL: URL(string: "https://example.test")!,
            transport: FakeTransport()
        )

        XCTAssertEqual(
            sdk.string(forKey: "paywall.title", fallback: "Unlock Premium"),
            "Unlock Premium"
        )
    }

    /// Ayni paket tekrar uygulandiginda UI tazelenmemeli; yoksa gorunum bos
    /// yere yeniden olusur ve goz kirpar.
    func testApplyReportsChangeOnlyOnce() {
        let store = LocalizationStore()
        let bundle = LocalizationBundle(
            schemaVersion: 1, release: 3, locale: "tr", strings: ["a": "bir"]
        )

        XCTAssertTrue(store.apply(bundle))
        XCTAssertFalse(store.apply(bundle))

        let next = LocalizationBundle(
            schemaVersion: 1, release: 4, locale: "tr", strings: ["a": "iki"]
        )

        XCTAssertTrue(store.apply(next))
    }
}

// MARK: - Test Mode

private func previewJSON(revision: Int, locale: String, cta: String) -> String {
    """
    {"locale":"\(locale)","sourceLocale":"en","availableLocales":["en","tr"],
     "revision":\(revision),"strings":{"paywall.cta.start_trial":"\(cta)"}}
    """
}

/// docs/IMPLEMENTATION_PLAN.md Faz 24: test state production disk cache'ini
/// degistirmez. Bu sinif o kuralin nobetcisi.
final class TestModeTests: XCTestCase {
    private let projectKey = "pk_preview_test"
    private let previewPath = "/api/sdk/v1/preview/tok"

    private var cache: LocalizationCache { LocalizationCache(projectKey: projectKey) }

    override func tearDown() {
        cache.clear(locale: "tr")
        super.tearDown()
    }

    private func published() -> LocalizationBundle {
        LocalizationBundle(
            schemaVersion: 1,
            release: 5,
            locale: "tr",
            strings: ["paywall.cta.start_trial": "Ücretsiz dene"]
        )
    }

    private func makeSDK(_ transport: FakeTransport) -> Localization {
        let sdk = Localization()
        sdk.configure(
            projectKey: projectKey,
            baseURL: URL(string: "https://example.test")!,
            locale: "tr",
            transport: transport
        )
        return sdk
    }

    /// Taslak metin ekranda gorunur ama diske yazilmaz. Yazilsaydi oturum
    /// bittikten sonra da cihazda kalir, yani yayinlanmamis metin gercek
    /// kullanicinin karsisina cikardi.
    func testDraftIsShownButNeverWrittenToDisk() async throws {
        try cache.save(published())
        cache.saveLastLocale("tr")

        let transport = FakeTransport()
        transport.stub(
            path: previewPath,
            json: previewJSON(revision: 11, locale: "tr", cta: "Taslak metin")
        )

        let sdk = makeSDK(transport)
        try await sdk.pollPreview(token: "tok")

        XCTAssertEqual(
            sdk.string(forKey: "paywall.cta.start_trial", fallback: nil),
            "Taslak metin"
        )

        XCTAssertEqual(
            cache.load(locale: "tr"),
            published(),
            "Disk cache taslak metinle degistirilmis"
        )
    }

    /// Oturum bitince cihaz yayinlanmis hale doner.
    func testFinishingRestoresPublishedCopy() async throws {
        try cache.save(published())
        cache.saveLastLocale("tr")

        let transport = FakeTransport()
        transport.stub(
            path: previewPath,
            json: previewJSON(revision: 12, locale: "tr", cta: "Taslak metin")
        )

        let sdk = makeSDK(transport)
        try await sdk.pollPreview(token: "tok")
        XCTAssertEqual(sdk.string(forKey: "paywall.cta.start_trial", fallback: nil), "Taslak metin")

        sdk.leaveTestMode()

        XCTAssertEqual(
            sdk.string(forKey: "paywall.cta.start_trial", fallback: nil),
            "Ücretsiz dene"
        )
    }

    /// Ayni revision tekrar gelirse gorunum tazelenmez.
    func testSameRevisionIsNotReapplied() async throws {
        let transport = FakeTransport()
        transport.stub(
            path: previewPath,
            json: previewJSON(revision: 13, locale: "tr", cta: "Taslak metin")
        )

        let sdk = makeSDK(transport)

        try await sdk.pollPreview(token: "tok")
        try await sdk.pollPreview(token: "tok")

        XCTAssertEqual(
            transport.requested.filter { $0 == previewPath }.count,
            2,
            "Her turda sorulmali"
        )
        XCTAssertEqual(sdk.string(forKey: "paywall.cta.start_trial", fallback: nil), "Taslak metin")
    }

    /// Test Mode acikken uygulama one geldiginde tetiklenen yenileme
    /// taslagi silip atmamali.
    func testRefreshIsSkippedWhileTestModeIsActive() async throws {
        let transport = FakeTransport()
        transport.stub(
            path: previewPath,
            json: previewJSON(revision: 14, locale: "tr", cta: "Taslak metin")
        )
        transport.stub(
            path: "/api/sdk/v1/projects/\(projectKey)/manifest",
            json: manifestJSON(release: 9)
        )

        let sdk = makeSDK(transport)
        sdk.startTestMode(token: "tok")
        defer { sdk.stopTestMode() }

        XCTAssertTrue(sdk.isTestModeActive)

        let result = try await sdk.refresh()

        XCTAssertNil(result, "Test Mode acikken yayinlanmis paket cekilmemeli")
    }
}
