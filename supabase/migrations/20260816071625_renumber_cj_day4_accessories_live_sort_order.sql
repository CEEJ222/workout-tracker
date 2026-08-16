-- Retiring Cable Chest Fly (sort_order 0) and Reverse Pec Deck (sort_order 1)
-- in CJ's Day 4 · Upper Accessories block (2f74ad2c-6b18-4e94-b575-9b02d2216ddb)
-- left the LIVE rows colliding with the retired rows on 0 and 1. With retired
-- rows filtered out of prescription display the live sequence is well-defined,
-- but the collision makes ordering undefined the moment anything reads retired
-- rows again. Pin the three LIVE rows to a clean, contiguous 0,1,2.
--
-- Retired rows are deliberately left alone: their sort_order no longer affects
-- any display, and changing them risks nothing useful (see CLAUDE.md — retired
-- hides from FUTURE prescription, never from past history).
--
-- Keyed by row id and idempotent: the live rows already sit at 0,1,2, so this
-- makes the intended order explicit and durable rather than incidental. On a
-- fresh replay before these user-authored rows exist, each UPDATE simply
-- affects zero rows.
update public.template_exercises set sort_order = 0
  where id = 'f8b475cb-fa8b-49a9-a9a1-c440d9198869';  -- Neutral-grip lat pulldown
update public.template_exercises set sort_order = 1
  where id = 'b35007bd-d7e1-48eb-aae8-bf005f7ad1b2';  -- Cable Face Pull
update public.template_exercises set sort_order = 2
  where id = '76ef687c-1f08-431e-9b93-de209118f8c0';  -- Scaption (full-can)