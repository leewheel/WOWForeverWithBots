-- WoW Classic 1.60.1.70009 ("WoW Forever"): replace the retail (Cataclysm) Northshire Valley with vanilla 1.12 data from VMaNGOS.
-- Requires the VMaNGOS world database imported as schema `vmangos_world` (release db_latest, GPL-2) on the same MySQL server.
-- Area: map 0, x -9200..-8600, y -500..250. VMaNGOS rows are filtered to patch 1.12 (patch index 10).

SET @XMIN := -9200, @XMAX := -8600, @YMIN := -500, @YMAX := 250;
SET @GUID_BASE := 20000000;        -- new creature/gameobject guids = base + VMaNGOS guid
SET @OBJECTIVE_BASE := 90000000;   -- quest_objectives.ID = base + quest * 10 + index
SET @REF_BASE := 900000;           -- reference_loot_template entries = base + VMaNGOS reference id

-- ---------------------------------------------------------------------------------------------------------------------
-- Helper tables (in vmangos_world): 1.12 rows only
-- ---------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS vmangos_world.ns_creature_template;
CREATE TABLE vmangos_world.ns_creature_template AS
SELECT t.* FROM vmangos_world.creature_template t
JOIN (SELECT entry, MAX(patch) AS p FROM vmangos_world.creature_template WHERE patch <= 10 GROUP BY entry) l ON l.entry = t.entry AND l.p = t.patch;
ALTER TABLE vmangos_world.ns_creature_template ADD PRIMARY KEY (entry);

DROP TABLE IF EXISTS vmangos_world.ns_quest_template;
CREATE TABLE vmangos_world.ns_quest_template AS
SELECT q.* FROM vmangos_world.quest_template q
JOIN (SELECT entry, MAX(patch) AS p FROM vmangos_world.quest_template WHERE patch <= 10 GROUP BY entry) l ON l.entry = q.entry AND l.p = q.patch;
ALTER TABLE vmangos_world.ns_quest_template ADD PRIMARY KEY (entry);

DROP TABLE IF EXISTS vmangos_world.ns_creature;
CREATE TABLE vmangos_world.ns_creature AS
SELECT * FROM vmangos_world.creature
WHERE map = 0 AND position_x BETWEEN @XMIN AND @XMAX AND position_y BETWEEN @YMIN AND @YMAX AND patch_min <= 10 AND patch_max >= 10;

DROP TABLE IF EXISTS vmangos_world.ns_gameobject;
CREATE TABLE vmangos_world.ns_gameobject AS
SELECT g.* FROM vmangos_world.gameobject g
JOIN world.gameobject_template t ON t.entry = g.id
WHERE g.map = 0 AND g.position_x BETWEEN @XMIN AND @XMAX AND g.position_y BETWEEN @YMIN AND @YMAX AND g.patch_min <= 10 AND g.patch_max >= 10;

DROP TABLE IF EXISTS vmangos_world.ns_entries;
CREATE TABLE vmangos_world.ns_entries (entry INT UNSIGNED PRIMARY KEY)
SELECT DISTINCT c.id AS entry FROM vmangos_world.ns_creature c JOIN world.creature_template w ON w.entry = c.id;

-- quests started or ended by Northshire creatures
DROP TABLE IF EXISTS vmangos_world.ns_quests;
CREATE TABLE vmangos_world.ns_quests (quest INT UNSIGNED PRIMARY KEY)
SELECT DISTINCT r.quest FROM (
    SELECT id, quest FROM vmangos_world.creature_questrelation WHERE patch_min <= 10 AND patch_max >= 10
    UNION SELECT id, quest FROM vmangos_world.creature_involvedrelation WHERE patch_min <= 10 AND patch_max >= 10) r
JOIN vmangos_world.ns_entries e ON e.entry = r.id
JOIN world.quest_template w ON w.ID = r.quest
JOIN vmangos_world.ns_quest_template q ON q.entry = r.quest;

-- ---------------------------------------------------------------------------------------------------------------------
-- Remove retail spawns in the area (and rows linked to them)
-- ---------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS vmangos_world.ns_old_creature;
CREATE TABLE vmangos_world.ns_old_creature (guid BIGINT UNSIGNED PRIMARY KEY)
SELECT guid FROM world.creature WHERE map = 0 AND position_x BETWEEN @XMIN AND @XMAX AND position_y BETWEEN @YMIN AND @YMAX;

