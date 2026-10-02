-- Classic 1.60: SmartAI of the new-zone creatures from the spells they cast in ymir sniffs of the official beta, build 70124
-- (classic_re/sniff/sniff_ai.py): timings are the medians seen (first cast after the attack start, repeat gap).
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` IN (251115,251143,251145,251160,251261,251284,251366,251374,251404,251448,251451,251662,251902,251918,251966,252068,252481,255534,256935,257521,267599);
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (251115,251143,251145,251160,251261,251284,251366,251374,251404,251448,251451,251662,251902,251918,251966,252068,252481,255534,256935,257521,267599);
INSERT INTO `smart_scripts` (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`target_type`,`comment`) VALUES
(251115,0,0,0,0,0,100,0,600,1000,8000,12000,11,11430,0,2,'Urs''anah - In Combat - Cast ''11430'' on Victim'),
(251143,0,0,0,6,0,100,0,0,0,0,0,3,0,131873,1,'Roiling Winds - On Death - Morph to Model 131873'),
(251143,0,1,0,0,0,100,0,2000,5000,1800,3000,11,1248802,0,2,'Roiling Winds - In Combat - Cast ''1248802'' on Victim'),
(251143,0,2,0,25,0,100,0,0,0,0,0,11,1291834,0,1,'Roiling Winds - On Reset - Cast ''1291834'' on Self'),
(251145,0,0,0,0,0,100,0,4500,7500,8000,12000,11,1259652,0,2,'Al''Aketh Brute - In Combat - Cast ''1259652'' on Victim'),
(251160,0,0,0,0,0,100,0,1000,1600,8200,13600,11,1259652,0,2,'Al''Aketh Convert - In Combat - Cast ''1259652'' on Victim'),
(251261,0,0,0,0,0,100,0,6600,11100,8000,12000,11,11430,0,2,'Hippogryph Matriarch - In Combat - Cast ''11430'' on Victim'),
(251261,0,1,0,0,0,100,0,1800,3000,8000,12000,11,1259652,0,2,'Hippogryph Matriarch - In Combat - Cast ''1259652'' on Victim'),
(251284,0,0,0,0,0,100,0,2600,4300,16400,27300,11,1259652,0,2,'Hippogryph Protector - In Combat - Cast ''1259652'' on Victim'),
(251366,0,0,0,1,0,100,0,1000,3000,12800,21300,11,1254892,0,1,'Aetheen of the Gales - Out of Combat - Cast ''1254892'' on Self'),
(251374,0,0,0,25,0,100,0,0,0,0,0,11,9200,0,1,'Windshaper Boro - On Reset - Cast ''9200'' on Self'),
(251404,0,0,0,0,0,100,0,8200,13600,8000,12000,11,1271513,0,2,'Cirrusfly Queen - In Combat - Cast ''1271513'' on Victim'),
(251448,0,0,0,0,0,100,0,3200,5300,8000,12000,11,1271521,0,2,'Al''Aketh Neophyte - In Combat - Cast ''1271521'' on Victim'),
(251451,0,0,0,0,0,100,0,500,800,8200,13600,11,14873,0,2,'Al''Aketh Ambusher - In Combat - Cast ''14873'' on Victim'),
(251451,0,1,0,25,0,100,0,0,0,0,0,11,1270462,0,1,'Al''Aketh Ambusher - On Reset - Cast ''1270462'' on Self'),
(251662,0,0,0,1,0,100,0,1000,3000,900,1500,11,1253931,0,1,'Living Lightning - Out of Combat - Cast ''1253931'' on Self'),
(251662,0,1,0,0,0,100,0,2200,3600,10900,18200,11,1271522,0,2,'Living Lightning - In Combat - Cast ''1271522'' on Victim'),
(251902,0,0,0,1,0,100,0,1000,3000,4000,6600,11,1255951,0,1,'Illaya Amberwind - Out of Combat - Cast ''1255951'' on Self'),
(251918,0,0,0,25,0,100,0,0,0,0,0,11,1266456,0,1,'Highlands Bandit - On Reset - Cast ''1266456'' on Self'),
(251966,0,0,0,0,0,100,0,2700,4500,8200,13800,11,1259652,0,2,'Commander Cyclas - In Combat - Cast ''1259652'' on Victim'),
(252068,0,0,0,0,0,100,0,6400,10700,4900,8200,11,1259652,0,2,'Al''Aketh Stormcaller - In Combat - Cast ''1259652'' on Victim'),
(252068,0,1,0,0,0,100,0,6400,10600,8000,12000,11,1269323,0,1,'Al''Aketh Stormcaller - In Combat - Cast ''1269323'' on Self'),
(252481,0,0,0,25,0,100,0,0,0,0,0,11,1253200,0,1,'Wind Sprite - On Reset - Cast ''1253200'' on Self'),
(255534,0,0,0,0,0,100,0,5400,9100,8000,12000,11,1265416,0,2,'"Badwind" Bennic - In Combat - Cast ''1265416'' on Victim'),
(256935,0,0,0,0,0,100,0,1800,3000,6000,10100,11,1259652,0,2,'Malduko Cloudcrush - In Combat - Cast ''1259652'' on Victim'),
(257521,0,0,0,0,0,100,0,2200,3700,2800,4700,11,9672,0,2,'High Order Apprentice - In Combat - Cast ''9672'' on Victim'),
(257521,0,1,0,25,0,100,0,0,0,0,0,11,1309170,0,1,'High Order Apprentice - On Reset - Cast ''1309170'' on Self'),
(267599,0,0,0,25,0,100,0,0,0,0,0,11,1299003,0,1,'Energizing Vortex - On Reset - Cast ''1299003'' on Self'),
(267599,0,1,0,25,0,100,0,0,0,0,0,11,1299005,0,1,'Energizing Vortex - On Reset - Cast ''1299005'' on Self');
