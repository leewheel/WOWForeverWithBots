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

// Classic 1.60 port of VMaNGOS src/scripts/world/npcs_special.cpp (ScriptDev2 lineage, GPL-2)
// Quest support: 6124, 6129 (Curing the Sick: Sickly Deer / Sickly Gazelle)

#include "ScriptMgr.h"
#include "Creature.h"
#include "Map.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "PassiveAI.h"
#include "Player.h"
#include "SpellInfo.h"

/*
 * Curing the Sick
 */

enum SicklyCritter
{
    SICKLY_SPELL_APPLY_SALVE        = 19512,
    SICKLY_SPELL_SICKLY_AURA        = 19502,

    SICKLY_NPC_SICKLY_DEER          = 12298,
    SICKLY_NPC_SICKLY_GAZELLE       = 12296,

    SICKLY_NPC_CURED_DEER           = 12299,
    SICKLY_NPC_CURED_GAZELLE        = 12297,

    SICKLY_MODEL_CURED_DEER         = 347,
    SICKLY_MODEL_CURED_GAZELLE      = 1547
};

struct classic_npc_sickly_critter : public CritterAI
{
    classic_npc_sickly_critter(Creature* creature) : CritterAI(creature), _team(HORDE)
    {
        ResetCreature();
    }

    void JustAppeared() override
    {
        ResetCreature();
        CritterAI::JustAppeared();
    }

    void ResetCreature()
    {
        _isHit = false;
        _modify = false;
        _timer = 1500;
    }

    void SpellHit(WorldObject* caster, SpellInfo const* spellInfo) override
    {
        if (spellInfo->Id != SICKLY_SPELL_APPLY_SALVE)
            return;

        if (_isHit)
            return;

        Player* player = caster ? caster->ToPlayer() : nullptr;
        if (!player)
            return;

        _playerGUID = player->GetGUID();

        if (me->GetEntry() != SICKLY_NPC_SICKLY_DEER && me->GetEntry() != SICKLY_NPC_SICKLY_GAZELLE)
            return;

        _team = player->GetTeam();
        _modify = true;

        me->GetMotionMaster()->Clear();
        me->GetMotionMaster()->MoveFleeing(player);
        me->DespawnOrUnsummon(10s);

        _isHit = true;
    }

    void UpdateAI(uint32 diff) override
    {
        if (_modify)
        {
            if (_timer < diff)
            {
                // VMaNGOS rewards through RewardPlayerAndGroupAtCast (ReqCreatureOrGOId = cured entry, ReqSpellCast = 19512);
                // TC quest objectives 6124/6129 are QUEST_OBJECTIVE_MONSTER on the cured entry, so give kill credit for it.
                uint32 curedEntry = SICKLY_NPC_CURED_GAZELLE;
                switch (_team)
                {
                    case ALLIANCE:
                        curedEntry = SICKLY_NPC_CURED_DEER;
                        me->SetEntry(SICKLY_NPC_CURED_DEER);
                        me->SetDisplayId(SICKLY_MODEL_CURED_DEER);
                        break;
                    default: // HORDE
                        me->SetEntry(SICKLY_NPC_CURED_GAZELLE);
                        me->SetDisplayId(SICKLY_MODEL_CURED_GAZELLE);
                        break;
                }

                me->RemoveAurasDueToSpell(SICKLY_SPELL_SICKLY_AURA);
                _modify = false;

                if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGUID))
                    player->RewardPlayerAndGroupAtEvent(curedEntry, me);
            }
            else
                _timer -= diff;
        }

        CritterAI::UpdateAI(diff);
    }

private:
    bool _isHit;
    bool _modify;
    uint32 _timer;
    Team _team;
    ObjectGuid _playerGUID;
};

void AddSC_classic_npcs_special()
{
    RegisterCreatureAI(classic_npc_sickly_critter);
}
