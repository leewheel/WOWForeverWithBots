-- WoW Classic 1.60.1.70009 ("WoW Forever"): full vanilla world, part 4/4 - gossip, vendors, trainers.
-- Requires 2026_09_28_10_world_vanilla_reset.sql (helper tables vmangos_world.va_*).
-- The Classic client only starts a service interaction (merchant, trainer, innkeeper, ...) through gossip: every service NPC gets
-- the gossip flag, a gossip menu (TC hides the gossip flag without one, Player::CanSeeGossipOn) and an option for its service.
-- VMaNGOS gossip conditions are not converted yet (options show unconditionally).
--   gossip option id   = 93000000 + menu * 32 + VMaNGOS option id;   service options = 94000000 + entry * 16 + OptionNpc
--   generated menus    = 91000000 + creature entry (text 68, generic greeting)
--   trainer id         = 1000000 + creature entry (class list + own list)

SET @MENU_BASE := 91000000, @OPT_BASE := 93000000, @SVC_BASE := 94000000, @TRAINER_BASE := 1000000;

-- leftovers of the Northshire-only import
DELETE FROM world.gossip_menu_option WHERE GossipOptionID BETWEEN 9000000 AND 9199999;
DELETE FROM world.creature_trainer WHERE TrainerID BETWEEN 60000 AND 69999;
DELETE FROM world.trainer_spell WHERE TrainerId BETWEEN 60000 AND 69999;
DELETE FROM world.trainer WHERE Id BETWEEN 60000 AND 69999;

-- ---------------------------------------------------------------------------------------------------------------------
-- Trainer spell lists first (the gossip part below needs to know every trainer):
-- class/profession list (npc_trainer_template via trainer_id) + own list (npc_trainer), build 5875 = 1.12.1.
-- VMaNGOS lists hold the "teach" spell; TC wants the learned spell (effect 36 LEARN_SPELL -> EffectTriggerSpell).
-- ---------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS vmangos_world.va_spell;
CREATE TABLE vmangos_world.va_spell AS
SELECT s.entry, s.effect1, s.effectTriggerSpell1 FROM vmangos_world.spell_template s
JOIN (SELECT entry, MAX(build) AS b FROM vmangos_world.spell_template WHERE build <= 5875 GROUP BY entry) l ON l.entry = s.entry AND l.b = s.build;
ALTER TABLE vmangos_world.va_spell ADD PRIMARY KEY (entry);

DROP TABLE IF EXISTS vmangos_world.va_trainer_spells;
CREATE TABLE vmangos_world.va_trainer_spells AS
SELECT t.entry AS creature, s.spell, s.spellcost, s.reqskill, s.reqskillvalue, s.reqlevel
FROM vmangos_world.va_creature_template t JOIN vmangos_world.va_entries e ON e.entry = t.entry
JOIN vmangos_world.npc_trainer_template s ON s.entry = t.trainer_id
WHERE t.trainer_id > 0 AND s.build_min <= 5875 AND s.build_max >= 5875
UNION ALL
SELECT s.entry, s.spell, s.spellcost, s.reqskill, s.reqskillvalue, s.reqlevel
FROM vmangos_world.npc_trainer s JOIN vmangos_world.va_entries e ON e.entry = s.entry
WHERE s.build_min <= 5875 AND s.build_max >= 5875;

DROP TABLE IF EXISTS vmangos_world.va_trainers;
CREATE TABLE vmangos_world.va_trainers (entry INT UNSIGNED PRIMARY KEY, trainer_type TINYINT UNSIGNED)
SELECT t.entry, t.trainer_type FROM vmangos_world.va_creature_template t JOIN (SELECT DISTINCT creature FROM vmangos_world.va_trainer_spells) s ON s.creature = t.entry;

UPDATE world.creature_template t JOIN vmangos_world.va_trainers n ON n.entry = t.entry
SET t.npcflag = t.npcflag | 1 | 16 | IF(n.trainer_type = 0, 32, IF(n.trainer_type = 2, 64, 0));

