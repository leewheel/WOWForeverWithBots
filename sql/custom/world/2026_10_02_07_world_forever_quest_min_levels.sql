-- Classic 1.60: level range of the Forever quests (ID >= 90000). The official server's quest data gives only the quest level
-- (quest_template_classic_level, from the sniffs); like vanilla (minimum mostly 2-4 below the quest level) they are offered from
-- quest level - 3, at least 1.
DELETE FROM `quest_classic_level` WHERE `ID` >= 90000;
INSERT INTO `quest_classic_level` (`ID`,`QuestLevel`,`MinLevel`,`MaxLevel`)
SELECT `ID`, `QuestLevel`, GREATEST(1, `QuestLevel` - 3), 0 FROM `quest_template_classic_level` WHERE `ID` >= 90000 AND `QuestLevel` > 0;
