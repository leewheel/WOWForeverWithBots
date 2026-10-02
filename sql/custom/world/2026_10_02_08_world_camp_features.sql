-- Re-run after the sniff files (2026_10_01_03/04, 2026_10_02_00/06) were regenerated on 2026-10-03: they rewrite rows this file adjusts.
-- Classic 1.60 (WoW Forever) camp features: sitting in a Camp Chair (612275) next to a campfire also starts the campfire rest
-- (classic_go_camp_chair); the buffs of the features near the fire are handled by classic_spell_campfire_rest
UPDATE `gameobject_template` SET `ScriptName` = 'classic_go_camp_chair' WHERE `entry` = 612275;