-- ---------------------------------------------------------------------------------------------------------------------
-- Gossip menus, options, texts
-- ---------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS vmangos_world.va_menus;
CREATE TABLE vmangos_world.va_menus (menu INT UNSIGNED PRIMARY KEY)
SELECT DISTINCT t.gossip_menu_id AS menu FROM vmangos_world.va_creature_template t JOIN vmangos_world.va_entries e ON e.entry = t.entry WHERE t.gossip_menu_id > 0;
-- sub menus reached through options
INSERT IGNORE INTO vmangos_world.va_menus (menu) SELECT DISTINCT o.action_menu_id FROM vmangos_world.gossip_menu_option o JOIN vmangos_world.va_menus m ON m.menu = o.menu_id WHERE o.action_menu_id > 0;
INSERT IGNORE INTO vmangos_world.va_menus (menu) SELECT DISTINCT o.action_menu_id FROM vmangos_world.gossip_menu_option o JOIN vmangos_world.va_menus m ON m.menu = o.menu_id WHERE o.action_menu_id > 0;
INSERT IGNORE INTO vmangos_world.va_menus (menu) SELECT DISTINCT o.action_menu_id FROM vmangos_world.gossip_menu_option o JOIN vmangos_world.va_menus m ON m.menu = o.menu_id WHERE o.action_menu_id > 0;

DELETE g FROM world.gossip_menu g JOIN vmangos_world.va_menus m ON m.menu = g.MenuID;
DELETE g FROM world.gossip_menu g WHERE g.MenuID BETWEEN @MENU_BASE AND @MENU_BASE + 999999;
DELETE o FROM world.gossip_menu_option o JOIN vmangos_world.va_menus m ON m.menu = o.MenuID;
DELETE o FROM world.gossip_menu_option o WHERE o.MenuID BETWEEN @MENU_BASE AND @MENU_BASE + 999999;

INSERT IGNORE INTO world.gossip_menu (MenuID, TextID, VerifiedBuild)
SELECT g.entry, g.text_id, 0 FROM vmangos_world.gossip_menu g JOIN vmangos_world.va_menus m ON m.menu = g.entry;

REPLACE INTO world.npc_text (ID, Probability0, Probability1, Probability2, Probability3, Probability4, Probability5, Probability6, Probability7,
    BroadcastTextID0, BroadcastTextID1, BroadcastTextID2, BroadcastTextID3, BroadcastTextID4, BroadcastTextID5, BroadcastTextID6, BroadcastTextID7, VerifiedBuild)
SELECT n.ID, n.Probability0, n.Probability1, n.Probability2, n.Probability3, n.Probability4, n.Probability5, n.Probability6, n.Probability7,
    n.BroadcastTextID0, n.BroadcastTextID1, n.BroadcastTextID2, n.BroadcastTextID3, n.BroadcastTextID4, n.BroadcastTextID5, n.BroadcastTextID6, n.BroadcastTextID7, 0
FROM vmangos_world.npc_text n JOIN (SELECT DISTINCT g.text_id FROM vmangos_world.gossip_menu g JOIN vmangos_world.va_menus m ON m.menu = g.entry) u ON u.text_id = n.ID;

-- VMaNGOS option_id -> TC GossipOptionNpc
INSERT IGNORE INTO world.gossip_menu_option (MenuID, GossipOptionID, OptionID, OptionNpc, OptionText, OptionBroadcastTextID, Language, Flags, ActionMenuID, ActionPoiID,
    GossipNpcOptionID, BoxCoded, BoxMoney, BoxText, BoxBroadcastTextID, SpellID, OverrideIconID, VerifiedBuild)
SELECT o.menu_id, @OPT_BASE + o.menu_id * 32 + o.id, o.id,
    CASE o.option_id WHEN 3 THEN 1 WHEN 15 THEN 1 WHEN 4 THEN 2 WHEN 5 THEN 3 WHEN 6 THEN 4 WHEN 7 THEN 4 WHEN 8 THEN 5 WHEN 9 THEN 6
        WHEN 10 THEN 7 WHEN 11 THEN 8 WHEN 12 THEN 9 WHEN 13 THEN 10 WHEN 14 THEN 12 WHEN 16 THEN 11 ELSE 0 END,
    o.option_text, o.option_broadcast_text, 0, 0, GREATEST(o.action_menu_id, 0), 0, NULL, o.box_coded, o.box_money, COALESCE(o.box_text, ''), o.box_broadcast_text,
    NULL, NULL, 0
