/*
 * This file is part of the TrinityCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Classic 1.60 port of VMaNGOS src/scripts/world/go_scripts.cpp (ScriptDev2 lineage, GPL-2)
// Field Repair Bot 74A schematic: teaches spell 22704 to engineers (skill >= 300)

#include "ScriptMgr.h"
#include "GameObject.h"
#include "GameObjectAI.h"
#include "Player.h"
#include "SharedDefines.h"
#include "Creature.h"
#include "RestMgr.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "SpellScript.h"
#include "UpdateFields.h"
#include <set>

/*######
## go_field_repair_bot_74A
######*/

enum FieldRepairBot74A
{
    FIELD_REPAIR_BOT_SPELL_LEARNED  = 22704,    // Field Repair Bot 74A
    FIELD_REPAIR_BOT_SPELL_LEARN    = 22864,    // teaches 22704
    FIELD_REPAIR_BOT_SKILL_REQUIRED = 300
};

struct classic_go_field_repair_bot_74A : public GameObjectAI
{
    classic_go_field_repair_bot_74A(GameObject* go) : GameObjectAI(go) { }

    bool OnGossipHello(Player* player) override
    {
        if (player->HasSkill(SKILL_ENGINEERING) && player->GetBaseSkillValue(SKILL_ENGINEERING) >= FIELD_REPAIR_BOT_SKILL_REQUIRED
            && !player->HasSpell(FIELD_REPAIR_BOT_SPELL_LEARNED))
            player->CastSpell(player, FIELD_REPAIR_BOT_SPELL_LEARN, false);
        return true;
    }
};

/*######
## classic_spell_campfire_rest (1289723)
######*/

// Classic 1.60 (WoW Forever) camping: sitting near a campfire starts this 60 s rest (WorldSession::HandleStandStateChangeOpcode);
// when it runs out the player gets the "Boosted ..." buff of every camp feature placed near the fire (client spell texts: "Players
// sitting or crafting nearby for 1 min will gain benefits from other camp features") and, still sitting by the fire, the next rest
// starts (ymir sniff of the official beta). Standing up removes it early, so the minute has to be sat out in one go.
enum CampfireRest
{
    SPELL_CAMPFIRE_REST         = 1289723,
    SPELL_BOOSTED_REST          = 1229451,  // Camp Tent
    SPELL_BOOSTED_CRIT          = 1229519,  // Camp Chair
    SPELL_BOOSTED_ATTACK_POWER  = 1230164,  // Lodestone
    SPELL_BOOSTED_MANA_REGEN    = 1230587,  // Mana Well
    SPELL_EXTRA_STRENGTH        = 1230172,  // Sharpening Wheel
    SPELL_BOOSTED_INTELLECT     = 1229513,  // Incense Candle
    SPELL_BOOSTED_SPIRIT        = 1229718,  // Faction Banner
    SPELL_BOOSTED_STAMINA       = 1230124,  // First Aid Kit
    SPELL_BOOSTED_STATS_PCT     = 1230098,  // Fish Bowl
    SPELL_BOOSTED_STATS_LUTE    = 1230653,  // Enchanted Lute: armor, all stats, all resistances
    SPELL_CAMP_BENEFITS         = 1229741,  // visible summary buff ("Gained the following camp benefits: ...")
    SPELL_FOCUS_CAMPFIRE        = 4
};

static constexpr float CAMPFIRE_RANGE = 15.0f;      // sitting this close to the fire (same as HandleStandStateChangeOpcode)
static constexpr float CAMP_FEATURE_RANGE = 20.0f;  // features this close to the fire count ("Camp Benefits" 1229741, radius 9)

// Camp features -> their "Boosted ..." buff. The features are the gameobjects summoned by the placement spells (1307229 Camp Chair,
// 1307254 Lodestone, ... effect 50); only Chair, Lodestone and Mana Well have templates so far (sniffed next to the camping
// trainer's fire), the others need a sniff of placing them. The trainer's camp has its tent as a creature.
struct CampFeature
{
    uint32 Entry;
    bool IsCreature;
    uint32 Buff;
};

