-- Classic 1.60 (WoW Forever): Hungry Bandits (252802) are stealthed (official beta sniff 70170: they cast Sneak 22766 = stealth +
-- slower movement, and carry Sneak 7939, a dummy aura of the client). As addon auras they are applied at spawn and again after
-- evading. Safe to run again.
INSERT INTO `creature_template_addon` (`entry`, `auras`) VALUES (252802, '22766 7939')
ON DUPLICATE KEY UPDATE `auras` = '22766 7939';
