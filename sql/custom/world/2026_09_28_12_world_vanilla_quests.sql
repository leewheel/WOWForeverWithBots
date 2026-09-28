-- WoW Classic 1.60.1.70009 ("WoW Forever"): full vanilla world, part 3/4 - quests.
-- Requires 2026_09_28_10_world_vanilla_reset.sql (helper tables vmangos_world.va_*).
-- Every 1.12 quest that TC knows gets vanilla text, objectives, rewards and chain; quest givers/enders become exactly the
-- vanilla ones (retail relations removed, Zephras Isle relations kept).

SET @OBJECTIVE_BASE := 90000000;   -- quest_objectives.ID = base + quest * 10 + index

DROP TABLE IF EXISTS vmangos_world.va_quests;
CREATE TABLE vmangos_world.va_quests (quest INT UNSIGNED PRIMARY KEY)
SELECT q.entry AS quest FROM vmangos_world.va_quest_template q JOIN world.quest_template w ON w.ID = q.entry;

-- vanilla quest level / min level (TC master derives levels from ContentTuning; kept here for the Classic QuestInfo fields)
CREATE TABLE IF NOT EXISTS world.quest_classic_level (
    ID INT UNSIGNED NOT NULL,
    QuestLevel SMALLINT NOT NULL,
    MinLevel TINYINT UNSIGNED NOT NULL,
    MaxLevel TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Classic 1.60: vanilla quest levels';
REPLACE INTO world.quest_classic_level (ID, QuestLevel, MinLevel, MaxLevel)
SELECT q.entry, q.QuestLevel, q.MinLevel, q.MaxLevel FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry;

UPDATE world.quest_template w JOIN vmangos_world.va_quest_template q ON q.entry = w.ID JOIN vmangos_world.va_quests n ON n.quest = w.ID
SET w.LogTitle = q.Title, w.LogDescription = q.Objectives, w.QuestDescription = q.Details, w.AreaDescription = '', w.QuestCompletionLog = q.EndText,
    w.QuestSortID = q.ZoneOrSort, w.QuestInfoID = q.Type, w.SuggestedGroupNum = q.SuggestedPlayers,
    -- vanilla QuestFlags -> TC: keep stay alive (1), sharable (8), raid (64); vanilla 2 = party accept (TC special flag 2), vanilla 4 = exploration;
    -- VMaNGOS SpecialFlags 2 = completed by exploration / event -> TC 4 COMPLETION_AREA_TRIGGER or 2 COMPLETION_EVENT
    w.Flags = (q.QuestFlags & (1 | 8 | 64)) | IF(q.SpecialFlags & 2, IF(q.QuestFlags & 4, 4, 2), 0), w.FlagsEx = 0,
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
    w.POIContinent = q.PointMapId, w.POIx = q.PointX, w.POIy = q.PointY, w.POIPriority = q.PointOpt,
    w.Expansion = 0, w.ContentTuningID = 0;

REPLACE INTO world.quest_template_addon (ID, MaxLevel, AllowableClasses, SourceSpellID, PrevQuestID, NextQuestID, ExclusiveGroup, BreadcrumbForQuestId,
    RewardMailTemplateID, RewardMailDelay, RequiredSkillID, RequiredSkillPoints, RequiredMinRepFaction, RequiredMaxRepFaction, RequiredMinRepValue,
    RequiredMaxRepValue, ProvidedItemCount, SpecialFlags, ScriptName)
SELECT q.entry, 0, q.RequiredClasses, q.SrcSpell, q.PrevQuestId, GREATEST(q.NextQuestId, 0), q.ExclusiveGroup, q.BreadcrumbForQuestId,
    q.RewMailTemplateId, q.RewMailDelaySecs, q.RequiredSkill, q.RequiredSkillValue, q.RequiredMinRepFaction, q.RequiredMaxRepFaction, q.RequiredMinRepValue,
    q.RequiredMaxRepValue, q.SrcItemCount, (q.SpecialFlags & 1) | IF(q.QuestFlags & 2, 2, 0), COALESCE((SELECT a.ScriptName FROM world.quest_template_addon a WHERE a.ID = q.entry), '')
FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry;

REPLACE INTO world.quest_offer_reward (ID, Emote1, Emote2, Emote3, Emote4, EmoteDelay1, EmoteDelay2, EmoteDelay3, EmoteDelay4, RewardText, VerifiedBuild)
SELECT q.entry, q.OfferRewardEmote1, q.OfferRewardEmote2, q.OfferRewardEmote3, q.OfferRewardEmote4,
    q.OfferRewardEmoteDelay1, q.OfferRewardEmoteDelay2, q.OfferRewardEmoteDelay3, q.OfferRewardEmoteDelay4, q.OfferRewardText, 0
FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry;

DELETE r FROM world.quest_request_items r JOIN vmangos_world.va_quests n ON n.quest = r.ID;
INSERT INTO world.quest_request_items (ID, EmoteOnComplete, EmoteOnIncomplete, EmoteOnCompleteDelay, EmoteOnIncompleteDelay, CompletionText, VerifiedBuild)
SELECT q.entry, q.CompleteEmote, q.IncompleteEmote, 0, 0, q.RequestItemsText, 0
FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry
WHERE q.RequestItemsText IS NOT NULL AND q.RequestItemsText <> '';

-- objectives: kill / gameobject (negative ReqCreatureOrGOId) first, then items
DELETE o FROM world.quest_objectives o JOIN vmangos_world.va_quests n ON n.quest = o.QuestID;
INSERT INTO world.quest_objectives (ID, QuestID, Type, `Order`, StorageIndex, ObjectID, Amount, ConditionalAmount, Flags, Flags2, ProgressBarWeight, ParentObjectiveID, Visible, Description, VerifiedBuild)
SELECT @OBJECTIVE_BASE + quest * 10 + idx, quest, type, idx, idx, obj, amount, 0, 0, 0, 0, 0, 1, descr, 0 FROM (
    SELECT q.entry AS quest, 0 AS idx, IF(q.ReqCreatureOrGOId1 < 0, 2, 0) AS type, ABS(q.ReqCreatureOrGOId1) AS obj, q.ReqCreatureOrGOCount1 AS amount, q.ObjectiveText1 AS descr FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry WHERE q.ReqCreatureOrGOId1 <> 0
    UNION ALL SELECT q.entry, 1, IF(q.ReqCreatureOrGOId2 < 0, 2, 0), ABS(q.ReqCreatureOrGOId2), q.ReqCreatureOrGOCount2, q.ObjectiveText2 FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry WHERE q.ReqCreatureOrGOId2 <> 0
    UNION ALL SELECT q.entry, 2, IF(q.ReqCreatureOrGOId3 < 0, 2, 0), ABS(q.ReqCreatureOrGOId3), q.ReqCreatureOrGOCount3, q.ObjectiveText3 FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry WHERE q.ReqCreatureOrGOId3 <> 0
    UNION ALL SELECT q.entry, 3, IF(q.ReqCreatureOrGOId4 < 0, 2, 0), ABS(q.ReqCreatureOrGOId4), q.ReqCreatureOrGOCount4, q.ObjectiveText4 FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry WHERE q.ReqCreatureOrGOId4 <> 0
    UNION ALL SELECT q.entry, 4, 1, q.ReqItemId1, q.ReqItemCount1, '' FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry WHERE q.ReqItemId1 <> 0
    UNION ALL SELECT q.entry, 5, 1, q.ReqItemId2, q.ReqItemCount2, '' FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry WHERE q.ReqItemId2 <> 0
    UNION ALL SELECT q.entry, 6, 1, q.ReqItemId3, q.ReqItemCount3, '' FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry WHERE q.ReqItemId3 <> 0
    UNION ALL SELECT q.entry, 7, 1, q.ReqItemId4, q.ReqItemCount4, '' FROM vmangos_world.va_quest_template q JOIN vmangos_world.va_quests n ON n.quest = q.entry WHERE q.ReqItemId4 <> 0
) x;

-- quest givers / enders: exactly the vanilla relations (Zephras Isle creatures and gameobjects keep theirs)
DROP TABLE IF EXISTS vmangos_world.va_keep_relation;
CREATE TABLE vmangos_world.va_keep_relation (kind TINYINT, entry INT UNSIGNED, PRIMARY KEY (kind, entry))
SELECT DISTINCT 0 AS kind, id AS entry FROM world.creature WHERE guid BETWEEN 21000000 AND 21099999
UNION SELECT DISTINCT 1, id FROM world.gameobject WHERE guid BETWEEN 21000000 AND 21099999;

DELETE s FROM world.creature_queststarter s   LEFT JOIN vmangos_world.va_keep_relation k ON k.kind = 0 AND k.entry = s.id WHERE k.entry IS NULL;
DELETE s FROM world.creature_questender s     LEFT JOIN vmangos_world.va_keep_relation k ON k.kind = 0 AND k.entry = s.id WHERE k.entry IS NULL;
DELETE s FROM world.gameobject_queststarter s LEFT JOIN vmangos_world.va_keep_relation k ON k.kind = 1 AND k.entry = s.id WHERE k.entry IS NULL;
DELETE s FROM world.gameobject_questender s   LEFT JOIN vmangos_world.va_keep_relation k ON k.kind = 1 AND k.entry = s.id WHERE k.entry IS NULL;

INSERT IGNORE INTO world.creature_queststarter (id, quest, VerifiedBuild)
SELECT DISTINCT r.id, r.quest, 0 FROM vmangos_world.creature_questrelation r
JOIN world.creature_template t ON t.entry = r.id JOIN vmangos_world.va_quests n ON n.quest = r.quest
WHERE r.patch_min <= 10 AND r.patch_max >= 10;
INSERT IGNORE INTO world.creature_questender (id, quest, VerifiedBuild)
SELECT DISTINCT r.id, r.quest, 0 FROM vmangos_world.creature_involvedrelation r
JOIN world.creature_template t ON t.entry = r.id JOIN vmangos_world.va_quests n ON n.quest = r.quest
WHERE r.patch_min <= 10 AND r.patch_max >= 10;
INSERT IGNORE INTO world.gameobject_queststarter (id, quest, VerifiedBuild)
SELECT DISTINCT r.id, r.quest, 0 FROM vmangos_world.gameobject_questrelation r
JOIN world.gameobject_template t ON t.entry = r.id JOIN vmangos_world.va_quests n ON n.quest = r.quest
WHERE r.patch_min <= 10 AND r.patch_max >= 10;
INSERT IGNORE INTO world.gameobject_questender (id, quest, VerifiedBuild)
SELECT DISTINCT r.id, r.quest, 0 FROM vmangos_world.gameobject_involvedrelation r
JOIN world.gameobject_template t ON t.entry = r.id JOIN vmangos_world.va_quests n ON n.quest = r.quest
WHERE r.patch_min <= 10 AND r.patch_max >= 10;

-- questgiver flag follows the relations
UPDATE world.creature_template t JOIN (SELECT id FROM world.creature_queststarter UNION SELECT id FROM world.creature_questender) r ON r.id = t.entry
SET t.npcflag = t.npcflag | 2;

-- TDB disables many old quests ("Deprecated quest"): re-enable the vanilla ones; retail quest POIs are gone
DELETE d FROM world.disables d JOIN vmangos_world.va_quests n ON n.quest = d.entry WHERE d.sourceType = 1;
DELETE p FROM world.quest_poi p JOIN vmangos_world.va_quests n ON n.quest = p.QuestID;
DELETE p FROM world.quest_poi_points p JOIN vmangos_world.va_quests n ON n.quest = p.QuestID;
