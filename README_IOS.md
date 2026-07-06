iOS Release (no local Xcode) — Guide

`Tactical Eleven: Idle Manager` uygulamasının iOS build/imzalama/TestFlight yükleme işlerinin tamamı GitHub Actions'ın macOS runner'ı üzerinde çalışır. Xcode hiçbir zaman sizin bilgisayarınıza kurulmaz — Windows'tan bu depoya push attığınızda ya da workflow'u elle tetiklediğinizde, CI kendi macOS makinesinde Xcode'u kullanarak derler ve imzalar; siz sadece sonucu (TestFlight'taki build'i) görürsünüz.

Tek workflow: `.github/workflows/ios_release.yml`, `main`/`master`'a her push'ta ya da elle tetiklendiğinde çalışır:
1. **Analyze & Test** (ubuntu, hızlı) — `flutter analyze` + `flutter test` başarısız olursa build hiç başlamaz.
2. **Build IPA and upload to TestFlight** (macos-15) — Flutter + CocoaPods kurar, imzalama sertifikasını/profilini hazırlar, `fastlane ios beta` lane'i ile derler ve TestFlight'a yükler.

Gereken GitHub Secrets (tam liste: [GITHUB_SECRETS.md](GITHUB_SECRETS.md))
- `APP_STORE_CONNECT_KEY_ID` / `APP_STORE_CONNECT_ISSUER_ID` / `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` — App Store Connect API key. TestFlight yüklemesi VE imzalama sertifikası/profilinin oluşturulması için kullanılır — Apple ID şifresi veya 2FA kodu **hiç gerekmez**. Bu key'in **Admin** rolünde olması şart (Developer/App Manager rolü sertifika oluşturma iznini reddeder).
- `BUNDLE_ID`, `TEAM_ID`, `APPLE_ID`

## İmzalama nasıl çalışıyor (match yok, ekstra repo/secret gerekmiyor)

`fastlane/Fastfile`'daki `beta` lane'i iki yoldan birini otomatik seçiyor:
- `MATCH_GIT_URL` secret'ı tanımlıysa: klasik `fastlane match` akışı (salt okunur, ayrı bir sertifika deposu gerektirir).
- Tanımlı değilse (bu repodaki mevcut durum): **`cert` + `sigh`** ile, sadece yukarıdaki App Store Connect API key kullanılarak CI'nin kendi içinde bir Distribution sertifikası + App Store provisioning profile oluşturulur.

İlk çalıştırmada sertifika/profil sıfırdan oluşturulur ve `ios_signing_cache/` klasörüne yazılır; `ios_release.yml` bu klasörü `actions/cache` ile sabit bir anahtarla (`ios-signing-v1`) kalıcı olarak saklar. Sonraki her çalıştırma bu önbellekten okur, **yeni sertifika oluşturmaz** — çünkü Apple bir hesapta en fazla 3 aktif Distribution sertifikasına izin veriyor; her run'da yeniden üretmek bu limiti hızla doldurur.

Bu yaklaşımın tek riski: App Store Connect API key'inizin rolü **Admin** değilse (App Manager/Developer gibi daha kısıtlı bir roldeyse), sertifika oluşturma adımı Apple tarafından reddedilir. Bu durumda App Store Connect → Users and Access → Integrations → App Store Connect API üzerinden key'in rolünü Admin'e yükseltmeniz gerekir — bu tek değişiklik dışında sizin tarafınızdan yapılacak bir şey yok.

Notlar
- CI, `update_code_signing_settings` ile projeyi otomatik imzalamadan (Xcode hesabı gerektirir, CI'da yok) manuel imzalamaya, oluşturulan/önbellekten okunan profile geçirir; bu adım olmadan CI'da imzalama başarısız olurdu.
- Build number çakışmasını (App Store Connect "this build number has already been used" hatası) önlemek için her çalıştırmada `github.run_number` otomatik build number olarak kullanılır; `workflow_dispatch` ile manuel tetiklerken isterseniz `build_number` girdisiyle override edebilirsiniz.
- TestFlight'a yüklemek için App Store Connect API key yeterlidir, Apple ID şifresi gerekmez.
- Sertifikayı elle rotate etmek isterseniz: GitHub → Actions sekmesinde bu repo için kayıtlı `ios-signing-v1` cache'ini silin (`gh cache delete ios-signing-v1` ya da Settings → Actions → Caches), bir sonraki çalıştırma sıfırdan yeni bir sertifika/profil üretir.
- İleride ayrı bir sertifika deposu (match) kullanmak isterseniz `MATCH_GIT_URL`/`MATCH_PASSWORD` secret'larını eklemeniz yeterli — Fastfile otomatik olarak o yola geçer.
