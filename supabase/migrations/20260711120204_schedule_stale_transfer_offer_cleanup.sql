-- process_stale_transfer_offers() (3 günden eski bekleyen teklifleri
-- otomatik reddedip blocked_budget'ı iade eden fonksiyon) hiçbir cron
-- job'a bağlı değildi - fonksiyon vardı ama hiç otomatik çalışmıyordu,
-- süresiz bekleyen teklifler alıcı kulübün bütçesini süresiz kilitli
-- tutabiliyordu. Günde bir kez (diğer günlük işlerle çakışmayan bir
-- saatte) çalıştırıyoruz.
SELECT cron.schedule(
  'process-stale-transfer-offers',
  '0 4 * * *',
  $$SELECT public.process_stale_transfer_offers();$$
);
