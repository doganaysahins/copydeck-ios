import Foundation

/// Cihazin dilini projenin dillerine esler.
///
/// docs/TECHNICAL_DESIGN.md §15:
///
///     tr-TR -> yoksa tr -> yoksa sourceLocale
enum LocaleResolver {
    static func resolve(
        preferred: [String],
        available: [String],
        sourceLocale: String
    ) -> String {
        guard !available.isEmpty else { return sourceLocale }

        let lowercased = available.map { $0.lowercased() }

        func match(_ candidate: String) -> String? {
            guard let index = lowercased.firstIndex(of: candidate.lowercased()) else {
                return nil
            }
            return available[index]
        }

        for tag in preferred {
            // Tam eslesme: pt-BR
            if let exact = match(tag) { return exact }

            // Ana dile dus: pt-BR -> pt
            if let dash = tag.firstIndex(of: "-") {
                let base = String(tag[tag.startIndex..<dash])
                if let baseMatch = match(base) { return baseMatch }
            }
        }

        return match(sourceLocale) ?? sourceLocale
    }

    static func deviceLocale(available: [String], sourceLocale: String) -> String {
        resolve(
            preferred: Locale.preferredLanguages,
            available: available,
            sourceLocale: sourceLocale
        )
    }
}
