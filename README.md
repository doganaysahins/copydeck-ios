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

### Acilista metnin ziplamasini onlemek

Cache'te release 4, sunucuda 5 varsa uygulama once 4'u cizer, ~200ms sonra
5 gelir ve metin gozun onunde degisir. Bu her publish'ten sonraki her
acilista olur.

Ilk render'i kisa bir sure ag icin bekleterek onlenir:

```swift
struct RootView: View {
    @State private var ready = false

    var body: some View {
        Group {
            if ready { PaywallView() } else { Color(.systemBackground) }
        }
        .task {
            await Localization.shared.warmUp()
            ready = true
        }
    }
}
```

Normal baglantida manifest 100-150ms'de donuyor, yani ziplama hic gorunmez.
Ag yoksa ya da yavassa varsayilan 300ms dolar ve elde ne varsa onunla devam
edilir — uygulama takilmaz.

Sureyi sen secersin: `warmUp(timeout: 0.5)`. `0` verirsen hicbir sey
beklenmez.

Bu yalnizca bir goruntu meselesi degil: bekleme penceresi olmadan
kullanicinin gordugu ilk metin her zaman bir onceki surumun metnidir.

### Test Mode


Panelde bir oturum baslatirsin, cihaz oturuma baglanir ve **yayinlanmamis
taslak metinleri** gosterir. Panelde bir metni degistirdiginde ya da dili
degistirdiginde acik ekran yaklasik bir saniye icinde guncellenir.

```swift
Localization.shared.startTestMode(token: kod)   // panelde QR olarak gorunur
Localization.shared.stopTestMode()
```

Uc kural:

- **Taslak metin diske yazilmaz.** Yazilsaydi oturum bittikten sonra da
  cihazda kalir, yani yayinlanmamis metin gercek kullanicinin karsisina
  cikardi.
- **Oturum acikken normal yenileme calismaz.** Uygulama one geldiginde
  tetiklenen yenileme taslagi silip atardi.
- **Oturum bitince cihaz yayinlanmis hale doner** — panelden bitirsen de,
  suresi dolsa da.

### Gelistirme sirasinda canli gormek

Test Mode'dan farkli: bu yalnizca **yayinlanmis** icerigi izler, oturum
gerektirmez.

```swift
Localization.shared.configure(projectKey: "pk_live_...", livePolling: true)
```

Iki saniyede bir sorar, yani Publish'e bastiginda degisikligi uygulamayi arka
plana atmadan gorursun. Uretim derlemesinde acik birakma;
`stopLivePolling()` ile kapatilir.

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

## Bir sey beklendigi gibi calismadiginda

```swift
Copydeck.isLoggingEnabled = true
```

Konsola hangi adimda ne oldugunu yazar:

```
[Copydeck] acilis: diskten tr v3, 2 key
[Copydeck] yenileme gereksiz: zaten tr v3
[Copydeck] test: oturuma baglaniliyor
[Copydeck] test: tr rev 1868744125, 2 key uygulaniyor
[Copydeck] test: degisiklik yok (rev 1868744125)
```

Varsayilan kapali: bir SDK, entegre edildigi uygulamanin loguna davetsiz
yazmaz.

En sik karsilasilan iki durum ve loglarda nasil gorundukleri:

- **Test Mode'da metin degismiyor.** Oturumun dili ile duzenledigin dil ayni
  mi? Log `test: en rev ...` diyorsa cihaz Ingilizce gosteriyordur ve Turkce
  degeri degistirmen ekranda bir sey degistirmez.
- **Acilista metinler ziplayip degisiyor.** Log `acilis: diskte kayitli dil
  yok` diyorsa ilk render fallback ile cikmistir; bu yalnizca uygulamanin
  hayatindaki ilk acilista ya da proje anahtari degistiginde olur.

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
