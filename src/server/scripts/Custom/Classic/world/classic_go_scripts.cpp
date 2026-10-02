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
#include "SpellAuraEffects.h"
#include "SpellScript.h"

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

// Classic 1.60 (WoW Forever): sitting near a campfire starts this 60 s rest (WorldSession::HandleStandStateChangeOpcode); when it
// runs out the player gets Boosted Rest (1229451) and, still sitting by the fire, the next rest starts (ymir sniff of the official
// beta). Standing up removes it early, so the minute has to be sat out in one go ("The Great Outdoors").
enum CampfireRest
{
    SPELL_CAMPFIRE_REST     = 1289723,
    SPELL_BOOSTED_REST      = 1229451,
    SPELL_FOCUS_CAMPFIRE    = 4
};

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
        target->CastSpell(target, SPELL_BOOSTED_REST, true);
        if (target->GetStandState() == UNIT_STAND_STATE_SIT)
            target->CastSpell(target, SPELL_CAMPFIRE_REST, true);
    }

    void Register() override
    {
        AfterEffectRemove += AuraEffectRemoveFn(classic_spell_campfire_rest::AfterRemove, EFFECT_0, SPELL_AURA_ANY, AURA_EFFECT_HANDLE_REAL);
    }
};

void AddSC_classic_go_scripts()
{
    RegisterGameObjectAI(classic_go_field_repair_bot_74A);
    RegisterSpellScript(classic_spell_campfire_rest);
}
