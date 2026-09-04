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

Localization.shared.configure(projectKey: "pk_live_...")
```

Sunucu adresi istenmiyor: o bizim altyapi detayimiz. Kendi sunucunu
kullaniyorsan `baseURL:` ile gecebilirsin.

### Gelistirme sirasinda canli gormek

```swift
Localization.shared.configure(projectKey: "pk_live_...", testMode: true)
```

Iki saniyede bir sunucuya sorar, yani panelde Publish'e bastiginda degisikligi
uygulamayi arka plana atmadan gorursun.

Yalnizca **yayinlanmis** icerigi gosterir — taslak metinleri degil. Panelden
QR ile baslatilan oturum tabanli Test Mode ayri bir is.

Uretim derlemesinde acik birakma; `stopTestMode()` ile kapatilir.

Hepsi bu. Uygulama one geldiginde yeni surumu SDK kendisi ariyor; kok
gorunumde kurulum yok.

Metinleri `@Localized` ile bildirirsin:

```swift
struct PaywallView: View {
    @Localized("paywall.title", fallback: "Unlock Premium") var title
    @Localized("paywall.cta.start_trial") var cta

    var body: some View {
        VStack {
            Text(title)
                .font(.largeTitle.bold())

            Button(cta) { startTrial() }
        }
    }
}
```

Duz `String` verdigi icin her yerde calisir: `Text`, `Button` basligi,
`Label`, `Text + Text` birlestirmesi, `accessibilityLabel`.

`DynamicProperty` oldugu icin SwiftUI bunu iceren gorunumun bagimliligi
sayiyor: yeni paket geldiginde yalnizca o gorunum yeniden degerlendiriliyor.
Kimlik degismedigi icin `@State`, scroll pozisyonu ve navigasyon oldugu gibi
kaliyor.

Yan faydasi: ekranin yonetilen butun metinlerini struct'in tepesinde bir
arada gorursun.

### Anahtar derleme zamaninda belli degilse

`@Localized` bir saklanan alan olmak zorunda, yani dongude kullanilamaz.
Anahtar veriden geliyorsa `CopyText`:

```swift
ForEach(features) { feature in
    CopyText(feature.key)
}
```

`Text` gibi davranir, kendi kendini tazeler.

### SwiftUI disinda

```swift
label.text = "paywall.title".localize
```

### Ozet

| Durum | Kullan |
|---|---|
| Cogu yer | `@Localized("key") var x` |
| Anahtar calisma zamaninda belli | `CopyText(key)` |
| SwiftUI disi kod | `"key".localize` |

`.copydeckUpdates()` diye bir modifier de var ama **son care**: altta `.id()`
kullaniyor, yani alt agacin kimligini degistirip onu yok ediyor ve yeniden
kuruyor. `@State` sifirlanir, scroll basa doner, kullanicinin doldurdugu form
bosalir. Kokte kullanma.

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
