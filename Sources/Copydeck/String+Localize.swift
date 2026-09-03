import Foundation

public extension String {
    /// `Text("paywall.title".localize)`
    ///
    /// Yalnizca bellekten okur; ag ya da disk erisimi yoktur.
    var localize: String {
        Localization.shared.string(forKey: self)
    }

    /// `Text("paywall.title".localize(fallback: "Unlock Premium"))`
    ///
    /// Anahtar bulunamazsa fallback, o da yoksa anahtarin kendisi doner.
    func localize(fallback: String) -> String {
        Localization.shared.string(forKey: self, fallback: fallback)
    }
}
