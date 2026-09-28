-- WoW Classic 1.60.1.70009 ("WoW Forever"): full vanilla world, part 1/4 - helper tables and removal of all retail spawns.
-- Requires the VMaNGOS world database as schema `vmangos_world` (release db_latest, GPL-2) on the same MySQL server.
-- VMaNGOS rows are filtered to patch 1.12 (patch index 10). Kept: the Zephras Isle spawns (guid 21000000..21099999, own import).
-- Supersedes the Northshire-only import (2026_09_27_01..03).

-- ---------------------------------------------------------------------------------------------------------------------
-- Helper tables (in vmangos_world): 1.12 rows only
-- ---------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS vmangos_world.va_creature_template;
CREATE TABLE vmangos_world.va_creature_template AS
SELECT t.* FROM vmangos_world.creature_template t
JOIN (SELECT entry, MAX(patch) AS p FROM vmangos_world.creature_template WHERE patch <= 10 GROUP BY entry) l ON l.entry = t.entry AND l.p = t.patch;
ALTER TABLE vmangos_world.va_creature_template ADD PRIMARY KEY (entry);

DROP TABLE IF EXISTS vmangos_world.va_gameobject_template;
CREATE TABLE vmangos_world.va_gameobject_template AS
SELECT t.* FROM vmangos_world.gameobject_template t
JOIN (SELECT entry, MAX(patch) AS p FROM vmangos_world.gameobject_template WHERE patch <= 10 GROUP BY entry) l ON l.entry = t.entry AND l.p = t.patch;
ALTER TABLE vmangos_world.va_gameobject_template ADD PRIMARY KEY (entry);

DROP TABLE IF EXISTS vmangos_world.va_quest_template;
CREATE TABLE vmangos_world.va_quest_template AS
SELECT q.* FROM vmangos_world.quest_template q
JOIN (SELECT entry, MAX(patch) AS p FROM vmangos_world.quest_template WHERE patch <= 10 GROUP BY entry) l ON l.entry = q.entry AND l.p = q.patch;
ALTER TABLE vmangos_world.va_quest_template ADD PRIMARY KEY (entry);

-- holiday (game event) spawns are left out until game events are imported; disabled spawns (spawn_flags 0x2) too
DROP TABLE IF EXISTS vmangos_world.va_creature;
CREATE TABLE vmangos_world.va_creature AS
SELECT c.* FROM vmangos_world.creature c
JOIN vmangos_world.va_creature_template t ON t.entry = c.id
WHERE c.patch_min <= 10 AND c.patch_max >= 10 AND (c.spawn_flags & 2) = 0
  AND NOT EXISTS (SELECT 1 FROM vmangos_world.game_event_creature e WHERE ABS(e.guid) = c.guid);
ALTER TABLE vmangos_world.va_creature ADD PRIMARY KEY (guid);

DROP TABLE IF EXISTS vmangos_world.va_gameobject;
CREATE TABLE vmangos_world.va_gameobject AS
SELECT g.* FROM vmangos_world.gameobject g
JOIN vmangos_world.va_gameobject_template t ON t.entry = g.id
WHERE g.patch_min <= 10 AND g.patch_max >= 10 AND (g.spawn_flags & 2) = 0
  AND NOT EXISTS (SELECT 1 FROM vmangos_world.game_event_gameobject e WHERE ABS(e.guid) = g.guid);
ALTER TABLE vmangos_world.va_gameobject ADD PRIMARY KEY (guid);

-- every creature entry that is spawned (main id and the inline alternatives id2..id5)
DROP TABLE IF EXISTS vmangos_world.va_entries;
CREATE TABLE vmangos_world.va_entries (entry INT UNSIGNED PRIMARY KEY)
SELECT DISTINCT e.entry FROM (
    SELECT id AS entry FROM vmangos_world.va_creature
    UNION SELECT id2 FROM vmangos_world.va_creature WHERE id2 > 0
    UNION SELECT id3 FROM vmangos_world.va_creature WHERE id3 > 0
    UNION SELECT id4 FROM vmangos_world.va_creature WHERE id4 > 0
    UNION SELECT id5 FROM vmangos_world.va_creature WHERE id5 > 0) e
JOIN world.creature_template w ON w.entry = e.entry
JOIN vmangos_world.va_creature_template t ON t.entry = e.entry;

-- ---------------------------------------------------------------------------------------------------------------------
-- Remove every retail spawn (all maps) except Zephras Isle, and all rows keyed by those spawns
-- ---------------------------------------------------------------------------------------------------------------------
SET @KEEP_MIN := 21000000, @KEEP_MAX := 21099999;

DELETE FROM world.creature_addon                  WHERE guid     NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.creature_formations             WHERE leaderGUID NOT BETWEEN @KEEP_MIN AND @KEEP_MAX OR memberGUID NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.creature_movement_override      WHERE SpawnId  NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.creature_static_flags_override  WHERE SpawnId  NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.game_event_creature             WHERE ABS(guid) NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.game_event_gameobject           WHERE ABS(guid) NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.game_event_model_equip          WHERE guid     NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.game_event_npc_vendor           WHERE guid     NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.game_event_npcflag              WHERE guid     NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.gameobject_addon                WHERE guid     NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.gameobject_overrides            WHERE spawnId  NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.linked_respawn                  WHERE guid     NOT BETWEEN @KEEP_MIN AND @KEEP_MAX OR linkedGuid NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.spawn_group                     WHERE spawnType IN (0, 1) AND spawnId NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.spawn_tracking                  WHERE SpawnId  NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.spawn_tracking_state            WHERE SpawnId  NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.vehicle_accessory               WHERE guid     NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.pool_members;
DELETE FROM world.pool_template;
-- per-spawn SmartAI (negative entryorguid) and retail areatrigger spawns
DELETE FROM world.smart_scripts WHERE source_type IN (0, 1) AND entryorguid < 0 AND -entryorguid NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.areatrigger;
-- waypoint paths stay: escort / SmartAI scripts start them by id; paths of removed spawns are simply unused

DELETE FROM world.creature   WHERE guid NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
DELETE FROM world.gameobject WHERE guid NOT BETWEEN @KEEP_MIN AND @KEEP_MAX;
