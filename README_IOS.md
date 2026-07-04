iOS Release (no local Xcode) — Guide

Aşağıdaki adımlar `Tactical Eleven: Idle Manager` uygulaması için Xcode olmadan iOS build/upload işlemlerini CI (GitHub Actions) ile yapmanızı sağlar.
Aşağıda gerekli adımlar ve GitHub Secrets listesi yer alıyor.

Gereken GitHub Secrets
- APP_STORE_CONNECT_KEY_ID: App Store Connect API key id
- APP_STORE_CONNECT_ISSUER_ID: App Store Connect issuer id
- APP_STORE_CONNECT_PRIVATE_KEY_BASE64: Base64 ile encode edilmiş .p8 private key
- MATCH_GIT_URL: (opsiyonel) match sertifika deposu git URL'si
- MATCH_PASSWORD: (opsiyonel) match repo şifresi
- BUNDLE_ID: uygulama bundle id (ör. com.yourcompany.tacticaleleven)
- TEAM_ID: Apple team id
- APPLE_ID: Apple developer account email

Adımlar (kısaca)
1) App Store Connect API Key oluşturun
   - App Store Connect → Users and Access → Keys → + → Issuer ID ve Key ID not alın, .p8 dosyasını indirin.
   - .p8 dosyasını base64'e çevirin:

```bash
base64 -i AuthKey_XXX.p8 | pbcopy
# veya
base64 AuthKey_XXX.p8 > authkey.base64
```

2) GitHub Secrets ekleyin
   - Repo → Settings → Secrets → New repository secret; yukarıdaki değişkenleri ekleyin.

3) (Opsiyonel) match kullanmak isterseniz sertifikalar için bir özel git reposu kurun ve `MATCH_GIT_URL` ve `MATCH_PASSWORD` ekleyin.

4) Workflow tetikleme
   - GitHub → Actions → iOS Build & TestFlight → Run workflow (veya push to main/master tetiklemesi)

Notlar
- CI sunucusu Xcode ve macOS üzerinde paketleri indirip `fastlane beta` çalıştıracak. Fastlane `match` ile sertifikaları çekip `build_ios_app` ile ipa oluşturur.
- TestFlight'a yüklemek için App Store Connect API key yeterlidir.

Eğer isterseniz ben GitHub Actions secrets listesini ve fastlane yapılandırmasını repoda sizin adınıza daha fazla özelleştiririm (ör. team id, bundle id, match repo).