DROP TABLE IF EXISTS vmangos_world.ns_old_gameobject;
CREATE TABLE vmangos_world.ns_old_gameobject (guid BIGINT UNSIGNED PRIMARY KEY)
SELECT guid FROM world.gameobject WHERE map = 0 AND position_x BETWEEN @XMIN AND @XMAX AND position_y BETWEEN @YMIN AND @YMAX;

DELETE a FROM world.creature_addon a JOIN vmangos_world.ns_old_creature o ON o.guid = a.guid;
DELETE f FROM world.creature_formations f JOIN vmangos_world.ns_old_creature o ON o.guid = f.memberGUID OR o.guid = f.leaderGUID;
DELETE e FROM world.game_event_creature e JOIN vmangos_world.ns_old_creature o ON o.guid = e.guid;
DELETE s FROM world.spawn_group s JOIN vmangos_world.ns_old_creature o ON o.guid = s.spawnId WHERE s.spawnType = 0;
DELETE p FROM world.pool_members p JOIN vmangos_world.ns_old_creature o ON o.guid = p.spawnId WHERE p.type = 0;
DELETE c FROM world.creature c JOIN vmangos_world.ns_old_creature o ON o.guid = c.guid;

DELETE a FROM world.gameobject_addon a JOIN vmangos_world.ns_old_gameobject o ON o.guid = a.guid;
DELETE e FROM world.game_event_gameobject e JOIN vmangos_world.ns_old_gameobject o ON o.guid = e.guid;
DELETE s FROM world.spawn_group s JOIN vmangos_world.ns_old_gameobject o ON o.guid = s.spawnId WHERE s.spawnType = 1;
DELETE p FROM world.pool_members p JOIN vmangos_world.ns_old_gameobject o ON o.guid = p.spawnId WHERE p.type = 1;
DELETE g FROM world.gameobject g JOIN vmangos_world.ns_old_gameobject o ON o.guid = g.guid;

-- ---------------------------------------------------------------------------------------------------------------------
-- Vanilla spawns (waypoint paths not imported yet: waypoint movers stand still)
-- ---------------------------------------------------------------------------------------------------------------------
INSERT INTO world.creature (guid, id, map, zoneId, areaId, spawnDifficulties, phaseUseFlags, PhaseId, PhaseGroup, terrainSwapMap, modelid,
    equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, currentwaypoint, curHealthPct, MovementType,
    npcflag, unit_flags, unit_flags2, unit_flags3, ScriptName, StringId, VerifiedBuild)
SELECT @GUID_BASE + c.guid, c.id, 0, 0, 0, '0', 0, 0, 0, -1, 0,
    IF(t.equipment_id > 0, 1, 0), c.position_x, c.position_y, c.position_z, c.orientation, c.spawntimesecsmin, c.wander_distance, 0, 100,
    IF(c.movement_type = 1, 1, 0), NULL, NULL, NULL, NULL, '', NULL, 0
FROM vmangos_world.ns_creature c
JOIN vmangos_world.ns_entries e ON e.entry = c.id
JOIN vmangos_world.ns_creature_template t ON t.entry = c.id;

INSERT INTO world.gameobject (guid, id, map, zoneId, areaId, spawnDifficulties, phaseUseFlags, PhaseId, PhaseGroup, terrainSwapMap,
    position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state, ScriptName, StringId, VerifiedBuild)
SELECT @GUID_BASE + g.guid, g.id, 0, 0, 0, '0', 0, 0, 0, -1,
    g.position_x, g.position_y, g.position_z, g.orientation, g.rotation0, g.rotation1, g.rotation2, g.rotation3, g.spawntimesecsmin, g.animprogress, g.state, '', NULL, 0
FROM vmangos_world.ns_gameobject g;

