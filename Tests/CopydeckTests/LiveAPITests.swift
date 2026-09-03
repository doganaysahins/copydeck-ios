import XCTest
@testable import Copydeck

/// Gercek sunucuya baglanan uctan uca kontrol.
///
/// Varsayilan olarak atlanir; ag gerektiren bir testin normal `swift test`
/// kosusunu kirmasini istemiyoruz. Calistirmak icin:
///
///     COPYDECK_BASE_URL=https://localize-app-theta.vercel.app \
///     COPYDECK_PROJECT_KEY=pk_demo \
///     swift test --filter LiveAPITests
///
/// Bu test gectiginde urunun vaadi ilk kez gerceklesmis olur: panelde
/// yayinlanan metin, SDK tarafindan indirilip diske yazilmis ve okunmustur.
final class LiveAPITests: XCTestCase {
    private var baseURL: URL!
    private var projectKey: String!

    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment

        guard
            let raw = environment["COPYDECK_BASE_URL"],
            let url = URL(string: raw)
        else {
            throw XCTSkip("COPYDECK_BASE_URL verilmedi — canli test atlandi.")
        }

        baseURL = url
        projectKey = environment["COPYDECK_PROJECT_KEY"] ?? "pk_demo"
    }

    /// manifest -> locale cozumle -> paket indir -> dogrula -> diske yaz ->
    /// geri oku -> lookup.
    func testFullChainAgainstHostedAPI() async throws {
        let client = LocalizationClient(
            baseURL: baseURL,
            projectKey: projectKey,
            transport: URLSessionTransport()
        )

        let manifest = try await client.fetchManifest()
        print("manifest: release=\(manifest.release) locales=\(manifest.availableLocales)")

        XCTAssertEqual(manifest.schemaVersion, LocalizationSchema.supportedVersion)
        XCTAssertFalse(manifest.availableLocales.isEmpty)

        let locale = LocaleResolver.resolve(
            preferred: ["tr"],
            available: manifest.availableLocales,
            sourceLocale: manifest.sourceLocale
        )

        let bundle = try await client.fetchBundle(release: manifest.release, locale: locale)
        print("bundle: \(bundle.locale) v\(bundle.release), \(bundle.strings.count) key")

        try BundleValidator.validate(
            bundle,
            expectedRelease: manifest.release,
            expectedLocale: locale
        )

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("copydeck-live-\(UUID().uuidString)", isDirectory: true)
        let cache = LocalizationCache(projectKey: projectKey, root: root)

        try cache.save(bundle)

        let reloaded = try XCTUnwrap(
            cache.load(locale: locale),
            "Diske yazilan paket geri okunamadi"
        )
        XCTAssertEqual(reloaded, bundle)

        let store = LocalizationStore()
        store.apply(reloaded)

        let key = try XCTUnwrap(bundle.strings.keys.sorted().first)
        let value = store.string(forKey: key, fallback: nil)

        print("lookup: \(key) -> \(value)")
        XCTAssertEqual(value, bundle.strings[key])

        try? FileManager.default.removeItem(at: root)
    }

    /// Yayinlanmamis bir surum istenirse 404 gelir ve eldeki cache bozulmaz.
    func testUnknownReleaseReturns404() async throws {
        let client = LocalizationClient(
            baseURL: baseURL,
            projectKey: projectKey,
            transport: URLSessionTransport()
        )

        do {
            _ = try await client.fetchBundle(release: 9999, locale: "tr")
            XCTFail("Olmayan release 404 donmeliydi")
        } catch {
            XCTAssertEqual(error as? LocalizationError, .httpStatus(404))
        }
    }
}
