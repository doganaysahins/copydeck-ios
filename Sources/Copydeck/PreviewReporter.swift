import Foundation

/// Cihazin QA'ya ne gosterdigini takip eder.
///
/// Iki ayri soru var ve ikisi de Test Mode sirasinda panele bildiriliyor:
///
/// - **Su an ekranda ne var** — QA hangi ekranda, panel onu takip edebilsin.
/// - **Oturum boyunca ne gorundu** — "her yeri gezdim mi" sorusunun cevabi.
///
/// Yalnizca degisen bilgi gonderiliyor. QA bir ekranda dururken saniyede bir
/// ayni listeyi yollamanin anlami yok; ikinci turdan itibaren rapor bos
/// kaliyor ve sunucu hicbir sey yazmiyor.
///
/// Kapsam dil basina tutuluyor. Bir metni TR'de gormek DE'de gordugun
/// anlamina gelmiyor — localization testinin butun meselesi bu — o yuzden
/// dil degistiginde gorulmus sayilanlar sifirlaniyor.
final class PreviewReporter: @unchecked Sendable {
    struct Report {
        /// Degismediyse nil: sunucu o zaman ekrandaki listeye dokunmuyor.
        let visible: [String]?
        let newlySeen: [String]

        /// Uygulamanin istedigi ama pakette olmayan key'ler.
        let missing: [String]
    }

    private let lock = NSLock()

    private var visible: Set<String> = []
    private var lastReportedVisible: Set<String>?
    private var reportedSeen: Set<String> = []
    private var missing: Set<String> = []
    private var reportedMissing: Set<String> = []
    private var locale: String?

    func appeared(_ key: String) {
        lock.withLock { visible.insert(key) }
    }

    func disappeared(_ key: String) {
        lock.withLock { visible.remove(key) }
    }

    /// Uygulama bu key'i istedi ama pakette yoktu.
    ///
    /// Panel bunu baska turlu ogrenemiyor: kodda hangi key'lerin gectigini
    /// gormuyor. Gelistirici bir key yazip panele eklemeyi unuttugunda tek
    /// uyari bu.
    func noteMissing(_ key: String) {
        lock.withLock { missing.insert(key) }
    }

    /// Su an ekranda olan key'ler.
    func currentlyVisible() -> [String] {
        lock.withLock { visible.sorted() }
    }

    /// Oturumun dili degisti: bu dilde hicbir sey gorulmemis sayilir.
    func localeChanged(to newLocale: String) {
        lock.withLock {
            guard locale != newLocale else { return }

            locale = newLocale
            reportedSeen = []
            lastReportedVisible = nil

            // Bir key TR'de eksik olabilir ama DE'de olabilir; yeniden
            // bakilmasi gerekiyor.
            missing = []
            reportedMissing = []
        }
    }

    /// Gonderilecek rapor; gonderilecek bir sey yoksa nil.
    func pendingReport() -> Report? {
        lock.withLock {
            let visibleChanged = lastReportedVisible != visible
            let newlySeen = visible.subtracting(reportedSeen)
            let newlyMissing = missing.subtracting(reportedMissing)

            guard visibleChanged || !newlySeen.isEmpty || !newlyMissing.isEmpty else {
                return nil
            }

            return Report(
                visible: visibleChanged ? visible.sorted() : nil,
                newlySeen: newlySeen.sorted(),
                missing: newlyMissing.sorted()
            )
        }
    }

    /// Rapor sunucuya ulasti. Basarisiz gonderimde cagrilmiyor, boylece bir
    /// ag hatasi kapsam bilgisini sessizce dusurmuyor.
    func commit(_ report: Report) {
        lock.withLock {
            if let reported = report.visible {
                lastReportedVisible = Set(reported)
            }

            reportedSeen.formUnion(report.newlySeen)
            reportedMissing.formUnion(report.missing)
        }
    }

    func reset() {
        lock.withLock {
            visible = []
            lastReportedVisible = nil
            reportedSeen = []
            missing = []
            reportedMissing = []
            locale = nil
        }
    }
}
