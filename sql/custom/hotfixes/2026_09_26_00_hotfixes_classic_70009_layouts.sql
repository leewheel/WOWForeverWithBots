-- WoW Classic beta 1.60.1.70009 DB2 layouts: hotfix table columns matching DB2LoadInfo.h / HotfixDatabase.cpp

-- AreaTable.db2 (9995B797)
ALTER TABLE `area_table` ADD `ExplorationLevel` tinyint NOT NULL DEFAULT '0' AFTER `UwZoneMusic`;

-- Cfg_Regions.db2 (66694D4D)
ALTER TABLE `cfg_regions` ADD `Name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci AFTER `Tag`;

DROP TABLE IF EXISTS `cfg_regions_locale`;
CREATE TABLE `cfg_regions_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Name_lang` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`,`locale`,`VerifiedBuild`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
/*!50500 PARTITION BY LIST  COLUMNS(locale)
(PARTITION deDE VALUES IN ('deDE') ENGINE = InnoDB,
 PARTITION esES VALUES IN ('esES') ENGINE = InnoDB,
 PARTITION esMX VALUES IN ('esMX') ENGINE = InnoDB,
 PARTITION frFR VALUES IN ('frFR') ENGINE = InnoDB,
 PARTITION itIT VALUES IN ('itIT') ENGINE = InnoDB,
 PARTITION koKR VALUES IN ('koKR') ENGINE = InnoDB,
 PARTITION ptBR VALUES IN ('ptBR') ENGINE = InnoDB,
 PARTITION ruRU VALUES IN ('ruRU') ENGINE = InnoDB,
 PARTITION zhCN VALUES IN ('zhCN') ENGINE = InnoDB,
 PARTITION zhTW VALUES IN ('zhTW') ENGINE = InnoDB) */;

-- CharacterLoadout.db2 (713CE8BB)
ALTER TABLE `character_loadout` ADD `Field_1_60_1_69876_003` int NOT NULL DEFAULT '0' AFTER `ItemContext`;

-- CurrencyTypes.db2 (EBEAF439)
ALTER TABLE `currency_types` ADD `MaxQtyCurveID` int NOT NULL DEFAULT '0' AFTER `AccountTransferPercentage`;

-- Faction.db2 (6D443C38)
ALTER TABLE `faction` ADD `RenownThresholdCurveID` int NOT NULL DEFAULT '0' AFTER `RenownCurrencyID`;

-- GlobalCurve.db2 (1DC57BDD)
ALTER TABLE `global_curve` ADD `Subtype` int NOT NULL DEFAULT '0' AFTER `Type`;

-- Item.db2 (9A2A4834) - Unknown1200 is AmmunitionType in this layout (same u8 column, kept name)
ALTER TABLE `item` ADD `ItemPetFoodID` int NOT NULL DEFAULT '0' AFTER `SheatheType`;

-- ItemSparse.db2 (6FCC3191)
ALTER TABLE `item_sparse` ADD `AmmunitionType` tinyint unsigned NOT NULL DEFAULT '0' AFTER `OverallQualityID`;

-- Map.db2 (D43AFAC3)
ALTER TABLE `map` ADD `OceanLiquidTypeID` int NOT NULL DEFAULT '0' AFTER `WdtFileDataID`;

-- NameGen.db2 (584300FA)
ALTER TABLE `name_gen` ADD `NameType` tinyint unsigned NOT NULL DEFAULT '0' AFTER `Sex`;

-- PlayerDataElementAccount.db2 / PlayerDataElementCharacter.db2 (C513161B)
ALTER TABLE `player_data_element_account` ADD `Field_12_1_5_69594_004` int NOT NULL DEFAULT '0' AFTER `Unknown1125`;
ALTER TABLE `player_data_element_character` ADD `Field_12_1_5_69594_004` int NOT NULL DEFAULT '0' AFTER `Unknown1125`;

-- SkillLineAbility.db2 (224F7EA0)
ALTER TABLE `skill_line_ability`
  ADD `Field_5_5_4_67090_0141` int NOT NULL DEFAULT '0' AFTER `SkillupSkillLineID`,
  ADD `Field_5_5_4_67090_0142` int NOT NULL DEFAULT '0' AFTER `Field_5_5_4_67090_0141`;

-- SpellItemEnchantment.db2 (952B72B2) - most columns widened to 32 bit, ConditionID maps to Field_12_1_5_69594_011
ALTER TABLE `spell_item_enchantment`
  MODIFY `Charges` int unsigned NOT NULL DEFAULT '0',
  MODIFY `Effect1` int unsigned NOT NULL DEFAULT '0',
  MODIFY `Effect2` int unsigned NOT NULL DEFAULT '0',
  MODIFY `Effect3` int unsigned NOT NULL DEFAULT '0',
  MODIFY `EffectPointsMin1` int NOT NULL DEFAULT '0',
  MODIFY `EffectPointsMin2` int NOT NULL DEFAULT '0',
  MODIFY `EffectPointsMin3` int NOT NULL DEFAULT '0',
  MODIFY `ScalingClass` int NOT NULL DEFAULT '0',
  MODIFY `ScalingClassRestricted` int NOT NULL DEFAULT '0',
  MODIFY `ConditionID` int unsigned NOT NULL DEFAULT '0',
  MODIFY `RequiredSkillID` int unsigned NOT NULL DEFAULT '0',
  MODIFY `RequiredSkillRank` int unsigned NOT NULL DEFAULT '0',
  MODIFY `MinLevel` int unsigned NOT NULL DEFAULT '0',
  MODIFY `MaxLevel` int unsigned NOT NULL DEFAULT '0',
  ADD `Field_12_1_5_69594_021` int NOT NULL DEFAULT '0' AFTER `TransmogCost`;

-- SpellProcsPerMinuteMod.db2 (A89F22A1)
ALTER TABLE `spell_procs_per_minute_mod` ADD `Field_12_1_5_69594_003` int NOT NULL DEFAULT '0' AFTER `Coeff`;

-- SpellVisualMissile.db2 (EC765EB2)
ALTER TABLE `spell_visual_missile`
  ADD `Field_12_1_5_69594_018` int NOT NULL DEFAULT '0' AFTER `Unused1100`,
  ADD `Field_12_1_5_69594_019` int NOT NULL DEFAULT '0' AFTER `Field_12_1_5_69594_018`,
  ADD `Field_12_1_5_69594_020` int NOT NULL DEFAULT '0' AFTER `Field_12_1_5_69594_019`,
  ADD `Field_12_1_5_69594_021` int NOT NULL DEFAULT '0' AFTER `Field_12_1_5_69594_020`;

-- TraitCurrency.db2 (A8B0874B)
ALTER TABLE `trait_currency` ADD `SourcedMax` int NOT NULL DEFAULT '0' AFTER `PlayerDataElementCharacterID`;

-- TraitCurrencySource.db2 (4C49B6AA)
ALTER TABLE `trait_currency_source` ADD `SuperDistrictSetID` int NOT NULL DEFAULT '0' AFTER `TraitNodeEntryID`;
