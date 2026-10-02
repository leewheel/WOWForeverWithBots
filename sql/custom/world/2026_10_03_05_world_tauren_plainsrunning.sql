-- Classic 1.60: Tauren racial Plainsrunning (1259918) stacks Plainsrunning speed (1299038) while moving (classic_spell_plainsrunning).
-- Safe to run again.
DELETE FROM `spell_script_names` WHERE `spell_id` = 1259918;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (1259918, 'classic_spell_plainsrunning');
