-- WoW Classic 1.60.1.70009: vanilla trainers for the imported Northshire creatures (VMaNGOS npc_trainer_template, build 5875 = 1.12.1).
-- Requires 2026_09_27_01_world_classic_northshire.sql (helper tables vmangos_world.ns_*).
-- VMaNGOS trainer lists hold the "teach" spell; the learned spell (effect 36 = LEARN_SPELL, EffectTriggerSpell) is what TC's trainer_spell wants.

SET @TRAINER_BASE := 60000;          -- trainer.Id = base + VMaNGOS trainer_id
SET @GOSSIP_OPTION_BASE := 9000000;  -- gossip_menu_option.GossipOptionID = base + creature entry

DROP TABLE IF EXISTS vmangos_world.ns_spell;
CREATE TABLE vmangos_world.ns_spell AS
SELECT s.entry, s.effect1, s.effectTriggerSpell1 FROM vmangos_world.spell_template s
JOIN (SELECT entry, MAX(build) AS b FROM vmangos_world.spell_template WHERE build <= 5875 GROUP BY entry) l ON l.entry = s.entry AND l.b = s.build;
ALTER TABLE vmangos_world.ns_spell ADD PRIMARY KEY (entry);

DROP TABLE IF EXISTS vmangos_world.ns_trainers;
CREATE TABLE vmangos_world.ns_trainers (entry INT UNSIGNED PRIMARY KEY, trainer_id INT UNSIGNED, trainer_type TINYINT UNSIGNED)
SELECT t.entry, t.trainer_id, t.trainer_type FROM vmangos_world.ns_creature_template t JOIN vmangos_world.ns_entries e ON e.entry = t.entry WHERE t.trainer_id > 0;

-- trainer lists
DELETE t FROM world.trainer t JOIN (SELECT DISTINCT trainer_id FROM vmangos_world.ns_trainers) n ON t.Id = @TRAINER_BASE + n.trainer_id;
INSERT INTO world.trainer (Id, Type, Greeting, VerifiedBuild)
SELECT DISTINCT @TRAINER_BASE + n.trainer_id, n.trainer_type, COALESCE(g.content_default, ''), 0
FROM vmangos_world.ns_trainers n LEFT JOIN vmangos_world.npc_trainer_greeting g ON g.entry = n.entry;

DELETE s FROM world.trainer_spell s JOIN (SELECT DISTINCT trainer_id FROM vmangos_world.ns_trainers) n ON s.TrainerId = @TRAINER_BASE + n.trainer_id;
INSERT IGNORE INTO world.trainer_spell (TrainerId, SpellId, MoneyCost, ReqSkillLine, ReqSkillRank, ReqAbility1, ReqAbility2, ReqAbility3, ReqLevel, VerifiedBuild)
SELECT @TRAINER_BASE + x.entry, x.learned, x.spellcost, x.reqskill, x.reqskillvalue, COALESCE(c.prev_spell, 0), 0, 0, x.reqlevel, 0
FROM (
    SELECT t.entry, IF(s.effect1 = 36 AND s.effectTriggerSpell1 > 0, s.effectTriggerSpell1, t.spell) AS learned, t.spellcost, t.reqskill, t.reqskillvalue, t.reqlevel
    FROM vmangos_world.npc_trainer_template t
    JOIN (SELECT DISTINCT trainer_id FROM vmangos_world.ns_trainers) n ON n.trainer_id = t.entry
    LEFT JOIN vmangos_world.ns_spell s ON s.entry = t.spell
    WHERE t.build_min <= 5875 AND t.build_max >= 5875
) x
LEFT JOIN (SELECT spell_id, ANY_VALUE(prev_spell) AS prev_spell FROM vmangos_world.spell_chain WHERE build_min <= 5875 AND build_max >= 5875 GROUP BY spell_id) c ON c.spell_id = x.learned;

-- "I require training." option in each trainer's gossip menu, linked to its trainer list
DELETE o FROM world.gossip_menu_option o JOIN vmangos_world.ns_trainers n ON o.GossipOptionID = @GOSSIP_OPTION_BASE + n.entry;
INSERT INTO world.gossip_menu_option (MenuID, GossipOptionID, OptionID, OptionNpc, OptionText, OptionBroadcastTextID, Language, Flags, ActionMenuID, ActionPoiID,
    GossipNpcOptionID, BoxCoded, BoxMoney, BoxText, BoxBroadcastTextID, SpellID, OverrideIconID, VerifiedBuild)
SELECT g.MenuID, @GOSSIP_OPTION_BASE + n.entry, (SELECT COALESCE(MAX(o.OptionID) + 1, 0) FROM world.gossip_menu_option o WHERE o.MenuID = g.MenuID),
    3, 'I require training.', 0, 0, 0, 0, 0, NULL, 0, 0, '', 0, NULL, NULL, 0
FROM vmangos_world.ns_trainers n JOIN world.creature_template_gossip g ON g.CreatureID = n.entry;

DELETE c FROM world.creature_trainer c JOIN vmangos_world.ns_trainers n ON n.entry = c.CreatureID;
INSERT INTO world.creature_trainer (CreatureID, TrainerID, MenuID, OptionID)
SELECT n.entry, @TRAINER_BASE + n.trainer_id, o.MenuID, o.OptionID
FROM vmangos_world.ns_trainers n JOIN world.gossip_menu_option o ON o.GossipOptionID = @GOSSIP_OPTION_BASE + n.entry;

-- NPC flags: gossip + trainer (+ class trainer / profession trainer)
UPDATE world.creature_template t JOIN vmangos_world.ns_trainers n ON n.entry = t.entry
SET t.npcflag = t.npcflag | 0x1 | 0x10 | IF(n.trainer_type = 0, 0x20, IF(n.trainer_type = 2, 0x40, 0));