FROM vmangos_world.gossip_menu_option o JOIN vmangos_world.va_menus m ON m.menu = o.menu_id;

-- creature -> menu: vanilla menu, or a generated one for service NPCs without a menu
DELETE c FROM world.creature_template_gossip c JOIN vmangos_world.va_entries e ON e.entry = c.CreatureID;
INSERT INTO world.creature_template_gossip (CreatureID, MenuID, VerifiedBuild)
SELECT t.entry, t.gossip_menu_id, 0 FROM vmangos_world.va_creature_template t JOIN vmangos_world.va_entries e ON e.entry = t.entry
WHERE t.gossip_menu_id > 0 AND EXISTS (SELECT 1 FROM world.gossip_menu g WHERE g.MenuID = t.gossip_menu_id);

-- service roles (TC npcflag bit -> GossipOptionNpc, text); vendors, trainers and the rest
DROP TABLE IF EXISTS vmangos_world.va_services;
CREATE TABLE vmangos_world.va_services (flag INT UNSIGNED, option_npc TINYINT UNSIGNED PRIMARY KEY, text VARCHAR(100));
INSERT INTO vmangos_world.va_services VALUES
    (128, 1, 'I want to browse your goods.'), (8192, 2, 'Show me where I can fly.'), (16, 3, 'I require training.'),
    (16384, 4, 'Return me to life.'), (65536, 5, 'Make this inn your home.'), (131072, 6, 'I would like to check my deposit box.'),
    (262144, 7, 'How do I form a guild?'), (524288, 8, 'I want to create a guild crest.'), (1048576, 9, 'I would like to go to the battleground.'),
    (2097152, 10, 'I would like to browse the auction house.'), (4194304, 12, 'I''d like to stable my pet here.');

DROP TABLE IF EXISTS vmangos_world.va_service_npcs;
CREATE TABLE vmangos_world.va_service_npcs (entry INT UNSIGNED, option_npc TINYINT UNSIGNED, text VARCHAR(100), PRIMARY KEY (entry, option_npc))
SELECT w.entry, s.option_npc, s.text FROM world.creature_template w JOIN vmangos_world.va_entries e ON e.entry = w.entry
JOIN vmangos_world.va_services s ON (w.npcflag & s.flag) <> 0;

INSERT INTO world.creature_template_gossip (CreatureID, MenuID, VerifiedBuild)
SELECT DISTINCT n.entry, @MENU_BASE + n.entry, 0 FROM vmangos_world.va_service_npcs n
LEFT JOIN world.creature_template_gossip c ON c.CreatureID = n.entry WHERE c.CreatureID IS NULL;
INSERT IGNORE INTO world.gossip_menu (MenuID, TextID, VerifiedBuild)
SELECT DISTINCT @MENU_BASE + n.entry, 68, 0 FROM vmangos_world.va_service_npcs n
JOIN world.creature_template_gossip c ON c.CreatureID = n.entry AND c.MenuID = @MENU_BASE + n.entry;

-- add the service option where the menu has none for it
INSERT IGNORE INTO world.gossip_menu_option (MenuID, GossipOptionID, OptionID, OptionNpc, OptionText, OptionBroadcastTextID, Language, Flags, ActionMenuID, ActionPoiID,
    GossipNpcOptionID, BoxCoded, BoxMoney, BoxText, BoxBroadcastTextID, SpellID, OverrideIconID, VerifiedBuild)
SELECT c.MenuID, @SVC_BASE + n.entry * 16 + n.option_npc,
    (SELECT COALESCE(MAX(o.OptionID), -1) FROM world.gossip_menu_option o WHERE o.MenuID = c.MenuID) + 1 + n.option_npc,
    n.option_npc, n.text, 0, 0, 0, 0, 0, NULL, 0, 0, '', 0, NULL, NULL, 0
