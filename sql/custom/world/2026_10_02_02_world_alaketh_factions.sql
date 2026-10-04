-- Re-run after the sniff files (2026_10_01_03/04, 2026_10_02_00/06, 2026_10_03_00) were regenerated: they rewrite rows this file adjusts (last: 2026-10-04, build 70205 sniff of 04:31, gossip greetings).
-- Classic 1.60: the Al'Aketh cultists of Zephras Isle are hostile (faction template 3578 in ymir sniffs of the official beta);
-- the ones added by hand before the sniffs (not seen there yet) had the friendly 35, so players could not attack them for quests.
UPDATE `creature_template` SET `faction` = 3578 WHERE `name` LIKE 'Al''Aketh %' AND `faction` = 35;
