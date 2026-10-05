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

// Classic 1.60 class spell scripts.

#include "ScriptMgr.h"
#include "AreaTrigger.h"
#include "Creature.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "SpellScript.h"
#include "Unit.h"

/*######
## classic_spell_ground_area_damage
######*/

// Classic 1.60 ground spells (official client data): the spell creates an area trigger (effect 1) and puts a periodic dummy aura
// on the caster (effect 2); every tick damages the enemies inside the caster's area trigger of that spell. The client data has
// no damage spell or per-rank damage for them (placeholder values on effect 0): the tick damage per rank is the vanilla one
// (VMaNGOS spell_template, persistent area aura base points + 1), the spell power share per tick the vanilla coefficient.
struct ClassicGroundAreaDamage
{
    uint32 TickDamage;
    float Coefficient;      // spell power per tick
};

static std::unordered_map<uint32, ClassicGroundAreaDamage> const ClassicGroundAreaDamages =
{
    // Blizzard (frost, 1 s, 8 s channel): 33% spell power over 8 ticks
    { 10,    {  25, 0.0417f } }, { 6141,  {  44, 0.0417f } }, { 8427,  {  65, 0.0417f } },
    { 10185, {  90, 0.0417f } }, { 10186, { 117, 0.0417f } }, { 10187, { 149, 0.0417f } },
    // Flamestrike burning ground (fire, 2 s, 8 s; the direct hit is effect 0): ~12% spell power over 4 ticks
    { 2120,  {  12, 0.0305f } }, { 2121,  {  22, 0.0305f } }, { 8422,  {  35, 0.0305f } },
    { 8423,  {  49, 0.0305f } }, { 10215, {  66, 0.0305f } }, { 10216, {  85, 0.0305f } },
    // Rain of Fire (fire, 2 s, 8 s channel): 33% spell power over 4 ticks
    { 5740,  {  42, 0.0833f } }, { 6219,  {  96, 0.0833f } }, { 11677, { 155, 0.0833f } }, { 11678, { 226, 0.0833f } },
    // Volley (arcane, 1 s, 6 s channel): no spell power
    { 1510,  {  50, 0.0f } }, { 14294, {  65, 0.0f } }, { 14295, {  80, 0.0f } },
};

class classic_spell_ground_area_damage : public AuraScript
{
    bool Validate(SpellInfo const* spellInfo) override
    {
        return ClassicGroundAreaDamages.contains(spellInfo->Id);
    }

