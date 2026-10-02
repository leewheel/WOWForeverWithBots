-- Classic 1.60: graveyards of Zephras Isle (map 2991, zone 16593); without them a death there sent the player to the Barrens.
-- IDs from the official beta's cemetery list for the zone (ymir sniffs); the positions are only on Blizzard's server: the Spirit Healer
-- seen in the sniffs (11033) and the quest hubs.
DELETE FROM `world_safe_locs` WHERE `ID` IN (10912,11031,11032,11033);
INSERT INTO `world_safe_locs` (`ID`,`MapID`,`LocX`,`LocY`,`LocZ`,`Facing`,`Comment`) VALUES
(11031,2991,4085.0,1860.0,977.0,4.71,'Zephras Isle - starting village'),
(10912,2991,3837.2,2099.9,967.6,3.14,'Zephras Isle - Hanaa Nightwind'),
(11032,2991,3268.8,1700.0,826.5,1.57,'Zephras Isle - Shen''dar Village'),
(11033,2991,3290.41,1150.97,761.64,3.01,'Zephras Isle - Spirit Healer');
DELETE FROM `graveyard_zone` WHERE `ID` IN (10912,11031,11032,11033);
INSERT INTO `graveyard_zone` (`ID`,`GhostZone`,`Comment`) VALUES
(11031,16593,'Zephras Isle - starting village'),
(10912,16593,'Zephras Isle - Hanaa Nightwind'),
(11032,16593,'Zephras Isle - Shen''dar Village'),
(11033,16593,'Zephras Isle - Spirit Healer');

-- .tele zephras: the starting village
DELETE FROM `game_tele` WHERE `name` = 'Zephras';
INSERT INTO `game_tele` (`position_x`,`position_y`,`position_z`,`orientation`,`map`,`name`) VALUES
(4088.6,1848.9,976.3,0,2991,'Zephras');
