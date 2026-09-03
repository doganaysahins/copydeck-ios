import Foundation

/// Yeni gelen paket, eldeki cache'i degistirmeden ONCE dogrulanir.
///
/// docs/TECHNICAL_DESIGN.md §14: paket decode edilemezse, schemaVersion
/// desteklenmiyorsa, beklenen locale ile eslesmiyorsa ya da release metadata
/// uyusmuyorsa eski gecerli cache korunur.
enum BundleValidator {
    static func validate(
        _ bundle: LocalizationBundle,
        expectedRelease: Int?,
        expectedLocale: String?
    ) throws {
        guard bundle.schemaVersion == LocalizationSchema.supportedVersion else {
            throw LocalizationError.unsupportedSchemaVersion(bundle.schemaVersion)
        }

        if let expectedLocale, bundle.locale != expectedLocale {
            throw LocalizationError.localeMismatch(
                expected: expectedLocale,
                received: bundle.locale
            )
        }

        if let expectedRelease, bundle.release != expectedRelease {
            throw LocalizationError.releaseMismatch(
                expected: expectedRelease,
                received: bundle.release
            )
        }

        guard !bundle.strings.isEmpty else {
            throw LocalizationError.emptyBundle
        }

        // Bos string gecerli bir deger degildir; varsayilan fallback olarak
        // kullanilamaz (docs/TECHNICAL_DESIGN.md §19 kural 3).
        for (key, value) in bundle.strings where value.isEmpty {
            throw LocalizationError.emptyValue(key: key)
        }
    }
}
