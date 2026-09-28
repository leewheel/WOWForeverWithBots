-- WoW Classic 1.60.1.70009 ("WoW Forever"): full vanilla world, part 2/4 - templates, spawns, paths, pools, loot.
-- Requires 2026_09_28_10_world_vanilla_reset.sql (helper tables vmangos_world.va_*).
--   creature guid        = 20000000 + VMaNGOS guid
--   inline alternatives  = 25000000 + VMaNGOS guid * 4 + (n - 2)   (VMaNGOS creature.id2..id5, pooled with the main spawn)
--   gameobject guid      = 30000000 + VMaNGOS guid
--   waypoint path        = 800000000 + guid * 10 + path_id (per spawn), 810000000 + entry * 10 + path_id (per entry)
--   pools                = VMaNGOS pool entry; inline alternative pools = 1000000 + VMaNGOS guid

SET @CRE_BASE := 20000000, @ALT_BASE := 25000000, @GO_BASE := 30000000;
SET @PATH_SPAWN := 800000000, @PATH_ENTRY := 810000000, @POOL_INLINE := 1000000;

-- ---------------------------------------------------------------------------------------------------------------------
-- Creature templates: vanilla faction, flags, roles, speeds, rank, levels, loot
-- ---------------------------------------------------------------------------------------------------------------------
UPDATE world.creature_template w
JOIN vmangos_world.va_creature_template t ON t.entry = w.entry
JOIN vmangos_world.va_entries e ON e.entry = w.entry
SET w.name = t.name, w.subname = NULLIF(t.subname, ''), w.faction = t.faction,
    -- VMaNGOS 1.12 npc flags -> TC (decimal constants: MySQL treats 0x literals as binary strings in bit operations)
    w.npcflag = (IF(t.npc_flags & 1, 1, 0)           -- gossip
               + IF(t.npc_flags & 2, 2, 0)           -- quest giver
               + IF(t.npc_flags & 4, 128, 0)         -- vendor
               + IF(t.npc_flags & 8, 8192, 0)        -- flight master
               + IF(t.npc_flags & 16, 16, 0)         -- trainer
               + IF(t.npc_flags & 32, 16384, 0)      -- spirit healer
               + IF(t.npc_flags & 64, 32768, 0)      -- spirit guide
               + IF(t.npc_flags & 128, 65536, 0)     -- innkeeper
               + IF(t.npc_flags & 256, 131072, 0)    -- banker
               + IF(t.npc_flags & 512, 262144, 0)    -- petitioner
               + IF(t.npc_flags & 1024, 524288, 0)   -- tabard designer
               + IF(t.npc_flags & 2048, 1048576, 0)  -- battlemaster
               + IF(t.npc_flags & 4096, 2097152, 0)  -- auctioneer
               + IF(t.npc_flags & 8192, 4194304, 0)  -- stable master
               + IF(t.npc_flags & 16384, 4096, 0)),  -- repair
    w.speed_walk = t.speed_walk, w.speed_run = t.speed_run, w.Classification = t.rank, w.unit_class = t.unit_class,
    w.family = t.pet_family, w.type = t.type, w.trainer_class = t.trainer_class, w.dmgschool = t.damage_school,
    w.BaseAttackTime = t.base_attack_time, w.RangeAttackTime = t.ranged_attack_time, w.RacialLeader = t.racial_leader,
    w.ExperienceModifier = t.xp_multiplier, w.RequiredExpansion = 0, w.VignetteID = 0,
    w.VehicleId = 0,   -- retail vehicle kits do not exist in the Classic client (client freeze)
    w.unit_flags = w.unit_flags & ~64;   -- retail UNIT_FLAG_UNK_6: the Classic client treats it as a PvP unit (can't attack elites)

INSERT INTO world.creature_template_difficulty (Entry, DifficultyID, LootID, PickPocketLootID, SkinLootID, GoldMin, GoldMax)
SELECT t.entry, 0, t.loot_id, t.pickpocket_loot_id, t.skinning_loot_id, t.gold_min, t.gold_max
FROM vmangos_world.va_creature_template t JOIN vmangos_world.va_entries e ON e.entry = t.entry
ON DUPLICATE KEY UPDATE LootID = VALUES(LootID), PickPocketLootID = VALUES(PickPocketLootID), SkinLootID = VALUES(SkinLootID),
    GoldMin = VALUES(GoldMin), GoldMax = VALUES(GoldMax);

CREATE TABLE IF NOT EXISTS world.creature_classic_level (
    entry INT UNSIGNED NOT NULL,
    level_min TINYINT UNSIGNED NOT NULL,
    level_max TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (entry)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Classic 1.60: fixed vanilla creature levels (replaces ContentTuning scaling)';
REPLACE INTO world.creature_classic_level (entry, level_min, level_max)
SELECT t.entry, t.level_min, t.level_max FROM vmangos_world.va_creature_template t JOIN vmangos_world.va_entries e ON e.entry = t.entry;

-- models (+ size data for displays retail does not know), equipment, template addon (mount, auras)
DELETE m FROM world.creature_template_model m JOIN vmangos_world.va_entries e ON e.entry = m.CreatureID;
INSERT INTO world.creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT entry, 0, display_id1, IF(display_scale1 > 0, display_scale1, 1), IF(display_probability1 > 0, display_probability1, 1), 0 FROM vmangos_world.va_creature_template JOIN vmangos_world.va_entries USING (entry) WHERE display_id1 > 0
UNION ALL SELECT entry, 1, display_id2, IF(display_scale2 > 0, display_scale2, 1), display_probability2, 0 FROM vmangos_world.va_creature_template JOIN vmangos_world.va_entries USING (entry) WHERE display_id2 > 0
UNION ALL SELECT entry, 2, display_id3, IF(display_scale3 > 0, display_scale3, 1), display_probability3, 0 FROM vmangos_world.va_creature_template JOIN vmangos_world.va_entries USING (entry) WHERE display_id3 > 0
UNION ALL SELECT entry, 3, display_id4, IF(display_scale4 > 0, display_scale4, 1), display_probability4, 0 FROM vmangos_world.va_creature_template JOIN vmangos_world.va_entries USING (entry) WHERE display_id4 > 0;

INSERT IGNORE INTO world.creature_model_info (DisplayID, BoundingRadius, CombatReach, DisplayID_Other_Gender, VerifiedBuild)
SELECT d.display_id, d.bounding_radius, d.combat_reach, d.display_id_other_gender, 0
FROM vmangos_world.creature_display_info_addon d
JOIN (SELECT display_id, MAX(build) AS b FROM vmangos_world.creature_display_info_addon WHERE build <= 5875 GROUP BY display_id) l ON l.display_id = d.display_id AND l.b = d.build;

DELETE q FROM world.creature_equip_template q JOIN vmangos_world.va_entries e ON e.entry = q.CreatureID;
INSERT INTO world.creature_equip_template (CreatureID, ID, ItemID1, AppearanceModID1, ItemVisual1, ItemID2, AppearanceModID2, ItemVisual2, ItemID3, AppearanceModID3, ItemVisual3, VerifiedBuild)
SELECT t.entry, 1, q.item1, 0, 0, q.item2, 0, 0, q.item3, 0, 0, 0
FROM vmangos_world.va_creature_template t
JOIN vmangos_world.va_entries e ON e.entry = t.entry
JOIN (SELECT entry, ANY_VALUE(item1) AS item1, ANY_VALUE(item2) AS item2, ANY_VALUE(item3) AS item3 FROM vmangos_world.creature_equip_template WHERE patch_min <= 10 AND patch_max >= 10 GROUP BY entry) q ON q.entry = t.equipment_id
WHERE t.equipment_id > 0;

DELETE a FROM world.creature_template_addon a JOIN vmangos_world.va_entries e ON e.entry = a.entry;
INSERT INTO world.creature_template_addon (entry, PathId, mount, MountCreatureID, StandState, AnimTier, VisFlags, SheathState, PvPFlags, emote, aiAnimKit, movementAnimKit, meleeAnimKit, visibilityDistanceType, auras)
SELECT t.entry, 0, GREATEST(t.mount_display_id, 0), 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, NULLIF(TRIM(t.auras), '')
FROM vmangos_world.va_creature_template t JOIN vmangos_world.va_entries e ON e.entry = t.entry
WHERE t.mount_display_id > 0 OR (t.auras IS NOT NULL AND TRIM(t.auras) <> '');

-- ---------------------------------------------------------------------------------------------------------------------
-- Creature spawns (this file can be re-run: our ranges are cleared first)
-- ---------------------------------------------------------------------------------------------------------------------
DELETE FROM world.creature_addon WHERE guid BETWEEN @CRE_BASE AND @CRE_BASE + 999999 OR guid BETWEEN @ALT_BASE AND @GO_BASE - 1;
DELETE FROM world.creature WHERE guid BETWEEN @CRE_BASE AND @CRE_BASE + 999999 OR guid BETWEEN @ALT_BASE AND @GO_BASE - 1;
DELETE FROM world.gameobject WHERE guid >= @GO_BASE;
DELETE FROM world.pool_members;
DELETE FROM world.pool_template;

DROP TABLE IF EXISTS vmangos_world.va_creature_addon;
CREATE TABLE vmangos_world.va_creature_addon AS
SELECT a.* FROM vmangos_world.creature_addon a
JOIN (SELECT guid, MAX(patch) AS p FROM vmangos_world.creature_addon WHERE patch <= 10 GROUP BY guid) l ON l.guid = a.guid AND l.p = a.patch;
ALTER TABLE vmangos_world.va_creature_addon ADD PRIMARY KEY (guid);

INSERT INTO world.creature (guid, id, map, zoneId, areaId, spawnDifficulties, phaseUseFlags, PhaseId, PhaseGroup, terrainSwapMap, modelid,
    equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, currentwaypoint, curHealthPct, MovementType,
    npcflag, unit_flags, unit_flags2, unit_flags3, ScriptName, StringId, VerifiedBuild)
SELECT @CRE_BASE + c.guid, c.id, c.map, 0, 0, '0', 0, 0, 0, -1, COALESCE(NULLIF(a.display_id, 0), 0),
    IF(t.equipment_id > 0, 1, 0), c.position_x, c.position_y, c.position_z, c.orientation, c.spawntimesecsmin, c.wander_distance, 0, 100,
    LEAST(c.movement_type, 2), NULL, NULL, NULL, NULL, '', NULL, 0
FROM vmangos_world.va_creature c
JOIN vmangos_world.va_entries e ON e.entry = c.id
JOIN vmangos_world.va_creature_template t ON t.entry = c.id
LEFT JOIN vmangos_world.va_creature_addon a ON a.guid = c.guid;

-- inline alternatives (id2..id5): extra spawn at the same spot, pooled with the main spawn (one of them is up)
DROP TABLE IF EXISTS vmangos_world.va_creature_alt;
CREATE TABLE vmangos_world.va_creature_alt (guid INT UNSIGNED, n TINYINT UNSIGNED, id INT UNSIGNED, PRIMARY KEY (guid, n))
SELECT guid, 2 AS n, id2 AS id FROM vmangos_world.va_creature WHERE id2 > 0 AND id2 <> id
UNION ALL SELECT guid, 3, id3 FROM vmangos_world.va_creature WHERE id3 > 0 AND id3 <> id
UNION ALL SELECT guid, 4, id4 FROM vmangos_world.va_creature WHERE id4 > 0 AND id4 <> id
UNION ALL SELECT guid, 5, id5 FROM vmangos_world.va_creature WHERE id5 > 0 AND id5 <> id;
DELETE x FROM vmangos_world.va_creature_alt x LEFT JOIN vmangos_world.va_entries e ON e.entry = x.id WHERE e.entry IS NULL;

INSERT INTO world.creature (guid, id, map, zoneId, areaId, spawnDifficulties, phaseUseFlags, PhaseId, PhaseGroup, terrainSwapMap, modelid,
    equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, currentwaypoint, curHealthPct, MovementType,
    npcflag, unit_flags, unit_flags2, unit_flags3, ScriptName, StringId, VerifiedBuild)
SELECT @ALT_BASE + c.guid * 4 + (x.n - 2), x.id, c.map, 0, 0, '0', 0, 0, 0, -1, 0,
    IF(t.equipment_id > 0, 1, 0), c.position_x, c.position_y, c.position_z, c.orientation, c.spawntimesecsmin, c.wander_distance, 0, 100,
    IF(c.movement_type = 1, 1, 0), NULL, NULL, NULL, NULL, '', NULL, 0
FROM vmangos_world.va_creature_alt x
JOIN vmangos_world.va_creature c ON c.guid = x.guid
JOIN vmangos_world.va_creature_template t ON t.entry = x.id;

-- per-spawn addon: stand state, sheath, emote, mount, auras
INSERT INTO world.creature_addon (guid, PathId, mount, MountCreatureID, StandState, AnimTier, VisFlags, SheathState, PvPFlags, emote, aiAnimKit, movementAnimKit, meleeAnimKit, visibilityDistanceType, auras)
SELECT @CRE_BASE + a.guid, 0, GREATEST(a.mount_display_id, 0), 0, GREATEST(a.stand_state, 0), 0, 0, GREATEST(a.sheath_state, 0), 0, GREATEST(a.emote_state, 0), 0, 0, 0, 0, NULLIF(TRIM(a.auras), '')
FROM vmangos_world.va_creature_addon a JOIN vmangos_world.va_creature c ON c.guid = a.guid JOIN vmangos_world.va_entries e ON e.entry = c.id;

-- ---------------------------------------------------------------------------------------------------------------------
-- Waypoint paths (VMaNGOS creature_movement per spawn, creature_movement_template per entry)
-- ---------------------------------------------------------------------------------------------------------------------
DELETE FROM world.waypoint_path_node WHERE PathId BETWEEN @PATH_SPAWN AND @PATH_ENTRY + 999999999;
DELETE FROM world.waypoint_path      WHERE PathId BETWEEN @PATH_SPAWN AND @PATH_ENTRY + 999999999;

INSERT INTO world.waypoint_path (PathId, MoveType, Flags, Velocity, Comment)
SELECT DISTINCT @PATH_SPAWN + m.id * 10 + m.path_id, 0, 0, NULL, 'VMaNGOS 1.12 spawn path'
FROM vmangos_world.creature_movement m JOIN vmangos_world.va_creature c ON c.guid = m.id;
INSERT INTO world.waypoint_path_node (PathId, NodeId, PositionX, PositionY, PositionZ, Orientation, Delay)
SELECT @PATH_SPAWN + m.id * 10 + m.path_id, m.point, m.position_x, m.position_y, m.position_z,
    IF(m.orientation = 100 OR m.orientation = 0, NULL, m.orientation), m.waittime
FROM vmangos_world.creature_movement m JOIN vmangos_world.va_creature c ON c.guid = m.id;

INSERT INTO world.waypoint_path (PathId, MoveType, Flags, Velocity, Comment)
SELECT DISTINCT @PATH_ENTRY + m.entry * 10 + m.path_id, 0, 0, NULL, 'VMaNGOS 1.12 entry path'
FROM vmangos_world.creature_movement_template m JOIN world.creature_template w ON w.entry = m.entry;   -- summoned creatures (scripts) too
INSERT INTO world.waypoint_path_node (PathId, NodeId, PositionX, PositionY, PositionZ, Orientation, Delay)
SELECT @PATH_ENTRY + m.entry * 10 + m.path_id, m.point, m.position_x, m.position_y, m.position_z,
    IF(m.orientation = 100 OR m.orientation = 0, NULL, m.orientation), m.waittime
FROM vmangos_world.creature_movement_template m JOIN world.creature_template w ON w.entry = m.entry;   -- summoned creatures (scripts) too

-- waypoint movers use their own path, else their entry's path (path_id 0)
DROP TABLE IF EXISTS vmangos_world.va_paths;
CREATE TABLE vmangos_world.va_paths (guid INT UNSIGNED PRIMARY KEY, path INT UNSIGNED)
SELECT c.guid, COALESCE(
        (SELECT @PATH_SPAWN + c.guid * 10 FROM vmangos_world.creature_movement m WHERE m.id = c.guid AND m.path_id = 0 LIMIT 1),
        (SELECT @PATH_ENTRY + c.id * 10 FROM vmangos_world.creature_movement_template m WHERE m.entry = c.id AND m.path_id = 0 LIMIT 1)) AS path
FROM vmangos_world.va_creature c JOIN vmangos_world.va_entries e ON e.entry = c.id
WHERE c.movement_type = 2;
DELETE FROM vmangos_world.va_paths WHERE path IS NULL;

INSERT INTO world.creature_addon (guid, PathId, mount, MountCreatureID, StandState, AnimTier, VisFlags, SheathState, PvPFlags, emote, aiAnimKit, movementAnimKit, meleeAnimKit, visibilityDistanceType, auras)
SELECT @CRE_BASE + p.guid, p.path, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, NULL FROM vmangos_world.va_paths p
ON DUPLICATE KEY UPDATE PathId = VALUES(PathId);
-- waypoint movers without any path stand still instead of erroring
UPDATE world.creature w JOIN vmangos_world.va_creature c ON w.guid = @CRE_BASE + c.guid
LEFT JOIN vmangos_world.va_paths p ON p.guid = c.guid
SET w.MovementType = 0 WHERE c.movement_type = 2 AND p.guid IS NULL;

-- ---------------------------------------------------------------------------------------------------------------------
-- Gameobject templates: vanilla data for every vanilla entry (missing ones created); TC scripts kept
-- ---------------------------------------------------------------------------------------------------------------------
INSERT INTO world.gameobject_template (entry, type, displayId, name, IconName, castBarCaption, unk1, size,
    Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, Data12, Data13, Data14, Data15, Data16, Data17,
    Data18, Data19, Data20, Data21, Data22, Data23, Data24, Data25, Data26, Data27, Data28, Data29, Data30, Data31, Data32, Data33, Data34,
    ContentTuningId, RequiredLevel, AIName, ScriptName, StringId, VerifiedBuild)
SELECT t.entry, t.type, t.displayId, t.name, COALESCE(t.icon, ''), '', '', t.size,
    t.data0, t.data1, t.data2, t.data3, t.data4, t.data5, t.data6, t.data7, t.data8, t.data9, t.data10, t.data11, t.data12, t.data13, t.data14,
    t.data15, t.data16, t.data17, t.data18, t.data19, t.data20, t.data21, t.data22, t.data23, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, '', '', NULL, 0
FROM vmangos_world.va_gameobject_template t
ON DUPLICATE KEY UPDATE type = VALUES(type), displayId = VALUES(displayId), name = VALUES(name), size = VALUES(size),
    Data0 = VALUES(Data0), Data1 = VALUES(Data1), Data2 = VALUES(Data2), Data3 = VALUES(Data3), Data4 = VALUES(Data4), Data5 = VALUES(Data5),
    Data6 = VALUES(Data6), Data7 = VALUES(Data7), Data8 = VALUES(Data8), Data9 = VALUES(Data9), Data10 = VALUES(Data10), Data11 = VALUES(Data11),
    Data12 = VALUES(Data12), Data13 = VALUES(Data13), Data14 = VALUES(Data14), Data15 = VALUES(Data15), Data16 = VALUES(Data16), Data17 = VALUES(Data17),
    Data18 = VALUES(Data18), Data19 = VALUES(Data19), Data20 = VALUES(Data20), Data21 = VALUES(Data21), Data22 = VALUES(Data22), Data23 = VALUES(Data23),
    Data24 = 0, Data25 = 0, Data26 = 0, Data27 = 0, Data28 = 0, Data29 = 0, Data30 = 0, Data31 = 0, Data32 = 0, Data33 = 0, Data34 = 0,
    ContentTuningId = 0, RequiredLevel = 0;

INSERT INTO world.gameobject_template_addon (entry, faction, flags, mingold, maxgold, artkit0, artkit1, artkit2, artkit3, artkit4, WorldEffectID, AIAnimKitID)
SELECT t.entry, t.faction, t.flags, t.mingold, t.maxgold, 0, 0, 0, 0, 0, 0, 0 FROM vmangos_world.va_gameobject_template t
ON DUPLICATE KEY UPDATE faction = VALUES(faction), flags = VALUES(flags), mingold = VALUES(mingold), maxgold = VALUES(maxgold), WorldEffectID = 0, AIAnimKitID = 0;

-- ---------------------------------------------------------------------------------------------------------------------
-- Gameobject spawns
-- ---------------------------------------------------------------------------------------------------------------------
INSERT INTO world.gameobject (guid, id, map, zoneId, areaId, spawnDifficulties, phaseUseFlags, PhaseId, PhaseGroup, terrainSwapMap,
    position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state, ScriptName, StringId, VerifiedBuild)
SELECT @GO_BASE + g.guid, g.id, g.map, 0, 0, '0', 0, 0, 0, -1,
    g.position_x, g.position_y, g.position_z, g.orientation, g.rotation0, g.rotation1, g.rotation2, g.rotation3, g.spawntimesecsmin, g.animprogress, g.state, '', NULL, 0
FROM vmangos_world.va_gameobject g;

-- instance spawns need the map's Classic difficulty: dungeons 1 (Normal), 20-man raids 148, 40-man raids 9
UPDATE world.creature SET spawnDifficulties = CASE
        WHEN map IN (309, 509) THEN '148'
        WHEN map IN (249, 409, 469, 531, 533) THEN '9'
        WHEN map IN (33, 34, 36, 43, 47, 48, 70, 90, 109, 129, 189, 209, 229, 230, 289, 329, 349, 389, 429) THEN '1'
        ELSE '0' END
WHERE guid BETWEEN @CRE_BASE AND @GO_BASE - 1;
UPDATE world.gameobject SET spawnDifficulties = CASE
        WHEN map IN (309, 509) THEN '148'
        WHEN map IN (249, 409, 469, 531, 533) THEN '9'
        WHEN map IN (33, 34, 36, 43, 47, 48, 70, 90, 109, 129, 189, 209, 229, 230, 289, 329, 349, 389, 429) THEN '1'
        ELSE '0' END
WHERE guid >= @GO_BASE;

-- ---------------------------------------------------------------------------------------------------------------------
-- Pools
-- ---------------------------------------------------------------------------------------------------------------------
INSERT INTO world.pool_template (entry, max_limit, description)
SELECT entry, max_limit, LEFT(description, 255) FROM vmangos_world.pool_template WHERE patch_min <= 10 AND patch_max >= 10;

INSERT IGNORE INTO world.pool_members (type, spawnId, poolSpawnId, chance, description)
SELECT 0, @CRE_BASE + p.guid, p.pool_entry, p.chance, LEFT(p.description, 255) FROM vmangos_world.pool_creature p
JOIN vmangos_world.va_creature c ON c.guid = p.guid JOIN world.pool_template t ON t.entry = p.pool_entry
WHERE p.patch_min <= 10 AND p.patch_max >= 10;
INSERT IGNORE INTO world.pool_members (type, spawnId, poolSpawnId, chance, description)
SELECT 1, @GO_BASE + p.guid, p.pool_entry, p.chance, LEFT(p.description, 255) FROM vmangos_world.pool_gameobject p
JOIN vmangos_world.va_gameobject g ON g.guid = p.guid JOIN world.pool_template t ON t.entry = p.pool_entry
WHERE p.patch_min <= 10 AND p.patch_max >= 10;
-- pools by entry: every spawn of that entry that is not pooled already
INSERT IGNORE INTO world.pool_members (type, spawnId, poolSpawnId, chance, description)
SELECT 0, @CRE_BASE + c.guid, p.pool_entry, p.chance, LEFT(p.description, 255) FROM vmangos_world.pool_creature_template p
JOIN vmangos_world.va_creature c ON c.id = p.id JOIN world.pool_template t ON t.entry = p.pool_entry
WHERE p.patch_min <= 10 AND p.patch_max >= 10;
INSERT IGNORE INTO world.pool_members (type, spawnId, poolSpawnId, chance, description)
SELECT 1, @GO_BASE + g.guid, p.pool_entry, p.chance, LEFT(p.description, 255) FROM vmangos_world.pool_gameobject_template p
JOIN vmangos_world.va_gameobject g ON g.id = p.id JOIN world.pool_template t ON t.entry = p.pool_entry
WHERE p.patch_min <= 10 AND p.patch_max >= 10;
INSERT IGNORE INTO world.pool_members (type, spawnId, poolSpawnId, chance, description)
SELECT 2, p.pool_id, p.mother_pool, p.chance, LEFT(p.description, 255) FROM vmangos_world.pool_pool p
JOIN world.pool_template a ON a.entry = p.pool_id JOIN world.pool_template b ON b.entry = p.mother_pool;

-- inline alternatives: main spawn + alternatives, one at a time (only when the main spawn is not in a pool already)
INSERT INTO world.pool_template (entry, max_limit, description)
SELECT DISTINCT @POOL_INLINE + x.guid, 1, CONCAT('VMaNGOS inline creature ', x.guid) FROM vmangos_world.va_creature_alt x
LEFT JOIN world.pool_members m ON m.type = 0 AND m.spawnId = @CRE_BASE + x.guid WHERE m.spawnId IS NULL;
INSERT IGNORE INTO world.pool_members (type, spawnId, poolSpawnId, chance, description)
SELECT 0, @CRE_BASE + c.guid, @POOL_INLINE + c.guid, 0, 'VMaNGOS inline main' FROM vmangos_world.va_creature c
JOIN world.pool_template t ON t.entry = @POOL_INLINE + c.guid;
INSERT IGNORE INTO world.pool_members (type, spawnId, poolSpawnId, chance, description)
SELECT 0, @ALT_BASE + x.guid * 4 + (x.n - 2), @POOL_INLINE + x.guid, 0, 'VMaNGOS inline alternative' FROM vmangos_world.va_creature_alt x
JOIN world.pool_template t ON t.entry = @POOL_INLINE + x.guid;
-- alternatives of an already pooled main spawn: drop them (the pool keeps the main spawn)
DELETE w FROM world.creature w JOIN vmangos_world.va_creature_alt x ON w.guid = @ALT_BASE + x.guid * 4 + (x.n - 2)
LEFT JOIN world.pool_members m ON m.type = 0 AND m.spawnId = w.guid WHERE m.spawnId IS NULL;

-- pools without members would error at load
DELETE t FROM world.pool_template t LEFT JOIN world.pool_members m ON m.poolSpawnId = t.entry WHERE m.poolSpawnId IS NULL;
DELETE m FROM world.pool_members m LEFT JOIN world.pool_template t ON t.entry = m.poolSpawnId WHERE t.entry IS NULL;

-- ---------------------------------------------------------------------------------------------------------------------
-- Loot: vanilla tables with VMaNGOS ids (Zephras Isle loot kept)
-- ---------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS vmangos_world.va_keep_loot;
CREATE TABLE vmangos_world.va_keep_loot (kind TINYINT, entry INT UNSIGNED, PRIMARY KEY (kind, entry))
SELECT DISTINCT 0 AS kind, d.LootID AS entry FROM world.creature_template_difficulty d JOIN world.creature c ON c.id = d.Entry
WHERE c.guid BETWEEN 21000000 AND 21099999 AND d.LootID > 0
UNION SELECT DISTINCT 1, t.Data1 FROM world.gameobject_template t JOIN world.gameobject g ON g.id = t.entry
WHERE g.guid BETWEEN 21000000 AND 21099999 AND t.type IN (3, 25) AND t.Data1 > 0;

DELETE l FROM world.creature_loot_template l LEFT JOIN vmangos_world.va_keep_loot k ON k.kind = 0 AND k.entry = l.Entry WHERE k.entry IS NULL;
DELETE l FROM world.gameobject_loot_template l LEFT JOIN vmangos_world.va_keep_loot k ON k.kind = 1 AND k.entry = l.Entry WHERE k.entry IS NULL;
DELETE FROM world.pickpocketing_loot_template;
DELETE FROM world.skinning_loot_template;
DELETE FROM world.item_loot_template;
DELETE FROM world.fishing_loot_template;
DELETE FROM world.reference_loot_template;

INSERT IGNORE INTO world.creature_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT entry, IF(mincountOrRef < 0, 1, 0), IF(mincountOrRef < 0, -mincountOrRef, item), ABS(ChanceOrQuestChance), ChanceOrQuestChance < 0, 1, groupid,
    IF(mincountOrRef < 0, 1, mincountOrRef), maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.creature_loot_template WHERE patch_min <= 10 AND patch_max >= 10;
INSERT IGNORE INTO world.gameobject_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT entry, IF(mincountOrRef < 0, 1, 0), IF(mincountOrRef < 0, -mincountOrRef, item), ABS(ChanceOrQuestChance), ChanceOrQuestChance < 0, 1, groupid,
    IF(mincountOrRef < 0, 1, mincountOrRef), maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.gameobject_loot_template WHERE patch_min <= 10 AND patch_max >= 10;
INSERT IGNORE INTO world.pickpocketing_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT entry, IF(mincountOrRef < 0, 1, 0), IF(mincountOrRef < 0, -mincountOrRef, item), ABS(ChanceOrQuestChance), ChanceOrQuestChance < 0, 1, groupid,
    IF(mincountOrRef < 0, 1, mincountOrRef), maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.pickpocketing_loot_template WHERE patch_min <= 10 AND patch_max >= 10;
INSERT IGNORE INTO world.skinning_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT entry, IF(mincountOrRef < 0, 1, 0), IF(mincountOrRef < 0, -mincountOrRef, item), ABS(ChanceOrQuestChance), ChanceOrQuestChance < 0, 1, groupid,
    IF(mincountOrRef < 0, 1, mincountOrRef), maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.skinning_loot_template WHERE patch_min <= 10 AND patch_max >= 10;
INSERT IGNORE INTO world.item_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT entry, IF(mincountOrRef < 0, 1, 0), IF(mincountOrRef < 0, -mincountOrRef, item), ABS(ChanceOrQuestChance), ChanceOrQuestChance < 0, 1, groupid,
    IF(mincountOrRef < 0, 1, mincountOrRef), maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.item_loot_template WHERE patch_min <= 10 AND patch_max >= 10;
INSERT IGNORE INTO world.fishing_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT entry, IF(mincountOrRef < 0, 1, 0), IF(mincountOrRef < 0, -mincountOrRef, item), ABS(ChanceOrQuestChance), ChanceOrQuestChance < 0, 1, groupid,
    IF(mincountOrRef < 0, 1, mincountOrRef), maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.fishing_loot_template WHERE patch_min <= 10 AND patch_max >= 10;
INSERT IGNORE INTO world.reference_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT entry, IF(mincountOrRef < 0, 1, 0), IF(mincountOrRef < 0, -mincountOrRef, item), ABS(ChanceOrQuestChance), ChanceOrQuestChance < 0, 1, groupid,
    IF(mincountOrRef < 0, 1, mincountOrRef), maxcount, 'VMaNGOS 1.12'
FROM vmangos_world.reference_loot_template WHERE patch_min <= 10 AND patch_max >= 10;
