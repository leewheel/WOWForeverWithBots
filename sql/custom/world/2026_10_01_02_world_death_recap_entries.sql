-- Death recap actors move from 9100000-9102000 to 8100000-8102000: the Classic client's creature GUID holds only 23 bits of
-- entry, so actors above 8388607 got a GUID entry that didn't match their object and failed the client's create validation
-- ("Failed to validate JamCliObjCreate", disconnect).
UPDATE `creature_template` SET `entry` = `entry` - 1000000 WHERE `entry` BETWEEN 9100000 AND 9102000;
UPDATE `creature_template_model` SET `CreatureID` = `CreatureID` - 1000000 WHERE `CreatureID` BETWEEN 9100000 AND 9102000;
UPDATE `creature_template_difficulty` SET `Entry` = `Entry` - 1000000 WHERE `Entry` BETWEEN 9100000 AND 9102000;
