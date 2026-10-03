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
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "TemporarySummon.h"
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

/*######
## classic_npc_malfunctioning_cyclone_construct (250929)
######*/

// Classic 1.60 (WoW Forever), Zephras Isle orchard, quest Standing Our Ground (92693; official beta sniffs, builds 70170 / 70205):
// "I'm ready to fight, Aamelia." gives the talk credit, Aamelia runs to the orchard's edge, then Ferauu the Bludgeon and six Bandit
// Henchmen appear on the road, Ferauu yells and they walk down to the orchard. ~20 s after they appeared the construct, which
// wanders by its post otherwise, walks over, yells, kills them with Chain Lightning and yells again; Aamelia casts Make Your Stand
// (the Ferauu credit) and runs home.
enum CycloneConstructEvent
{
    NPC_AAMELIA_WINDFIELD           = 252800,
    NPC_FERAUU_THE_BLUDGEON         = 252863,
    NPC_BANDIT_HENCHMAN             = 252875,
    SPELL_CONSTRUCT_CHAIN_LIGHTNING = 1257106,
    SPELL_MAKE_YOUR_STAND           = 1257130,
    QUEST_STANDING_OUR_GROUND       = 92693,
    GOSSIP_MENU_AAMELIA             = 40780,

    ACTION_START_ORCHARD_EVENT      = 1,
    ACTION_ORCHARD_EVENT_DONE       = 2,

    EVENT_BANDITS_APPEAR            = 1,
    EVENT_CONSTRUCT_GO,
    EVENT_CONSTRUCT_STRIKE,
    EVENT_CONSTRUCT_DONE,
    EVENT_AAMELIA_GO_HOME,

    POINT_CONSTRUCT_STRIKE          = 1,
    POINT_CONSTRUCT_HOME            = 2,
    POINT_AAMELIA_HOME              = 100
};

static constexpr Milliseconds CycloneBanditsDelay = 1s;
static constexpr Milliseconds CycloneStrikeDelay = 20s;
static constexpr float CycloneWanderDistance = 15.0f;

static Position const FerauuStart       = { 2110.0f, 1543.5f, 664.7f, 3.6f };
static Position const FerauuEnd         = { 2071.0f, 1571.1f, 655.7f, 3.6f };
static Position const ConstructStrikeAt = { 2069.0f, 1557.4f, 655.2f, 1.6f };

// start (on the road) -> end (in the orchard) of each henchman
static std::pair<Position, Position> const HenchmanPaths[] =
{
    { { 2115.7f, 1548.3f, 665.8f, 3.6f }, { 2078.6f, 1573.9f, 657.0f, 3.6f } },
    { { 2117.1f, 1550.8f, 666.7f, 3.6f }, { 2075.6f, 1575.6f, 656.5f, 3.6f } },
    { { 2114.5f, 1550.3f, 666.0f, 3.6f }, { 2074.4f, 1572.8f, 656.0f, 3.6f } },
    { { 2106.5f, 1535.5f, 664.9f, 3.6f }, { 2073.2f, 1559.9f, 656.2f, 3.6f } },
    { { 2108.4f, 1537.7f, 665.1f, 3.6f }, { 2070.3f, 1562.3f, 655.9f, 3.6f } },
    { { 2105.8f, 1537.8f, 664.6f, 3.6f }, { 2068.4f, 1560.0f, 654.7f, 3.6f } },
};

struct classic_npc_malfunctioning_cyclone_construct : public ScriptedAI
{
    classic_npc_malfunctioning_cyclone_construct(Creature* creature) : ScriptedAI(creature), _summons(creature) { }

    void JustAppeared() override
    {
        _events.Reset();
        _busy = false;
        me->GetMotionMaster()->MoveRandom(CycloneWanderDistance);
    }

    void DoAction(int32 action) override
    {
        if (action != ACTION_START_ORCHARD_EVENT || _busy)
            return;

        _busy = true;
        _events.ScheduleEvent(EVENT_BANDITS_APPEAR, CycloneBanditsDelay);
    }

    void JustSummoned(Creature* summon) override
    {
        _summons.Summon(summon);
    }

    void SummonedCreatureDespawn(Creature* summon) override
    {
        _summons.Despawn(summon);
    }

    void MovementInform(uint32 type, uint32 id) override
    {
        if (type != POINT_MOTION_TYPE)
            return;

        if (id == POINT_CONSTRUCT_STRIKE)
        {
            me->Yell("THREAT DETECTED. ADMINISTERING VIOLENCE.", LANG_UNIVERSAL);
            _events.ScheduleEvent(EVENT_CONSTRUCT_STRIKE, 3s);
        }
        else if (id == POINT_CONSTRUCT_HOME)
            me->GetMotionMaster()->MoveRandom(CycloneWanderDistance);
    }

