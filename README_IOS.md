iOS Release (no local Xcode) — Guide

`Tactical Eleven: Idle Manager` uygulamasının iOS build/imzalama/TestFlight yükleme işlerinin tamamı GitHub Actions'ın macOS runner'ı üzerinde çalışır. Xcode hiçbir zaman sizin bilgisayarınıza kurulmaz — Windows'tan bu depoya push attığınızda ya da workflow'u elle tetiklediğinizde, CI kendi macOS makinesinde Xcode'u kullanarak derler ve imzalar; siz sadece sonucu (TestFlight'taki build'i) görürsünüz.

İki workflow var, ikisi de macOS'ta yalnızca GitHub'ın bulut runner'ında çalışır — **hiçbir aşamada bir Mac'e ihtiyacınız yok**, kiralık Mac servisi de gerekmiyor:

1. `.github/workflows/ios_match_setup.yml` — **bir kerelik** kurulum. Apple Developer hesabınızda bir Distribution sertifikası + App Store provisioning profile oluşturur ve bunları şifreli biçimde `MATCH_GIT_URL` deposuna yazar. Yanlışlıkla tetiklenmesin diye `workflow_dispatch` girdisine "YES" yazmanızı zorunlu kılar.
2. `.github/workflows/ios_release.yml` — asıl release workflow'u. `main`/`master`'a her push'ta ya da elle tetiklendiğinde çalışır:
   - **Analyze & Test** (ubuntu, hızlı) — `flutter analyze` + `flutter test` başarısız olursa build hiç başlamaz.
   - **Build IPA and upload to TestFlight** (macos-15) — Flutter + CocoaPods kurar, `match`'i **salt okunur** modda çalıştırıp (1)'de oluşturulan sertifika/profili çeker, `fastlane ios beta` lane'i ile derler ve TestFlight'a yükler.

Gereken GitHub Secrets (tam liste: [GITHUB_SECRETS.md](GITHUB_SECRETS.md))
- APP_STORE_CONNECT_KEY_ID / APP_STORE_CONNECT_ISSUER_ID / APP_STORE_CONNECT_PRIVATE_KEY_BASE64: App Store Connect API key. Hem TestFlight yüklemesi hem de match'in Apple Developer Portal'a girişi için kullanılır — Apple ID şifresi veya 2FA kodu **hiç gerekmez**.
- MATCH_GIT_URL / MATCH_PASSWORD: sertifika/profil deposu (aşağıya bakın)
- BUNDLE_ID, TEAM_ID, APPLE_ID (APPLE_ID sadece etiketleme amaçlı, kimlik doğrulaması API key ile yapılıyor)

Adımlar (hepsi tarayıcıdan + GitHub Actions'tan yapılır)
1) App Store Connect API Key oluşturun
   - App Store Connect (web) → Users and Access → Integrations → App Store Connect API → + → **Admin** yetkisiyle bir key oluşturun (sertifika oluşturmak için Admin rolü gerekiyor; Developer/App Manager rolündeki key'ler match'in cert/profile oluşturma adımını reddeder). Issuer ID ve Key ID'yi not alın, `.p8` dosyasını indirin (yalnızca bir kez indirilebilir).
   - `.p8` dosyasını base64'e çevirin (PowerShell, Mac gerekmez):
     ```powershell
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXX.p8"))
     ```

2) match için boş bir private repo oluşturun (GitHub web arayüzünden, ör. `tactical-eleven-signing`). Bu repoyu bu proje reposundan farklı, ayrı bir private repo olarak açın.
   - Eğer bu repo aynı GitHub hesabında ama bu projenin reposundan farklıysa, CI'nin ona push/pull edebilmesi için bir **Personal Access Token** (Settings → Developer settings → Fine-grained tokens; sadece o signing reposuna `Contents: Read and write` izni yeterli) oluşturup `MATCH_GIT_BASIC_AUTHORIZATION` secret'ına `base64("kullaniciadi:TOKEN")` olarak koyun.
   - `MATCH_GIT_URL` = o reponun HTTPS URL'si (ör. `https://github.com/<user>/tactical-eleven-signing.git`).
   - `MATCH_PASSWORD` = match'in dosyaları şifrelemek için kullanacağı, sizin belirleyeceğiniz güçlü bir parola (bir yere not edin, kaybederseniz mevcut sertifikaları tekrar okuyamazsınız).

3) Yukarıdaki tüm secret'ları GitHub Secrets'a ekleyin: Repo → Settings → Secrets and variables → Actions → New repository secret ([GITHUB_SECRETS.md](GITHUB_SECRETS.md) listesine göre).

4) **Bir kerelik sertifika kurulumu**: GitHub → Actions → "iOS Signing Setup (one-time)" → Run workflow → `confirm` alanına `YES` yazın → çalıştırın. Bu, GitHub'ın macOS runner'ında sertifika/profili oluşturup signing reponuza yazar. Başarılı biterse bir daha çalıştırmanıza gerek yok (sertifika süresi dolana ya da elle rotate etmek isteyene kadar).

5) Release workflow'unu tetikleyin: GitHub → Actions → "iOS Build & TestFlight" → Run workflow (veya main/master'a push).

Notlar
- CI, `update_code_signing_settings` ile projeyi otomatik imzalamadan (Xcode hesabı gerektirir, CI'da yok) match'in getirdiği manuel profile geçirir; bu adım olmadan CI'da imzalama başarısız olurdu.
- Build number çakışmasını (App Store Connect "this build number has already been used" hatası) önlemek için her çalıştırmada `github.run_number` otomatik build number olarak kullanılır; `workflow_dispatch` ile manuel tetiklerken isterseniz `build_number` girdisiyle override edebilirsiniz.
- TestFlight'a yüklemek için App Store Connect API key yeterlidir, Apple ID şifresi gerekmez.
- Adım 4'teki workflow gerçek Apple Developer hesabınızda kalıcı bir sertifika/profil oluşturur — Apple, hesap başına en fazla 3 aktif Distribution sertifikasına izin verir, bu yüzden bu workflow'u gereksiz yere tekrar tekrar çalıştırmayın.