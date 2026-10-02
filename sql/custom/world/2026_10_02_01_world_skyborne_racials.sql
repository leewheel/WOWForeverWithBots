-- Classic 1.60: Skyborne racials (races 95 High Order / 96 Windshaper, RaceMask bits 32 and 33 = 0x300000000), as the official beta
-- gives them (ymir sniff of a new Skyborne hunter): the client data does not link them to the races, so new characters had none.
-- Elemental Blessing (1259688) is not learned: it is the aura one of these applies.
DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` = 12884901888 AND `Spell` IN (1259707,1259710,1259416,1259686);
INSERT INTO `playercreateinfo_spell_custom` (`racemask`,`classmask`,`Spell`,`Note`) VALUES
(12884901888,0,1259707,'Skyborne - Elemental Insight (passive)'),
(12884901888,0,1259710,'Skyborne - Wind Blessed (passive)'),
(12884901888,0,1259416,'Skyborne - Walk on Air'),
(12884901888,0,1259686,'Skyborne - Skysight');
