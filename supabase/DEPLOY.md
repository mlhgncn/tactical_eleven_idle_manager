Supabase Production Deployment

Bu projede `supabase/schema.sql` dosyası mevcut ve üretim veritabanı için kullanılabilir.

Adımlar
1) Supabase'te yeni bir proje oluşturun (prod environment).
2) Proje dashboard → SQL Editor → `supabase/schema.sql` içeriğini çalıştırın.
3) Environment değişkenleri ve servis anahtarları:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY` (kullanıcı uygulaması için publishable)
   - `SUPABASE_SERVICE_ROLE_KEY` (sadece backend/edge-fn içinde kullanın, mobil uygulamaya gömmeyin)

CLI ile deploy (tercih ederseniz)
- supabase CLI yüklüyse:
```bash
supabase db remote set <PROJECT_REF>
supabase db push --file supabase/schema.sql
```

RLS & Güvenlik
- `anon` rolünün hangi sorguları yapabileceğini kısıtlayın.
- Önemli: `service_role` anahtarını client uygulamaya asla gömmeyin.

Eğer isterseniz, bu dosyayı otomatik olarak Supabase projesine uygulayacak bir GitHub Action da ekleyebilirim.