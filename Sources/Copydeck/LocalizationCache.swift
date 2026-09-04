import Foundation

/// Disk cache.
///
/// docs/IOS_SDK.md §10 — yol:
///
///     Application Support/Copydeck/<projectKey>/<locale>/bundle.json
///
/// Yazma sirasi onemli: once gecici dosya, sonra geri okuyup dogrulama,
/// en son atomik degistirme. Bozuk bir paket eldeki gecerli cache'i asla
/// bozamaz.
struct LocalizationCache {
    let projectKey: String
    private let fileManager: FileManager
    private let root: URL

    init(projectKey: String, fileManager: FileManager = .default, root: URL? = nil) {
        self.projectKey = projectKey
        self.fileManager = fileManager

        if let root {
            self.root = root
        } else {
            let support = (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? fileManager.temporaryDirectory

            self.root = support.appendingPathComponent("Copydeck", isDirectory: true)
        }
    }

    func directory(for locale: String) -> URL {
        root
            .appendingPathComponent(projectKey, isDirectory: true)
            .appendingPathComponent(locale, isDirectory: true)
    }

    func file(for locale: String) -> URL {
        directory(for: locale).appendingPathComponent("bundle.json")
    }

    /// Diskteki paketi okur. Dosya yoksa, decode edilemezse ya da dogrulamayi
    /// gecemezse `nil` doner — cagiran taraf bunu "cache yok" olarak gorur.
    func load(locale: String) -> LocalizationBundle? {
        let url = file(for: locale)

        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let bundle = try? JSONDecoder().decode(LocalizationBundle.self, from: data) else {
            return nil
        }

        do {
            try BundleValidator.validate(bundle, expectedRelease: nil, expectedLocale: locale)
        } catch {
            return nil
        }

        return bundle
    }

    /// Paketi diske yazar. Once gecici dosyaya yazip geri okuyarak dogrular;
    /// ancak ondan sonra mevcut dosyanin yerine atomik olarak gecer.
    func save(_ bundle: LocalizationBundle) throws {
        let directory = directory(for: bundle.locale)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(bundle)
        let temporary = directory.appendingPathComponent("bundle.json.tmp-\(UUID().uuidString)")

        try data.write(to: temporary, options: .atomic)

        // Geri okuyup dogrula: diske bozuk bir sey yazildiysa mevcut dosyaya
        // hic dokunmadan vazgec.
        do {
            let written = try Data(contentsOf: temporary)
            let decoded = try JSONDecoder().decode(LocalizationBundle.self, from: written)
            try BundleValidator.validate(
                decoded,
                expectedRelease: bundle.release,
                expectedLocale: bundle.locale
            )
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }

        let destination = file(for: bundle.locale)

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    // MARK: - Son gosterilen dil

    private var lastLocaleFile: URL {
        root
            .appendingPathComponent(projectKey, isDirectory: true)
            .appendingPathComponent("last-locale")
    }

    /// En son hangi dilin gosterildigi.
    ///
    /// Acilista hangi paketi senkron yukleyecegimizi bilmek icin gerekli.
    /// Cihazin dilini projenin dillerine eslemek manifest'i, yani agi
    /// gerektiriyor; bu bilgi diskte durmazsa ilk render dogru metni
    /// gosteremez ve ag donunce metinler ziplar.
    func lastLocale() -> String? {
        guard
            let data = try? Data(contentsOf: lastLocaleFile),
            let raw = String(data: data, encoding: .utf8)
        else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func saveLastLocale(_ locale: String) {
        let directory = root.appendingPathComponent(projectKey, isDirectory: true)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data(locale.utf8).write(to: lastLocaleFile, options: .atomic)
    }

    func clear(locale: String) {
        try? fileManager.removeItem(at: file(for: locale))
    }
}
