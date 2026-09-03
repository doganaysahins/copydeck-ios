# Copydeck — iOS SDK

Over-the-air metin ve localization guncellemeleri.

Gelistirici anahtari bir kere baglar; sonrasinda urun ve ceviri ekibi metni
yeni bir uygulama surumu cikarmadan degistirir.

```swift
Text("paywall.title".localize)
```

Uygulama acilista diskteki son gecerli paketle render eder. **Ag hicbir zaman
ilk render'i bekletmez.**

## Kurulum

Xcode → **File → Add Package Dependencies** → adres alanina:

```
https://github.com/doganaysahins/copydeck-ios
```

Ya da `Package.swift` icinden:

```swift
dependencies: [
    .package(url: "https://github.com/doganaysahins/copydeck-ios", from: "0.1.0")
]
```

Gereksinim: iOS 15+ / macOS 12+, Swift 5.9+.

## Kullanim

Acilista bir kere:

```swift
import Copydeck

Localization.shared.configure(
    projectKey: "pk_live_...",
    baseURL: URL(string: "https://your-copydeck-instance.vercel.app")!
)
```

Metin:

```swift
Text("paywall.title".localize)
Text("paywall.title".localize(fallback: "Unlock Premium"))
Button("paywall.cta.start_trial".localize) { startTrial() }
```

Uygulama one geldiginde:

```swift
Localization.shared.refreshInBackground()
```

SwiftUI'nin yeni paketi gormesi icin root view store'u observe etmeli.
`.localize` duz `String` donduruyor, yani SwiftUI kendiliginden metnin
degistigini bilemez:

```swift
struct RootView: View {
    @StateObject private var localization = Localization.shared.observer

    var body: some View {
        PaywallView()
            .id(localization.version)
    }
}
```

## Davranis kurallari

Bunlar tasarim karari, tesaduf degil:

- **Lookup aga gitmez.** `.localize` yalnizca bellekten okur, senkrondur.
- **Eksik key crash yaratmaz.** Sira: deger → fallback → key'in kendisi.
  Bos string asla gecerli bir sonuc degildir.
- **Bozuk paket eski cache'i bozamaz.** Yeni paket once gecici dosyaya yazilir,
  geri okunup dogrulanir, ancak ondan sonra atomik olarak yerine gecer.
- **Surum karsilastirmasi `!=` iledir, `>` degil.** Sunucu v3'ten v1'e
  dondugunde (rollback) cihaz da inmeli. `>` olsaydi cihaz v3'te takili kalir
  ve rollback hicbir ise yaramazdi.
- **Ag yoksa uygulama calismaya devam eder** — son gecerli paketle.

## Derleme ve test

Paket macOS'u da destekliyor, yani simulator olmadan komut satirinda calisir:

```bash
swift build
swift test
```

Gercek bir sunucuya baglanan uctan uca kontrol (varsayilan olarak atlanir):

```bash
COPYDECK_BASE_URL=https://your-instance.vercel.app \
COPYDECK_PROJECT_KEY=pk_demo \
swift test --filter LiveAPITests
```

Bu gectiginde zincir dogrulanmis olur: manifest → paket indir → dogrula →
diske yaz → geri oku → lookup.

## Kapsam disi (0.1.0)

plural · ICU · bicimlendirme argumanlari · rich text · attributed string ·
kullanici bazli hedefleme · WebSocket · uretilen tipli key'ler

## Not

Kaynak dosyalardaki `docs/IOS_SDK.md` atiflari, bu SDK'nin uretildigi ic
tasarim dokumanina isaret ediyor; o dokuman bu repoda yok. Yorumlar yine de
kendi baslarina okunabilir — hepsi bir kararin *nedenini* anlatiyor.

## Lisans

MIT. Bkz. [LICENSE](LICENSE).
