-- Classic 1.60 (WoW Forever) "The Great Outdoors" and "Camping 101":
-- sitting near a campfire for a minute gives Boosted Rest (1229451) through the rest aura 1289723 (classic_spell_campfire_rest;
-- the sit itself is handled in WorldSession::HandleStandStateChangeOpcode)
DELETE FROM `spell_script_names` WHERE `spell_id` = 1289723;
INSERT INTO `spell_script_names` (`spell_id`,`ScriptName`) VALUES (1289723,'classic_spell_campfire_rest');

-- the profession follow-ups of the camping trainer (263664) are only offered to players who know that profession, after
-- "The Great Outdoors" (96101); "Camping 101: Cooking" teaches cooking, so it stays open to everyone
INSERT INTO `quest_template_addon` (`ID`,`PrevQuestID`,`RequiredSkillID`,`RequiredSkillPoints`) VALUES
(97923,96101,186,1),    -- Camping 101: Mining
(97965,96101,129,1),    -- Camping 101: First Aid
(97967,96101,356,1),    -- Camping 101: Fishing
(97969,96101,165,1),    -- Camping 101: Leatherworking
(97971,96101,393,1)     -- Camping 101: Skinning
ON DUPLICATE KEY UPDATE `PrevQuestID` = VALUES(`PrevQuestID`), `RequiredSkillID` = VALUES(`RequiredSkillID`),
`RequiredSkillPoints` = VALUES(`RequiredSkillPoints`);
