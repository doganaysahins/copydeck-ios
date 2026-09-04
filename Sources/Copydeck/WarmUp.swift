import Foundation

/// Iki isten hangisi once biterse onu bekleyen kapi.
///
/// Kaybedeni iptal etmiyoruz, bilerek: sure dolarsa yenilemeden vazgecmis
/// olmuyoruz, yalnizca beklemekten vazgeciyoruz. Yenileme arka planda
/// tamamlanip metni gunceller.
///
/// TaskGroup ile yazmak daha kisa olurdu ama dogru calismazdi: grup, cocuk
/// gorevlerin hepsi bitmeden donmuyor ve `Task.value` beklemesi iptale yanit
/// vermiyor. Yani sure dolsa bile yenileme bitene kadar beklerdik — tam da
/// engellemeye calistigimiz sey.
final class WarmUpGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            let alreadyFinished = lock.withLock { () -> Bool in
                if isFinished { return true }

                self.continuation = continuation

                return false
            }

            if alreadyFinished { continuation.resume() }
        }
    }

    func finish() {
        let waiting = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            guard !isFinished else { return nil }

            isFinished = true

            let pending = continuation
            continuation = nil

            return pending
        }

        waiting?.resume()
    }
}
