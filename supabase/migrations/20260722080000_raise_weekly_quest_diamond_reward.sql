-- Raise every weekly quest's diamond reward to a flat 15 (previously
-- 0/1/1/2/0/2 depending on the quest) - makes the diamond payout
-- meaningfully bigger regardless of which 3 quests a user is assigned
-- that week, instead of some weeks having zero diamond upside at all.
UPDATE public.weekly_quest_definitions SET diamond_reward = 15;
