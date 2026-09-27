-- WoW Classic 1.60.1.70009: vanilla vendors for the imported Northshire creatures (VMaNGOS npc_vendor).
-- Requires 2026_09_27_01_world_classic_northshire.sql (helper tables vmangos_world.ns_*).
-- The Classic client does not open a merchant for NPCs that only carry the vendor flag: vendors get the gossip flag and a
-- gossip menu with a "browse goods" option (same path trainers use).

SET @MENU_BASE := 91000000;            -- gossip_menu.MenuID = base + creature entry (only for vendors without a menu)
SET @GOSSIP_OPTION_BASE := 9100000;    -- gossip_menu_option.GossipOptionID = base + creature entry

DROP TABLE IF EXISTS vmangos_world.ns_vendors;
CREATE TABLE vmangos_world.ns_vendors (entry INT UNSIGNED PRIMARY KEY, npc_flags INT UNSIGNED)
SELECT t.entry, t.npc_flags FROM vmangos_world.ns_creature_template t JOIN vmangos_world.ns_entries e ON e.entry = t.entry WHERE t.npc_flags & 0x4;

-- item lists
DELETE v FROM world.npc_vendor v JOIN vmangos_world.ns_vendors n ON n.entry = v.entry;
INSERT IGNORE INTO world.npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, type, BonusListIDs, PlayerConditionID, IgnoreFiltering, VerifiedBuild)
SELECT v.entry, v.slot, v.item, v.maxcount, v.incrtime, 0, 1, NULL, 0, 0, 0
FROM vmangos_world.npc_vendor v JOIN vmangos_world.ns_vendors n ON n.entry = v.entry;

-- gossip menu for vendors that have none (text 68 = generic greeting)
INSERT INTO world.creature_template_gossip (CreatureID, MenuID, VerifiedBuild)
SELECT n.entry, @MENU_BASE + n.entry, 0 FROM vmangos_world.ns_vendors n
LEFT JOIN world.creature_template_gossip c ON c.CreatureID = n.entry WHERE c.CreatureID IS NULL;
-- the menu itself must exist too, otherwise TC hides the gossip flag (Player::CanSeeGossipOn)
DELETE g FROM world.gossip_menu g JOIN vmangos_world.ns_vendors n ON g.MenuID = @MENU_BASE + n.entry;
INSERT INTO world.gossip_menu (MenuID, TextID, VerifiedBuild)
SELECT c.MenuID, 68, 0 FROM vmangos_world.ns_vendors n JOIN world.creature_template_gossip c ON c.CreatureID = n.entry AND c.MenuID = @MENU_BASE + n.entry;

-- "browse goods" option
DELETE o FROM world.gossip_menu_option o JOIN vmangos_world.ns_vendors n ON o.GossipOptionID = @GOSSIP_OPTION_BASE + n.entry;
INSERT INTO world.gossip_menu_option (MenuID, GossipOptionID, OptionID, OptionNpc, OptionText, OptionBroadcastTextID, Language, Flags, ActionMenuID, ActionPoiID,
    GossipNpcOptionID, BoxCoded, BoxMoney, BoxText, BoxBroadcastTextID, SpellID, OverrideIconID, VerifiedBuild)
SELECT c.MenuID, @GOSSIP_OPTION_BASE + n.entry, (SELECT COALESCE(MAX(o.OptionID) + 1, 0) FROM world.gossip_menu_option o WHERE o.MenuID = c.MenuID),
    1, 'I want to browse your goods.', 0, 0, 0, 0, 0, NULL, 0, 0, '', 0, NULL, NULL, 0
FROM vmangos_world.ns_vendors n JOIN world.creature_template_gossip c ON c.CreatureID = n.entry;

-- flags: gossip + vendor (+ repair when the vanilla vendor could repair: 1.12 flag 0x4000)
UPDATE world.creature_template t JOIN vmangos_world.ns_vendors n ON n.entry = t.entry
SET t.npcflag = t.npcflag | 0x1 | 0x80 | IF(n.npc_flags & 0x4000, 0x1000, 0);