static constexpr CampFeature CampFeatures[] =
{
    { 263398, true,  SPELL_BOOSTED_REST },          // Camp Tent (creature, camping trainer's camp)
    { 528996, false, SPELL_BOOSTED_REST },          // Camp Tent
    { 612275, false, SPELL_BOOSTED_CRIT },          // Camp Chair
    { 651956, false, SPELL_BOOSTED_ATTACK_POWER },  // Lodestone
    { 651948, false, SPELL_BOOSTED_MANA_REGEN },    // Mana Well
    { 651950, false, SPELL_EXTRA_STRENGTH },        // Sharpening Wheel
    { 651955, false, SPELL_BOOSTED_INTELLECT },     // Incense Candle
    { 612350, false, SPELL_BOOSTED_SPIRIT },        // Faction Banner
    { 612351, false, SPELL_BOOSTED_SPIRIT },        // Faction Banner
    { 651953, false, SPELL_BOOSTED_STAMINA },       // First Aid Kit
    { 651954, false, SPELL_BOOSTED_STATS_PCT },     // Fish Bowl
    { 651952, false, SPELL_BOOSTED_STATS_LUTE },    // Enchanted Lute
};

// The buffs scale with level in steps (client tooltips: "$?$PL<12[3]?$PL<24[8]...[$1230124s1]"); the spell's own value is the
// highest step. Returns the value for 'level', or -1 to keep the spell's value.
struct CampTier { uint8 BelowLevel; int32 Value; };

static int32 CampTierValue(uint8 level, std::initializer_list<CampTier> tiers)
{
    for (CampTier const& tier : tiers)
        if (level < tier.BelowLevel)
            return tier.Value;
    return -1;
}

static void CastCampBuff(Unit* target, uint32 buff)
{
    uint8 level = target->GetLevel();
    CastSpellExtraArgs args(TRIGGERED_FULL_MASK);
    auto setValue = [&](uint8 effIndex, int32 value)
    {
        if (value >= 0)
            args.AddSpellMod(SpellValueModFloat(SPELLVALUE_BASE_POINT0 + effIndex), float(value));
    };

    switch (buff)
    {
        case SPELL_BOOSTED_STAMINA:
            setValue(0, CampTierValue(level, { { 12, 3 }, { 24, 8 }, { 36, 21 }, { 48, 34 }, { 60, 45 } }));
            break;
        case SPELL_BOOSTED_ATTACK_POWER:
            setValue(0, CampTierValue(level, { { 12, 12 }, { 22, 20 }, { 32, 32 }, { 42, 49 }, { 52, 67 } }));
            break;
        case SPELL_BOOSTED_MANA_REGEN:
            setValue(0, CampTierValue(level, { { 24, 10 }, { 34, 15 }, { 44, 20 }, { 54, 24 } }));
            break;
        case SPELL_EXTRA_STRENGTH:
            setValue(0, CampTierValue(level, { { 24, 6 }, { 38, 11 }, { 52, 20 } }));
            break;
        case SPELL_BOOSTED_INTELLECT:
            setValue(0, CampTierValue(level, { { 14, 2 }, { 28, 6 }, { 42, 12 }, { 56, 18 } }));
            break;
        case SPELL_BOOSTED_SPIRIT:
            setValue(0, CampTierValue(level, { { 40, 14 }, { 50, 19 }, { 60, 27 } }));
            break;
        case SPELL_BOOSTED_STATS_LUTE:
        {
            setValue(0, CampTierValue(level, { { 10, 28 }, { 20, 71 }, { 30, 114 }, { 40, 163 }, { 50, 211 }, { 60, 260 } }));
            setValue(1, CampTierValue(level, { { 10, 0 }, { 20, 2 }, { 30, 4 }, { 40, 7 }, { 50, 9 }, { 60, 12 } }));
            int32 resistance = CampTierValue(level, { { 30, 0 }, { 40, 6 }, { 50, 12 }, { 60, 16 } });
            for (uint8 i = 2; i <= 7; ++i)
                setValue(i, resistance);
            break;
        }
        default:    // Boosted Rest, Critical Chance and Stats (%) don't scale
            break;
    }
    target->CastSpell(target, buff, args);
}

