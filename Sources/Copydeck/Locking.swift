import Foundation

extension NSLock {
    /// Kilidi kapsam icinde tutar ve cikista mutlaka birakir.
    ///
    /// Swift 6'da `NSLock.lock()` async baglamdan cagrilamiyor. Sebebi
    /// gercek bir tehlike: kilit bir `await` boyunca elde tutulursa, gorev
    /// askiya alindiginda ayni thread baska bir goreve gecebilir ve o gorev
    /// ayni kilidi isterse kilitlenme olur.
    ///
    /// `body` async degil — yani icine `await` yazilamaz. Uyariyi susturmak
    /// yerine kilidin bir askiya alma noktasi boyunca tutulmasini derleyici
    /// seviyesinde imkansiz kiliyoruz.
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
