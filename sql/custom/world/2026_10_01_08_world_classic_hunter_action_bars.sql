-- Classic 1.60: starting action bars of the Tauren and Skyborne hunters as the official beta sets them (first login, ymir sniffs):
-- Auto Attack, Raptor Strike, Auto Shot, Track Beasts (Tauren), the racials, water and food; the retail rows had Steady Shot (56641).
DELETE FROM `playercreateinfo_action` WHERE `class` = 3 AND `race` IN (6,96);
INSERT INTO `playercreateinfo_action` (`race`,`class`,`button`,`action`,`type`) VALUES
(6,3,0,6603,0),
(6,3,1,2973,0),
(6,3,2,75,0),
(6,3,3,1494,0),
(6,3,8,20549,0),
(6,3,9,20552,0),
(6,3,10,159,128),
(6,3,11,117,128),
(96,3,0,6603,0),
(96,3,1,2973,0),
(96,3,2,75,0),
(96,3,8,1259686,0),
(96,3,9,1259416,0),
(96,3,10,159,128),
(96,3,11,117,128);