    void UpdateAI(uint32 diff) override
    {
        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_BANDITS_APPEAR:
                {
                    _summons.DespawnAll();
                    if (Creature* ferauu = me->SummonCreature(NPC_FERAUU_THE_BLUDGEON, FerauuStart, TEMPSUMMON_MANUAL_DESPAWN))
                    {
                        ferauu->Yell("Little apple farmers! Ferauu is here to collect what is owed!", LANG_UNIVERSAL);
                        ferauu->GetMotionMaster()->MovePoint(0, FerauuEnd);
                    }
                    for (auto const& [start, end] : HenchmanPaths)
                        if (Creature* henchman = me->SummonCreature(NPC_BANDIT_HENCHMAN, start, TEMPSUMMON_MANUAL_DESPAWN))
                            henchman->GetMotionMaster()->MovePoint(0, end);
                    _events.ScheduleEvent(EVENT_CONSTRUCT_GO, CycloneStrikeDelay);
                    break;
                }
                case EVENT_CONSTRUCT_GO:
                    me->GetMotionMaster()->Clear();
                    me->GetMotionMaster()->MovePoint(POINT_CONSTRUCT_STRIKE, ConstructStrikeAt);
                    break;
                case EVENT_CONSTRUCT_STRIKE:
                {
                    if (Creature* ferauu = me->FindNearestCreature(NPC_FERAUU_THE_BLUDGEON, 40.0f))
                        me->CastSpell(ferauu, SPELL_CONSTRUCT_CHAIN_LIGHTNING, true);
                    for (ObjectGuid const& guid : _summons)
                        if (Creature* bandit = ObjectAccessor::GetCreature(*me, guid))
                            if (bandit->IsAlive())
                            {
                                bandit->KillSelf();
                                bandit->DespawnOrUnsummon(10s);
                            }
                    _events.ScheduleEvent(EVENT_CONSTRUCT_DONE, 3s);
                    break;
                }
                case EVENT_CONSTRUCT_DONE:
                    me->Yell("FUNCTION FULFILLED. RESUMING REST MODE.", LANG_UNIVERSAL);
                    me->GetMotionMaster()->MovePoint(POINT_CONSTRUCT_HOME, me->GetHomePosition());
                    if (Creature* aamelia = me->FindNearestCreature(NPC_AAMELIA_WINDFIELD, 250.0f))
                        if (aamelia->AI())
                            aamelia->AI()->DoAction(ACTION_ORCHARD_EVENT_DONE);
                    _busy = false;
                    break;
                default:
                    break;
            }
        }
    }

private:
    EventMap _events;
    SummonList _summons;
    bool _busy = false;
};

/*######
## classic_npc_aamelia_windfield (252800)
######*/

// her run to the orchard's edge (official beta sniff 70205)
static Position const AameliaPath[] =
{
    { 1939.4f, 1615.4f, 647.4f },
    { 1950.4f, 1609.0f, 647.2f },
    { 1965.9f, 1603.3f, 647.1f },
    { 1974.1f, 1600.9f, 647.3f },
    { 1984.5f, 1599.6f, 647.5f },
    { 2003.9f, 1598.9f, 648.7f },
    { 2023.8f, 1595.1f, 650.3f },
    { 2034.4f, 1592.7f, 651.5f },
    { 2045.7f, 1588.5f, 652.5f },
};

struct classic_npc_aamelia_windfield : public ScriptedAI
{
    classic_npc_aamelia_windfield(Creature* creature) : ScriptedAI(creature) { }

    void JustAppeared() override
    {
        _events.Reset();
        _fighters.clear();
        _busy = false;
        _returning = false;
    }

    bool OnGossipSelect(Player* player, uint32 menuId, uint32 gossipListId) override
    {
        // "I'm ready to fight, Aamelia." (option 136302) is the menu's only option, order 0
        if (menuId != GOSSIP_MENU_AAMELIA || gossipListId != 0)
            return false;

        CloseGossipMenuFor(player);
        player->KilledMonsterCredit(NPC_AAMELIA_WINDFIELD);
        _fighters.insert(player->GetGUID());

        if (!_busy && !_returning)
            StartRun();
        return true;
    }

    void MovementInform(uint32 type, uint32 id) override
    {
        if (type != POINT_MOTION_TYPE)
            return;

        if (id == POINT_AAMELIA_HOME)
        {
            _returning = false;
            me->SetFacingTo(me->GetHomePosition().GetOrientation());
            if (!_fighters.empty()) // someone got ready while she ran home
                StartRun();
            return;
        }

        if (id + 1 < std::size(AameliaPath))
        {
            me->GetMotionMaster()->MovePoint(id + 1, AameliaPath[id + 1]);
            return;
        }

        if (Creature* construct = me->FindNearestCreature(250929, 250.0f))
            if (construct->AI())
                construct->AI()->DoAction(ACTION_START_ORCHARD_EVENT);
    }

    void DoAction(int32 action) override
    {
        if (action != ACTION_ORCHARD_EVENT_DONE || !_busy)
            return;

        DoCastSelf(SPELL_MAKE_YOUR_STAND, true);
        for (ObjectGuid const& guid : _fighters)
            if (Player* player = ObjectAccessor::GetPlayer(*me, guid))
                if (player->GetQuestStatus(QUEST_STANDING_OUR_GROUND) == QUEST_STATUS_INCOMPLETE && player->IsWithinDistInMap(me, 100.0f))
                    player->KilledMonsterCredit(NPC_FERAUU_THE_BLUDGEON);
        _fighters.clear();
        _busy = false;
        _events.ScheduleEvent(EVENT_AAMELIA_GO_HOME, 5s);
    }

    void UpdateAI(uint32 diff) override
    {
        _events.Update(diff);

        if (_events.ExecuteEvent() == EVENT_AAMELIA_GO_HOME)
        {
            _returning = true;
            me->GetMotionMaster()->MovePoint(POINT_AAMELIA_HOME, me->GetHomePosition());
        }
    }

private:
    void StartRun()
    {
        _busy = true;
        me->Say("It's time, stranger. One way or another, let's finish this.", LANG_UNIVERSAL);
        me->GetMotionMaster()->Clear();
        me->GetMotionMaster()->MovePoint(0, AameliaPath[0]);
    }

    EventMap _events;
    GuidUnorderedSet _fighters;
    bool _busy = false;
    bool _returning = false;
};

void AddSC_classic_npcs_special()
{
    RegisterCreatureAI(classic_npc_sickly_critter);
    RegisterCreatureAI(classic_npc_malfunctioning_cyclone_construct);
    RegisterCreatureAI(classic_npc_aamelia_windfield);
}