-- ---------------------------------------------------------------------------------------------------------------------
-- Creature models, equipment, levels, loot
-- ---------------------------------------------------------------------------------------------------------------------
DELETE m FROM world.creature_template_model m JOIN vmangos_world.ns_entries e ON e.entry = m.CreatureID;
INSERT INTO world.creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT entry, 0, display_id1, IF(display_scale1 > 0, display_scale1, 1), IF(display_probability1 > 0, display_probability1, 1), 0 FROM vmangos_world.ns_creature_template JOIN vmangos_world.ns_entries USING (entry) WHERE display_id1 > 0
UNION ALL SELECT entry, 1, display_id2, IF(display_scale2 > 0, display_scale2, 1), display_probability2, 0 FROM vmangos_world.ns_creature_template JOIN vmangos_world.ns_entries USING (entry) WHERE display_id2 > 0
UNION ALL SELECT entry, 2, display_id3, IF(display_scale3 > 0, display_scale3, 1), display_probability3, 0 FROM vmangos_world.ns_creature_template JOIN vmangos_world.ns_entries USING (entry) WHERE display_id3 > 0
UNION ALL SELECT entry, 3, display_id4, IF(display_scale4 > 0, display_scale4, 1), display_probability4, 0 FROM vmangos_world.ns_creature_template JOIN vmangos_world.ns_entries USING (entry) WHERE display_id4 > 0;

DELETE q FROM world.creature_equip_template q JOIN vmangos_world.ns_entries e ON e.entry = q.CreatureID;
INSERT INTO world.creature_equip_template (CreatureID, ID, ItemID1, AppearanceModID1, ItemVisual1, ItemID2, AppearanceModID2, ItemVisual2, ItemID3, AppearanceModID3, ItemVisual3, VerifiedBuild)
SELECT t.entry, 1, q.item1, 0, 0, q.item2, 0, 0, q.item3, 0, 0, 0
FROM vmangos_world.ns_creature_template t
JOIN vmangos_world.ns_entries e ON e.entry = t.entry
JOIN (SELECT entry, ANY_VALUE(item1) AS item1, ANY_VALUE(item2) AS item2, ANY_VALUE(item3) AS item3 FROM vmangos_world.creature_equip_template WHERE patch_min <= 10 AND patch_max >= 10 GROUP BY entry) q ON q.entry = t.equipment_id
WHERE t.equipment_id > 0;

