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

void AddSC_classic_go_scripts()
{
    RegisterGameObjectAI(classic_go_field_repair_bot_74A);
}
