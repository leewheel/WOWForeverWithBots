-- Classic 1.60: every realm serves one ruleset (super district), identified by its season (Cfg_SuperDistrict.ContentSetID):
-- 136 = PvP, 137 = Normal, 138 = Roleplay, 140 = Hardcore. The client joins the realm whose season matches the ruleset it picked.
ALTER TABLE `realmlist` ADD COLUMN `contentSetId` int unsigned NOT NULL DEFAULT 137 AFTER `Battlegroup`;
UPDATE `realmlist` SET `contentSetId` = 137 WHERE `id` = 70;