    void HandleTick(AuraEffect const* /*aurEff*/)
    {
        Unit* caster = GetCaster();
        if (!caster)
            return;

        SpellInfo const* spellInfo = GetSpellInfo();
        ClassicGroundAreaDamage const& values = ClassicGroundAreaDamages.at(spellInfo->Id);

        GuidUnorderedSet targets;
        for (AreaTrigger* areaTrigger : caster->GetAreaTriggers(spellInfo->Id))
            targets.insert(areaTrigger->GetInsideUnits().begin(), areaTrigger->GetInsideUnits().end());

        for (ObjectGuid const& guid : targets)
        {
            Unit* target = ObjectAccessor::GetUnit(*caster, guid);
            if (!target || !target->IsAlive() || !caster->IsValidAttackTarget(target, spellInfo))
                continue;

            int32 damage = values.TickDamage;
            if (values.Coefficient > 0.0f)
                damage += int32(caster->SpellBaseDamageBonusDone(spellInfo->GetSchoolMask()) * values.Coefficient);
            damage = target->SpellDamageBonusTaken(caster, spellInfo, damage, DOT);

            SpellNonMeleeDamage damageInfo(caster, target, spellInfo, GetAura()->GetSpellVisual(), spellInfo->GetSchoolMask(), GetAura()->GetCastId());
            damageInfo.periodicLog = true;
            caster->CalculateSpellDamageTaken(&damageInfo, damage, spellInfo);
            Unit::DealDamageMods(damageInfo.attacker, damageInfo.target, damageInfo.damage, &damageInfo.absorb);
            caster->SendSpellNonMeleeDamageLog(&damageInfo);
            caster->DealSpellDamage(&damageInfo, true);
        }
    }

    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        // channels (Blizzard, Rain of Fire, Volley): the ground effect ends with the channel
        if (GetSpellInfo()->IsChanneled())
            if (Unit* caster = GetCaster())
                caster->RemoveAreaTrigger(GetSpellInfo()->Id);
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(classic_spell_ground_area_damage::HandleTick, EFFECT_2, SPELL_AURA_PERIODIC_DUMMY);
        AfterEffectRemove += AuraEffectRemoveFn(classic_spell_ground_area_damage::HandleRemove, EFFECT_2, SPELL_AURA_PERIODIC_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// Classic 1.60 (WoW Forever), Shen'dar Highlands cave, quest 94489 (official beta sniff 70205): clicking an injured druid makes the
// player cast 1276047 (dummy) on it. Credit "Injured Druids healed" (257964) and the druid's own hidden objective (its entry).
enum ClassicHealInjuredDruid
{
    NPC_INJURED_DRUIDS_HEALED_CREDIT = 257964
};

class classic_spell_heal_injured_druid : public SpellScript
{
    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* player = GetCaster()->ToPlayer();
        Creature* druid = GetHitCreature();
        if (!player || !druid)
            return;

        player->KilledMonsterCredit(NPC_INJURED_DRUIDS_HEALED_CREDIT);
        player->KilledMonsterCredit(druid->GetEntry());
        druid->SetStandState(UNIT_STAND_STATE_STAND);
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(classic_spell_heal_injured_druid::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// Classic 1.60 (WoW Forever) profession books: Mining for Dummies (247840, 1245608), Wild Harvest (247841, 1245609), Pelt Collecting for
// Beginners (247846, 1245610). "Increases your <profession> skill by $m1. Cannot raise <profession> skill over $m2. You will learn
// <profession> if it is not already trained and you do not already know two other professions." Both effects are dummies.
class classic_spell_profession_book : public SpellScript
{
    struct BookProfession
    {
        uint32 SpellId;
        uint32 SkillId;
        uint32 ApprenticeSpell;
    };

    static BookProfession const* GetProfession(uint32 spellId)
    {
        static BookProfession const books[] =
        {
            { 1245608, SKILL_MINING,    2575 },     // Mining (Apprentice)
            { 1245609, SKILL_HERBALISM, 2366 },     // Herb Gathering (Apprentice)
            { 1245610, SKILL_SKINNING,  8613 },     // Skinning (Apprentice)
        };
        for (BookProfession const& book : books)
            if (book.SpellId == spellId)
                return &book;
        return nullptr;
    }

    uint32 GetCap() const
    {
        return uint32(std::max<int32>(GetSpellInfo()->GetEffect(EFFECT_1).CalcValue(), 1));
    }

    SpellCastResult CheckCast()
    {
        Player* player = GetCaster()->ToPlayer();
        BookProfession const* book = GetProfession(GetSpellInfo()->Id);
        if (!player || !book)
            return SPELL_FAILED_DONT_REPORT;

        if (player->HasSkill(book->SkillId))
            return player->GetPureSkillValue(book->SkillId) < GetCap() ? SPELL_CAST_OK : SPELL_FAILED_CANT_DO_THAT_RIGHT_NOW;

        return player->GetFreePrimaryProfessionPoints() > 0 ? SPELL_CAST_OK : SPELL_FAILED_CANT_DO_THAT_RIGHT_NOW;
    }

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* player = GetCaster()->ToPlayer();
        BookProfession const* book = GetProfession(GetSpellInfo()->Id);
        if (!player || !book)
            return;

        if (!player->HasSkill(book->SkillId))
            player->LearnSpell(book->ApprenticeSpell, false);
        if (!player->HasSkill(book->SkillId))
            return;

        uint16 const current = player->GetPureSkillValue(book->SkillId);
        uint16 const target = uint16(std::min<uint32>(current + uint32(GetEffectValue()), GetCap()));
        if (target > current)
            player->SetSkill(book->SkillId, player->GetSkillStep(book->SkillId), target, player->GetPureMaxSkillValue(book->SkillId));
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(classic_spell_profession_book::CheckCast);
        OnEffectHitTarget += SpellEffectFn(classic_spell_profession_book::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

void AddSC_classic_spell_scripts()
{
    RegisterSpellScript(classic_spell_profession_book);
    RegisterSpellScript(classic_spell_ground_area_damage);
    RegisterSpellScript(classic_spell_heal_injured_druid);
}