// the campfire (spell focus 4) the player is resting at, nullptr if none is close enough
static GameObject* FindCampfire(Unit* unit)
{
    GameObject* fire = unit->FindNearestGameObjectOfType(GAMEOBJECT_TYPE_SPELL_FOCUS, CAMPFIRE_RANGE);
    return fire && fire->GetGOInfo()->spellFocus.spellFocusType == SPELL_FOCUS_CAMPFIRE ? fire : nullptr;
}

class classic_spell_campfire_rest : public AuraScript
{
    bool Validate(SpellInfo const* /*spellInfo*/) override
    {
        return ValidateSpellInfo({ SPELL_BOOSTED_REST });
    }

    void AfterRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        if (GetTargetApplication()->GetRemoveMode() != AURA_REMOVE_BY_EXPIRE)
            return;

        Unit* target = GetTarget();
        GameObject* fire = FindCampfire(target);
        if (!fire)
            return;

        std::set<uint32> buffs;
        for (CampFeature const& feature : CampFeatures)
        {
            bool nearFire = feature.IsCreature ? fire->FindNearestCreature(feature.Entry, CAMP_FEATURE_RANGE) != nullptr
                : fire->FindNearestGameObject(feature.Entry, CAMP_FEATURE_RANGE) != nullptr;
            if (nearFire && sSpellMgr->GetSpellInfo(feature.Buff, DIFFICULTY_NONE))
                buffs.insert(feature.Buff);
        }
        for (uint32 buff : buffs)
            CastCampBuff(target, buff);
        // the Boosted buffs are hidden auras (Attributes 0x80); the visible buff is Camp Benefits, whose tooltip lists every one of them
        // the player has (official beta sniff: both in the same aura updates). Its other effects are area dummies, so add the aura only.
        if (!buffs.empty() && sSpellMgr->GetSpellInfo(SPELL_CAMP_BENEFITS, DIFFICULTY_NONE))
            target->AddAura(SPELL_CAMP_BENEFITS, target);

        if (target->IsSitState())
            target->CastSpell(target, SPELL_CAMPFIRE_REST, true);
    }

    void Register() override
    {
        AfterEffectRemove += AuraEffectRemoveFn(classic_spell_campfire_rest::AfterRemove, EFFECT_0, SPELL_AURA_ANY, AURA_EFFECT_HANDLE_REAL);
    }
};

/*######
## classic_spell_boosted_rest (1229451)
######*/

// Boosted Rest, the Camp Tent's benefit: "increase Rested experience to <effect value>% of a level. No effect if Rested experience
// already exceeds that value." (client spell text; effect 0 is a dummy with value 5)
class classic_spell_boosted_rest : public SpellScript
{
    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* player = Object::ToPlayer(GetHitUnit());
        if (!player)
            return;

        float wanted = float(*player->m_activePlayerData->NextLevelXP) * float(GetEffectValue()) / 100.0f;
        if (player->GetRestMgr().GetRestBonus(REST_TYPE_XP) < wanted)
            player->GetRestMgr().SetRestBonus(REST_TYPE_XP, wanted);
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(classic_spell_boosted_rest::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

/*######
## classic_go_camp_chair (612275)
######*/

// Sitting in a Camp Chair goes through GameObject::Use, not CMSG_STAND_STATE_CHANGE, so start the campfire rest here as well;
// returning false lets the chair seat the player as usual (standing up later removes the rest in HandleStandStateChangeOpcode)
struct classic_go_camp_chair : public GameObjectAI
{
    classic_go_camp_chair(GameObject* go) : GameObjectAI(go) { }

    bool OnGossipHello(Player* player) override
    {
        if (!player->HasAura(SPELL_CAMPFIRE_REST) && FindCampfire(player))
            player->CastSpell(player, SPELL_CAMPFIRE_REST, true);
        return false;
    }
};

void AddSC_classic_go_scripts()
{
    RegisterGameObjectAI(classic_go_field_repair_bot_74A);
    RegisterGameObjectAI(classic_go_camp_chair);
    RegisterSpellScript(classic_spell_campfire_rest);
    RegisterSpellScript(classic_spell_boosted_rest);
}