FROM vmangos_world.va_service_npcs n JOIN world.creature_template_gossip c ON c.CreatureID = n.entry
WHERE NOT EXISTS (SELECT 1 FROM world.gossip_menu_option o WHERE o.MenuID = c.MenuID AND o.OptionNpc = n.option_npc);

-- gossip flag for every NPC with a menu
UPDATE world.creature_template w JOIN world.creature_template_gossip c ON c.CreatureID = w.entry JOIN vmangos_world.va_entries e ON e.entry = w.entry
SET w.npcflag = w.npcflag | 1;

-- ---------------------------------------------------------------------------------------------------------------------
-- Vendors: own list + vendor template list
-- ---------------------------------------------------------------------------------------------------------------------
DELETE v FROM world.npc_vendor v JOIN vmangos_world.va_entries e ON e.entry = v.entry;
INSERT IGNORE INTO world.npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, type, BonusListIDs, PlayerConditionID, IgnoreFiltering, VerifiedBuild)
SELECT v.entry, v.slot, v.item, v.maxcount, v.incrtime, 0, 1, NULL, 0, 0, 0
FROM vmangos_world.npc_vendor v JOIN vmangos_world.va_entries e ON e.entry = v.entry;
INSERT IGNORE INTO world.npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, type, BonusListIDs, PlayerConditionID, IgnoreFiltering, VerifiedBuild)
SELECT t.entry, 100 + v.slot, v.item, v.maxcount, v.incrtime, 0, 1, NULL, 0, 0, 0
FROM vmangos_world.va_creature_template t JOIN vmangos_world.va_entries e ON e.entry = t.entry
JOIN vmangos_world.npc_vendor_template v ON v.entry = t.vendor_id WHERE t.vendor_id > 0;

-- ---------------------------------------------------------------------------------------------------------------------
-- Trainer lists
-- ---------------------------------------------------------------------------------------------------------------------
DELETE FROM world.trainer_spell WHERE TrainerId BETWEEN @TRAINER_BASE AND @TRAINER_BASE + 999999;
DELETE FROM world.trainer WHERE Id BETWEEN @TRAINER_BASE AND @TRAINER_BASE + 999999;
INSERT INTO world.trainer (Id, Type, Greeting, VerifiedBuild)
SELECT @TRAINER_BASE + n.entry, n.trainer_type, COALESCE(g.content_default, ''), 0
FROM vmangos_world.va_trainers n LEFT JOIN vmangos_world.npc_trainer_greeting g ON g.entry = n.entry;

INSERT IGNORE INTO world.trainer_spell (TrainerId, SpellId, MoneyCost, ReqSkillLine, ReqSkillRank, ReqAbility1, ReqAbility2, ReqAbility3, ReqLevel, VerifiedBuild)
SELECT @TRAINER_BASE + x.creature, x.learned, x.spellcost, x.reqskill, x.reqskillvalue, COALESCE(c.prev_spell, 0), 0, 0, x.reqlevel, 0
FROM (
    SELECT s.creature, IF(p.effect1 = 36 AND p.effectTriggerSpell1 > 0, p.effectTriggerSpell1, s.spell) AS learned, s.spellcost, s.reqskill, s.reqskillvalue, s.reqlevel
    FROM vmangos_world.va_trainer_spells s LEFT JOIN vmangos_world.va_spell p ON p.entry = s.spell
) x
LEFT JOIN (SELECT spell_id, ANY_VALUE(prev_spell) AS prev_spell FROM vmangos_world.spell_chain WHERE build_min <= 5875 AND build_max >= 5875 GROUP BY spell_id) c ON c.spell_id = x.learned;

-- trainer window opens from the menu's trainer option
DELETE c FROM world.creature_trainer c JOIN vmangos_world.va_entries e ON e.entry = c.CreatureID;
INSERT IGNORE INTO world.creature_trainer (CreatureID, TrainerID, MenuID, OptionID)
SELECT n.entry, @TRAINER_BASE + n.entry, o.MenuID, o.OptionID
FROM vmangos_world.va_trainers n
JOIN world.creature_template_gossip c ON c.CreatureID = n.entry
JOIN world.gossip_menu_option o ON o.MenuID = c.MenuID AND o.OptionNpc = 3;
