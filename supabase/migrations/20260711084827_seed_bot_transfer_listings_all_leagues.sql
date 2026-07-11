-- "transfer listesine tüm liglerden oyuncular koy": loadTransferMarket()
-- was already an unscoped, all-leagues query client-side - the real
-- problem is only 2 of 39 leagues ever had ANY transfer_market rows
-- (a one-time manual seed), since nothing ever lists bot-club players.
-- This adds a small, repeatable pool of bot-club listings across every
-- league (up to 3 surplus players per bot club, priced around the same
-- rescaled market-value formula used elsewhere), and schedules it to
-- keep replenishing as listings get bought/withdrawn.
CREATE OR REPLACE FUNCTION public.seed_bot_transfer_listings()
RETURNS void AS $$
BEGIN
  INSERT INTO public.transfer_market (player_id, asking_price)
  SELECT player_id, asking_price FROM (
    SELECT
      p.id AS player_id,
      GREATEST(1, ROUND(((p.current_ability * 15000 + p.potential_ability * 5000 + p.age * 100)::numeric / 40) * (0.8 + random() * 0.5))) AS asking_price,
      ROW_NUMBER() OVER (PARTITION BY p.club_id ORDER BY random()) AS rn
    FROM public.players p
    JOIN public.clubs c ON c.id = p.club_id
    WHERE c.user_id IS NULL
      AND NOT EXISTS (SELECT 1 FROM public.transfer_market tm WHERE tm.player_id = p.id)
  ) ranked
  WHERE rn <= 3
  ON CONFLICT (player_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

SELECT public.seed_bot_transfer_listings();

SELECT cron.schedule(
  'seed-bot-transfer-listings',
  '0 6 * * *',
  $$SELECT public.seed_bot_transfer_listings();$$
);
