#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Test Mode acikken ekranin altinda duran QA cubugu.
///
/// QA telefonu elinde tutuyor ve laptopa bakiyor; her ekranda iki kez
/// baglam degistiriyordu. Bu cubuk o gidis gelisi kaldiriyor: onay, sorun
/// ve dil degistirme cihazin kendisinde.
///
/// Yalnizca Test Mode acikken gorunuyor. Uretimde hicbir sey cizmiyor —
/// oturum yoksa cubuk da yok.
///
/// Isledigi metinler "su an ekranda gorunenler", yani SDK'nin `CopyText`
/// uzerinden zaten bildigi liste. Ekran kaydi ya da gorunum adi gerekmiyor.
public struct CopydeckTestBar: View {
    @ObservedObject private var observer = Localization.shared.observer

    @State private var busy = false
    @State private var flash: String?
    @State private var issueText = ""
    @State private var writingIssue = false

    public init() {}

    public var body: some View {
        Group {
            if case .live(let locale) = Localization.shared.testModeState {
                bar(locale: locale)
            }
        }
    }

    private func bar(locale: String) -> some View {
        VStack(spacing: 8) {
            if writingIssue {
                HStack(spacing: 8) {
                    TextField("What is wrong?", text: $issueText)
                        .textFieldStyle(.roundedBorder)
                        .font(.footnote)

                    Button("Send") {
                        act { await Localization.shared.reportIssue(comment: issueText) }
                        issueText = ""
                        writingIssue = false
                    }
                    .font(.footnote.weight(.semibold))
                }
            }

            HStack(spacing: 10) {
                Text(flash ?? "TEST · \(locale)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.orange)

                Spacer()

                Button("Approve") {
                    act { await Localization.shared.approveVisible() }
                }
                .font(.footnote.weight(.semibold))

                Button("Issue") {
                    writingIssue.toggle()
                }
                .font(.footnote)

                Button("Next") {
                    act { await Localization.shared.nextTestLocale() }
                }
                .font(.footnote)
            }
            .disabled(busy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func act(_ work: @escaping () async -> Bool) {
        busy = true

        Task {
            let ok = await work()

            // Kisa bir geri bildirim: QA cihaza bakiyor, panele degil.
            flash = ok ? "Saved" : "Failed"
            busy = false

            try? await Task.sleep(nanoseconds: 1_200_000_000)

            flash = nil
        }
    }
}

public extension View {
    /// Test Mode acikken alta QA cubugunu koyar.
    ///
    /// Kok gorunume bir kere uygulanir. Oturum yokken hicbir sey cizmez.
    func copydeckTestBar() -> some View {
        safeAreaInset(edge: .bottom) { CopydeckTestBar() }
    }
}
#endif
