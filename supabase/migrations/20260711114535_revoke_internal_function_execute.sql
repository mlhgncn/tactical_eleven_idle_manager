-- Kapsamlı denetimde bulunan 3 güvenlik açığı: bu fonksiyonlar sadece
-- BAŞKA bir SECURITY DEFINER fonksiyon (ya da servis rolü/cron) tarafından
-- çağrılmak üzere tasarlanmıştı, ama authenticated/anon rollerine EXECUTE
-- izni açık kalmıştı - yani her kullanıcı bunları doğrudan .rpc() ile
-- çağırabiliyordu:
--   * get_secret: CRON_SHARED_SECRET dahil tüm environment_secrets'ı
--     hiçbir yetki kontrolü olmadan herkese (anon dahil) döndürüyordu.
--   * _resolve_transfer_offer: respond_to_transfer_offer'ın sarmaladığı
--     asıl transfer mantığı - sahiplik kontrolü yok, doğrudan çağrılırsa
--     herkes başkasının teklifini "kabul ettirip" para/oyuncu taşıyabilir.
--   * _insert_generated_player: sınırsız sayıda istenen güçte oyuncu
--     üretip istenen kulübe ekleyebiliyordu.
--
-- REVOKE, bu fonksiyonları SADECE dışarıdan (authenticated/anon rolüyle
-- doğrudan .rpc() çağrısı) erişilemez yapar. İçeriden - başka bir
-- SECURITY DEFINER fonksiyonun (postgres/owner bağlamında) çağırması -
-- etkilenmez, çünkü definer context kendi fonksiyonuna zaten EXECUTE
-- yetkisine sahiptir (owner). Aynı desen daha önce
-- update_standings_after_match için uygulanmış ve doğrulanmıştı.
REVOKE EXECUTE ON FUNCTION public.get_secret(text) FROM PUBLIC, authenticated, anon;
REVOKE EXECUTE ON FUNCTION public._resolve_transfer_offer(uuid, boolean) FROM PUBLIC, authenticated, anon;
REVOKE EXECUTE ON FUNCTION public._insert_generated_player(uuid, integer, integer) FROM PUBLIC, authenticated, anon;