CREATE TABLE IF NOT EXISTS world.creature_classic_level (
    entry INT UNSIGNED NOT NULL,
    level_min TINYINT UNSIGNED NOT NULL,
    level_max TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (entry)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Classic 1.60: fixed vanilla creature levels (replaces ContentTuning scaling)';
REPLACE INTO world.creature_classic_level (entry, level_min, level_max)
SELECT t.entry, t.level_min, t.level_max FROM vmangos_world.ns_creature_template t JOIN vmangos_world.ns_entries e ON e.entry = t.entry;

-- loot: vanilla tables for the imported creatures (loot id = VMaNGOS loot_id), references copied with an id offset
UPDATE world.creature_template_difficulty d
JOIN vmangos_world.ns_creature_template t ON t.entry = d.Entry
JOIN vmangos_world.ns_entries e ON e.entry = d.Entry
SET d.LootID = t.loot_id, d.SkinLootID = t.skinning_loot_id, d.PickPocketLootID = t.pickpocket_loot_id, d.GoldMin = t.gold_min, d.GoldMax = t.gold_max
WHERE d.DifficultyID = 0;

DROP TABLE IF EXISTS vmangos_world.ns_loot_ids;
CREATE TABLE vmangos_world.ns_loot_ids (id INT UNSIGNED PRIMARY KEY)
SELECT DISTINCT t.loot_id AS id FROM vmangos_world.ns_creature_template t JOIN vmangos_world.ns_entries e ON e.entry = t.entry WHERE t.loot_id > 0;

DELETE l FROM world.creature_loot_template l JOIN vmangos_world.ns_loot_ids i ON i.id = l.Entry;
INSERT IGNORE INTO world.creature_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT l.entry, IF(l.mincountOrRef < 0, 1, 0), IF(l.mincountOrRef < 0, @REF_BASE - l.mincountOrRef, l.item), ABS(l.ChanceOrQuestChance),
    l.ChanceOrQuestChance < 0, 1, l.groupid, IF(l.mincountOrRef < 0, 1, l.mincountOrRef), l.maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.creature_loot_template l JOIN vmangos_world.ns_loot_ids i ON i.id = l.entry
WHERE l.patch_min <= 10 AND l.patch_max >= 10;

DROP TABLE IF EXISTS vmangos_world.ns_ref_ids;
CREATE TABLE vmangos_world.ns_ref_ids (id INT UNSIGNED PRIMARY KEY)
SELECT DISTINCT -l.mincountOrRef AS id FROM vmangos_world.creature_loot_template l JOIN vmangos_world.ns_loot_ids i ON i.id = l.entry
WHERE l.mincountOrRef < 0 AND l.patch_min <= 10 AND l.patch_max >= 10;

DELETE r FROM world.reference_loot_template r JOIN vmangos_world.ns_ref_ids i ON r.Entry = @REF_BASE + i.id;
INSERT IGNORE INTO world.reference_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT @REF_BASE + l.entry, 0, l.item, ABS(l.ChanceOrQuestChance), l.ChanceOrQuestChance < 0, 1, l.groupid, l.mincountOrRef, l.maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.reference_loot_template l JOIN vmangos_world.ns_ref_ids i ON i.id = l.entry
WHERE l.mincountOrRef > 0 AND l.patch_min <= 10 AND l.patch_max >= 10;

-- ---------------------------------------------------------------------------------------------------------------------
-- Quests: vanilla text, objectives, rewards, chain; no auto-accept (retail flag 0x80000 dropped)
-- ---------------------------------------------------------------------------------------------------------------------
UPDATE world.quest_template w JOIN vmangos_world.ns_quest_template q ON q.entry = w.ID JOIN vmangos_world.ns_quests n ON n.quest = w.ID
SET w.LogTitle = q.Title, w.LogDescription = q.Objectives, w.QuestDescription = q.Details, w.AreaDescription = '', w.QuestCompletionLog = q.EndText,
    w.QuestSortID = q.ZoneOrSort, w.QuestInfoID = q.Type, w.SuggestedGroupNum = q.SuggestedPlayers, w.Flags = q.QuestFlags, w.FlagsEx = 0,
    w.RewardNextQuest = q.NextQuestInChain, w.StartItem = q.SrcItemId, w.RewardSpell = IF(q.RewSpellCast > 0, q.RewSpellCast, q.RewSpell),
    w.RewardItem1 = q.RewItemId1, w.RewardAmount1 = q.RewItemCount1, w.RewardItem2 = q.RewItemId2, w.RewardAmount2 = q.RewItemCount2,
    w.RewardItem3 = q.RewItemId3, w.RewardAmount3 = q.RewItemCount3, w.RewardItem4 = q.RewItemId4, w.RewardAmount4 = q.RewItemCount4,
    w.ItemDrop1 = q.ReqSourceId1, w.ItemDropQuantity1 = q.ReqSourceCount1, w.ItemDrop2 = q.ReqSourceId2, w.ItemDropQuantity2 = q.ReqSourceCount2,
    w.ItemDrop3 = q.ReqSourceId3, w.ItemDropQuantity3 = q.ReqSourceCount3, w.ItemDrop4 = q.ReqSourceId4, w.ItemDropQuantity4 = q.ReqSourceCount4,
    w.RewardChoiceItemID1 = q.RewChoiceItemId1, w.RewardChoiceItemQuantity1 = q.RewChoiceItemCount1, w.RewardChoiceItemDisplayID1 = 0,
    w.RewardChoiceItemID2 = q.RewChoiceItemId2, w.RewardChoiceItemQuantity2 = q.RewChoiceItemCount2, w.RewardChoiceItemDisplayID2 = 0,
    w.RewardChoiceItemID3 = q.RewChoiceItemId3, w.RewardChoiceItemQuantity3 = q.RewChoiceItemCount3, w.RewardChoiceItemDisplayID3 = 0,
    w.RewardChoiceItemID4 = q.RewChoiceItemId4, w.RewardChoiceItemQuantity4 = q.RewChoiceItemCount4, w.RewardChoiceItemDisplayID4 = 0,
    w.RewardChoiceItemID5 = q.RewChoiceItemId5, w.RewardChoiceItemQuantity5 = q.RewChoiceItemCount5, w.RewardChoiceItemDisplayID5 = 0,
    w.RewardChoiceItemID6 = q.RewChoiceItemId6, w.RewardChoiceItemQuantity6 = q.RewChoiceItemCount6, w.RewardChoiceItemDisplayID6 = 0,
    w.RewardFactionID1 = q.RewRepFaction1, w.RewardFactionValue1 = 0, w.RewardFactionOverride1 = q.RewRepValue1 * 100,
    w.RewardFactionID2 = q.RewRepFaction2, w.RewardFactionValue2 = 0, w.RewardFactionOverride2 = q.RewRepValue2 * 100,
    w.RewardFactionID3 = q.RewRepFaction3, w.RewardFactionValue3 = 0, w.RewardFactionOverride3 = q.RewRepValue3 * 100,
    w.RewardFactionID4 = q.RewRepFaction4, w.RewardFactionValue4 = 0, w.RewardFactionOverride4 = q.RewRepValue4 * 100,
    w.RewardFactionID5 = q.RewRepFaction5, w.RewardFactionValue5 = 0, w.RewardFactionOverride5 = q.RewRepValue5 * 100,
    w.TimeAllowed = q.LimitTime, w.AllowableRaces = IF(q.RequiredRaces = 0, 18446744073709551615, q.RequiredRaces),
    w.POIContinent = q.PointMapId, w.POIx = q.PointX, w.POIy = q.PointY, w.POIPriority = q.PointOpt;

REPLACE INTO world.quest_template_addon (ID, MaxLevel, AllowableClasses, SourceSpellID, PrevQuestID, NextQuestID, ExclusiveGroup, BreadcrumbForQuestId,
    RewardMailTemplateID, RewardMailDelay, RequiredSkillID, RequiredSkillPoints, RequiredMinRepFaction, RequiredMaxRepFaction, RequiredMinRepValue,
    RequiredMaxRepValue, ProvidedItemCount, SpecialFlags, ScriptName)
SELECT q.entry, 0, q.RequiredClasses, q.SrcSpell, q.PrevQuestId, q.NextQuestId, q.ExclusiveGroup, q.BreadcrumbForQuestId,
    q.RewMailTemplateId, q.RewMailDelaySecs, q.RequiredSkill, q.RequiredSkillValue, q.RequiredMinRepFaction, q.RequiredMaxRepFaction, q.RequiredMinRepValue,
    q.RequiredMaxRepValue, q.SrcItemCount, q.SpecialFlags & 1, ''
FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry;

REPLACE INTO world.quest_offer_reward (ID, Emote1, Emote2, Emote3, Emote4, EmoteDelay1, EmoteDelay2, EmoteDelay3, EmoteDelay4, RewardText, VerifiedBuild)
SELECT q.entry, q.OfferRewardEmote1, q.OfferRewardEmote2, q.OfferRewardEmote3, q.OfferRewardEmote4,
    q.OfferRewardEmoteDelay1, q.OfferRewardEmoteDelay2, q.OfferRewardEmoteDelay3, q.OfferRewardEmoteDelay4, q.OfferRewardText, 0
FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry;

REPLACE INTO world.quest_request_items (ID, EmoteOnComplete, EmoteOnIncomplete, EmoteOnCompleteDelay, EmoteOnIncompleteDelay, CompletionText, VerifiedBuild)
SELECT q.entry, q.CompleteEmote, q.IncompleteEmote, 0, 0, q.RequestItemsText, 0
FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry
WHERE q.RequestItemsText IS NOT NULL AND q.RequestItemsText <> '';

-- objectives: kill / gameobject (negative ReqCreatureOrGOId) first, then items
DELETE o FROM world.quest_objectives o JOIN vmangos_world.ns_quests n ON n.quest = o.QuestID;
INSERT INTO world.quest_objectives (ID, QuestID, Type, `Order`, StorageIndex, ObjectID, Amount, ConditionalAmount, Flags, Flags2, ProgressBarWeight, ParentObjectiveID, Visible, Description, VerifiedBuild)
SELECT @OBJECTIVE_BASE + quest * 10 + idx, quest, type, idx, idx, obj, amount, 0, 0, 0, 0, 0, 1, descr, 0 FROM (
    SELECT q.entry AS quest, 0 AS idx, IF(q.ReqCreatureOrGOId1 < 0, 2, 0) AS type, ABS(q.ReqCreatureOrGOId1) AS obj, q.ReqCreatureOrGOCount1 AS amount, q.ObjectiveText1 AS descr FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry WHERE q.ReqCreatureOrGOId1 <> 0
    UNION ALL SELECT q.entry, 1, IF(q.ReqCreatureOrGOId2 < 0, 2, 0), ABS(q.ReqCreatureOrGOId2), q.ReqCreatureOrGOCount2, q.ObjectiveText2 FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry WHERE q.ReqCreatureOrGOId2 <> 0
    UNION ALL SELECT q.entry, 2, IF(q.ReqCreatureOrGOId3 < 0, 2, 0), ABS(q.ReqCreatureOrGOId3), q.ReqCreatureOrGOCount3, q.ObjectiveText3 FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry WHERE q.ReqCreatureOrGOId3 <> 0
    UNION ALL SELECT q.entry, 3, IF(q.ReqCreatureOrGOId4 < 0, 2, 0), ABS(q.ReqCreatureOrGOId4), q.ReqCreatureOrGOCount4, q.ObjectiveText4 FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry WHERE q.ReqCreatureOrGOId4 <> 0
    UNION ALL SELECT q.entry, 4, 1, q.ReqItemId1, q.ReqItemCount1, '' FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry WHERE q.ReqItemId1 <> 0
    UNION ALL SELECT q.entry, 5, 1, q.ReqItemId2, q.ReqItemCount2, '' FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry WHERE q.ReqItemId2 <> 0
    UNION ALL SELECT q.entry, 6, 1, q.ReqItemId3, q.ReqItemCount3, '' FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry WHERE q.ReqItemId3 <> 0
    UNION ALL SELECT q.entry, 7, 1, q.ReqItemId4, q.ReqItemCount4, '' FROM vmangos_world.ns_quest_template q JOIN vmangos_world.ns_quests n ON n.quest = q.entry WHERE q.ReqItemId4 <> 0
) x;

-- quest givers / enders: Northshire creatures get exactly their vanilla quests; the imported quests keep only vanilla givers/enders
DELETE s FROM world.creature_queststarter s JOIN vmangos_world.ns_entries e ON e.entry = s.id;
DELETE s FROM world.creature_queststarter s JOIN vmangos_world.ns_quests n ON n.quest = s.quest;
DELETE s FROM world.creature_questender s JOIN vmangos_world.ns_entries e ON e.entry = s.id;
DELETE s FROM world.creature_questender s JOIN vmangos_world.ns_quests n ON n.quest = s.quest;
DELETE s FROM world.gameobject_queststarter s JOIN vmangos_world.ns_quests n ON n.quest = s.quest;
DELETE s FROM world.gameobject_questender s JOIN vmangos_world.ns_quests n ON n.quest = s.quest;

INSERT IGNORE INTO world.creature_queststarter (id, quest, VerifiedBuild)
SELECT DISTINCT r.id, r.quest, 0 FROM vmangos_world.creature_questrelation r JOIN world.creature_template t ON t.entry = r.id JOIN world.quest_template q ON q.ID = r.quest
LEFT JOIN vmangos_world.ns_entries e ON e.entry = r.id LEFT JOIN vmangos_world.ns_quests n ON n.quest = r.quest
WHERE r.patch_min <= 10 AND r.patch_max >= 10 AND (e.entry IS NOT NULL OR n.quest IS NOT NULL);
INSERT IGNORE INTO world.creature_questender (id, quest, VerifiedBuild)
SELECT DISTINCT r.id, r.quest, 0 FROM vmangos_world.creature_involvedrelation r JOIN world.creature_template t ON t.entry = r.id JOIN world.quest_template q ON q.ID = r.quest
LEFT JOIN vmangos_world.ns_entries e ON e.entry = r.id LEFT JOIN vmangos_world.ns_quests n ON n.quest = r.quest
WHERE r.patch_min <= 10 AND r.patch_max >= 10 AND (e.entry IS NOT NULL OR n.quest IS NOT NULL);
INSERT IGNORE INTO world.gameobject_queststarter (id, quest, VerifiedBuild)
SELECT DISTINCT r.id, r.quest, 0 FROM vmangos_world.gameobject_questrelation r JOIN world.gameobject_template t ON t.entry = r.id JOIN vmangos_world.ns_quests n ON n.quest = r.quest
WHERE r.patch_min <= 10 AND r.patch_max >= 10;
INSERT IGNORE INTO world.gameobject_questender (id, quest, VerifiedBuild)
SELECT DISTINCT r.id, r.quest, 0 FROM vmangos_world.gameobject_involvedrelation r JOIN world.gameobject_template t ON t.entry = r.id JOIN vmangos_world.ns_quests n ON n.quest = r.quest
WHERE r.patch_min <= 10 AND r.patch_max >= 10;

-- TDB disables these old quests ("Deprecated quest") and marks them Expansion -2: re-enable the vanilla versions
DELETE d FROM world.disables d JOIN vmangos_world.ns_quests n ON n.quest = d.entry WHERE d.sourceType = 1;
UPDATE world.quest_template w JOIN vmangos_world.ns_quests n ON n.quest = w.ID SET w.Expansion = 0, w.ContentTuningID = 0;
