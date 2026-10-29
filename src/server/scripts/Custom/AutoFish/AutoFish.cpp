/*
 * Copyright 2026 Leewheel
 *
 * AutoFish - 玩家自动钓鱼功能
 *
 * 来源：LWCoreWotlkClassicEdition（E:\1.ClassicCataSlym）src\server\scripts\Custom\AutoFish\AutoFish.cpp
 * 移植：By leewheel 20260924 适配 WoWMidnight（TrinityCore 系 WOWSimulator）：
 * 再移植：By leewheel 20260929 移植到 TrinityCoreForever（E:\1.Forever\SourceAndBuild\TrinityCoreForever）——
 *   两核心同族，代码零改动；核心钩子 OnPlayerAfterUpdate/OnPlayerLootItem 与
 *   RBAC_PERM_COMMAND_AUTO_FISH(1003) 已同步加入本核心（对应 WSim 提交 a25a5126e1）：
 *   1. 鱼饵检测数据源改为 ItemTemplate::Effects（本核心由 sItemXItemEffectStore/sItemEffectStore
 *      装载，ObjectMgr.cpp 已按 LegacySlotIndex 排序），源项目的 sDB2Manager.GetItemEffectsForItemId
 *      在本核心不存在
 *   2. SpellEffectInfo::CalcValue() 改为本核心的 CalcValueAsInt()
 *   3. Player::CastItemUseSpell 签名不同（需显式 spellId + castCount），按本核心
 *      Player.cpp:9045 的口径传参；castId 生成对齐 Spell.cpp:564
 *   4. WorldSession::DoLootRelease 参数为 Loot*（源项目为 ObjectGuid）
 *   5. Loot 无 empty()/GetMaxSlotInLootFor()，改用 items.size()
 *   6. RBAC 权限改用核心枚举 RBAC_PERM_COMMAND_AUTO_FISH(1003)，
 *      见 sql/updates/auth/master/2026_09_24_00_auth_autofish_rbac.sql
 *   7. 依赖核心新增钩子 OnPlayerAfterUpdate（ScriptMgr.h/ScriptMgr.cpp/Player.cpp 已同步添加）
 * 再移植：By leewheel 20261029 移植到 ForeverWithMod\WoWForeverWithBots ——
 *   代码零改动（两核心同族：CastItemUseSpell/DoLootRelease(Loot*)/CalcValueAsInt/
 *   Item::GetEffects/ChatCommandBuilder 全部同签名）；核心钩子 OnPlayerAfterUpdate
 *   与 RBAC_PERM_COMMAND_AUTO_FISH(1003) 已同步加入本核心，
 *   见 sql/custom/auth/2026_10_29_00_auth_autofish_rbac.sql
 *
 * 命令:
 *   .自动钓鱼 / .autofish  - 开启/关闭自动钓鱼
 *
 * 功能:
 *   1. 检查玩家是否已学钓鱼、背包是否有鱼竿、是否在水边
 *   2. 自动装备鱼竿，自动使用最高等级鱼饵
 *   3. 自动施放钓鱼技能，自动拾取鱼漂中的鱼
 *   4. 背包满时丢弃钓起的鱼
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "Item.h"
#include "ItemDefines.h"
#include "ItemTemplate.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "SpellAuraDefines.h"
#include "Spell.h"
#include "GameObject.h"
#include "GameObjectData.h"
#include "Map.h"
#include "Log.h"
#include "DB2Stores.h"
#include "DB2Structure.h"
#include "DBCEnums.h"
#include "SharedDefines.h"
#include "ObjectAccessor.h"
#include "Object.h"
#include "WorldSession.h"
#include "LootMgr.h"
#include "Loot.h"
#include "Bag.h"
#include "UpdateFields.h"
#include "Timer.h"
#include "RBAC.h"

#include <vector>
#include <algorithm>
#include <unordered_map>
#include <memory>
#include <mutex>
#include <array>
#include <cmath>

using namespace Trinity::ChatCommands;

namespace
{

// ==================== 常量 ====================

// 钓鱼法术等级列表（从高到低）
// 7620=初级 7731=中级 7732=高级 18248=专家级 33095=大师级 51294=宗师级
static constexpr uint32 FISHING_SPELL_RANKS[] = { 51294, 33095, 18248, 7732, 7731, 7620 };
static constexpr uint32 FISHING_SKILL_ID = 356;
static constexpr uint32 TICK_MS = 500;
static constexpr uint32 CAST_TIMEOUT_MS = 3000;       // 施放后等待鱼漂出现的超时
static constexpr uint32 BOBBER_TIMEOUT_MS = 30000;    // 等待鱼漂就绪的超时
static constexpr uint32 RECAST_DELAY_MS = 1200;       // 重新施放的间隔
static constexpr uint32 LOOT_DELAY_MS = 300;          // 拾取前等待

// 自动钓鱼命令所需的 RBAC 权限（RBAC.h 自定义段，auth 库链到 199 "Role: Player Commands"）
//By leewheel 20260924: 本核心 rbac::RBACPermissions 是枚举，直接用枚举常量（源项目为可构造类型）
static constexpr rbac::RBACPermissions AUTOFISH_RBAC_PERM = rbac::RBAC_PERM_COMMAND_AUTO_FISH;
//End By leewheel

// 查找玩家已学的最高级钓鱼法术
uint32 GetBestFishingSpell(Player* player)
{
    for (uint32 spellId : FISHING_SPELL_RANKS)
    {
        if (player->HasSpell(spellId))
            return spellId;
    }
    return 0;
}

// ==================== 状态机 ====================

enum AutoFishState : uint8
{
    AF_STATE_IDLE = 0,
    AF_STATE_CASTING,    // 已施放钓鱼，等待鱼漂出现
    AF_STATE_WAITING,    // 鱼漂已出现，等待就绪
    AF_STATE_LOOTING,    // 鱼漂就绪，正在拾取
    AF_STATE_RECAST      // 等待重新施放
};

struct AutoFishPlayerState
{
    bool active = false;
    uint8 state = AF_STATE_IDLE;
    uint32 stateSinceMs = 0;
    uint32 tickAccum = 0;
    bool hasCasted = false;        // 当前 CASTING 状态是否已施放过钓鱼技能
    bool lureAttempted = false;    // 当前 RECAST 周期内是否已尝试过施放鱼饵
    ObjectGuid bobberGuid;
};

// By leewheel 2026-10-12: 跨线程访问修复（按原理，不因"源项目也这么写"而放过）。
//   g_autoFishStates 会被两类线程同时访问：
//     · 地图线程 —— UpdateAutoFish / OnLogout（玩家 tick 与登出都在玩家所属地图线程）
//     · world 线程 —— ChatHandler 处理 .自动钓鱼 命令（StartAutoFish / StopAutoFish）
//   std::unordered_map 的插入/删除/rehash 都不是线程安全的 ⇒ 数据竞争（可致堆损坏）。
//   更严重的是 UpdateAutoFish 会把 &itr->second 取出来长期使用，而 world 线程可能在此刻
//   erase 同一个 key ⇒ 那个引用立刻悬垂 ⇒ use-after-free（这正是"退出/切图偶发崩溃"的形状）。
//   修法：值改为 shared_ptr<AutoFishPlayerState>，map 结构由一把互斥锁保护，但【不】用锁去
//   保护状态对象本身 —— UpdateAutoFish 在锁内取出 shared_ptr 后即可脱离锁继续使用，即使
//   world 线程同时 erase，对象也被这个 shared_ptr 保活；同时也避免了在 CastSpell 这类可能
//   耗时的调用期间持锁。
static std::mutex& AutoFishMutex()
{
    static std::mutex* mutex = new std::mutex(); // 故意进程级泄漏：避免退出序析构后仍被使用
    return *mutex;
}

static std::unordered_map<ObjectGuid, std::shared_ptr<AutoFishPlayerState>> g_autoFishStates;

// ==================== 辅助函数 ====================

// 检查玩家是否已学钓鱼
bool PlayerHasFishingSkill(Player* player)
{
    return player->GetSkillValue(FISHING_SKILL_ID) > 0;
}

// 检查主手是否已装备鱼竿
bool IsFishingPoleEquipped(Player* player)
{
    Item* mainHand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND);
    if (!mainHand || mainHand->IsBroken())
        return false;
    ItemTemplate const* proto = mainHand->GetTemplate();
    return proto && proto->GetClass() == ITEM_CLASS_WEAPON && proto->GetSubClass() == ITEM_SUBCLASS_WEAPON_FISHING_POLE;
}

// 判断物品模板是否为鱼竿
bool IsFishingPole(ItemTemplate const* proto)
{
    return proto && proto->GetClass() == ITEM_CLASS_WEAPON && proto->GetSubClass() == ITEM_SUBCLASS_WEAPON_FISHING_POLE;
}

// 在背包中查找鱼竿（不含已装备的）
Item* FindFishingPoleInBags(Player* player)
{
    // 背包（backpack）
    for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
    {
        Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        if (item && !item->IsBroken() && IsFishingPole(item->GetTemplate()))
            return item;
    }
    // 装备的袋子
    for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
    {
        Bag* pBag = player->GetBagByPos(bag);
        if (!pBag)
            continue;
        for (uint8 slot = 0; slot < pBag->GetBagSize(); ++slot)
        {
            Item* item = player->GetItemByPos(bag, slot);
            if (item && !item->IsBroken() && IsFishingPole(item->GetTemplate()))
                return item;
        }
    }
    return nullptr;
}

// 装备鱼竿到主手
void EquipFishingPole(Player* player, Item* pole)
{
    if (!pole)
        return;

    uint16 srcPos = (uint16(pole->GetBagSlot()) << 8) | pole->GetSlot();
    uint16 dstPos = (uint16(INVENTORY_SLOT_BAG_0) << 8) | EQUIPMENT_SLOT_MAINHAND;
    player->SwapItem(srcPos, dstPos);
}

// 检查玩家附近是否有水
bool IsNearWater(Player* player)
{
    Map* map = player->GetMap();
    if (!map)
        return false;

    float const px = player->GetPositionX();
    float const py = player->GetPositionY();
    float const pz = player->GetPositionZ();
    float const ori = player->GetOrientation();

    // 检查玩家面前 3、6、9 码处的三点
    float const distances[] = { 3.0f, 6.0f, 9.0f };
    for (float dist : distances)
    {
        float x = px + dist * std::cos(ori);
        float y = py + dist * std::sin(ori);
        float ground = map->GetHeight(player->GetPhaseShift(), x, y, pz + 5.0f, true, 50.0f);
        if (ground == INVALID_HEIGHT)
            ground = pz;

        LiquidData liquidData;
        ZLiquidStatus status = map->GetLiquidStatus(player->GetPhaseShift(), x, y, pz, map_liquidHeaderTypeFlags::AllLiquids, &liquidData, DEFAULT_COLLISION_HEIGHT);
        if (status != LIQUID_MAP_NO_WATER && liquidData.level > ground + 0.5f)
            return true;
    }
    return false;
}

// ==================== 鱼饵识别与使用 ====================

// 从鱼饵物品获取钓鱼技能加成值（0 表示不是鱼饵）
//By leewheel 20260924: 数据源改用 ItemTemplate::Effects——本核心 ObjectMgr 装载物品模板时
//  已通过 sItemXItemEffectStore/sItemEffectStore 把 ItemEffect 挂到模板上（含 BonusList 变体走 Item::GetEffects）；
//  源项目的 sDB2Manager.GetItemEffectsForItemId 在本核心不存在
int32 GetLureFishingBonus(Item const* lureItem, ItemTemplate const* proto)
{
    if (!proto)
        return 0;

    int32 bestBonus = 0;

    for (ItemEffectEntry const* effect : lureItem->GetEffects())
    {
        if (!effect->SpellID)
            continue;

        // 鱼饵是"使用型"物品法术（右键对鱼竿使用）
        if (effect->TriggerType != ITEM_SPELLTRIGGER_ON_USE)
            continue;

        SpellInfo const* enchantSpell = sSpellMgr->GetSpellInfo(effect->SpellID, DIFFICULTY_NONE);
        if (!enchantSpell)
            continue;

        // 法术必须装备物品类为武器且子类包含鱼竿
        if (enchantSpell->EquippedItemClass != ITEM_CLASS_WEAPON)
            continue;
        if (!(enchantSpell->EquippedItemSubClassMask & (1 << ITEM_SUBCLASS_WEAPON_FISHING_POLE)))
            continue;

        for (SpellEffectInfo const& eff : enchantSpell->GetEffects())
        {
            if (eff.Effect != SPELL_EFFECT_ENCHANT_ITEM_TEMPORARY)
                continue;

            uint32 enchantId = uint32(eff.MiscValue);
            if (!enchantId)
                continue;

            SpellItemEnchantmentEntry const* enchant = sSpellItemEnchantmentStore.LookupEntry(enchantId);
            if (!enchant)
                continue;

            // 遍历附魔的 3 个效果槽
            for (uint8 s = 0; s < MAX_ITEM_ENCHANTMENT_EFFECTS; ++s)
            {
                if (enchant->Effect[s] != ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL)
                    continue;

                uint32 buffSpellId = enchant->EffectArg[s];
                if (!buffSpellId)
                    continue;

                SpellInfo const* buffSpell = sSpellMgr->GetSpellInfo(buffSpellId, DIFFICULTY_NONE);
                if (!buffSpell)
                    continue;

                // 查找增加钓鱼技能的光环
                for (SpellEffectInfo const& buffEff : buffSpell->GetEffects())
                {
                    if (buffEff.ApplyAuraName == SPELL_AURA_MOD_SKILL && buffEff.MiscValue == int32(FISHING_SKILL_ID))
                    {
                        //By leewheel 20260924: 本核心为 CalcValueAsInt（源项目 CalcValue）
                        int32 bonus = buffEff.CalcValueAsInt();
                        if (bonus > bestBonus)
                            bestBonus = bonus;
                        //End By leewheel
                    }
                }
            }
        }
    }

    return bestBonus;
}

// 在背包中查找最好的鱼饵（钓鱼技能加成最高的）
Item* FindBestLure(Player* player)
{
    Item* bestLure = nullptr;
    int32 bestBonus = 0;

    auto checkItem = [&](Item* item)
    {
        if (!item || item->IsBroken())
            return;
        ItemTemplate const* proto = item->GetTemplate();
        if (!proto)
            return;
        int32 bonus = GetLureFishingBonus(item, proto);
        if (bonus > bestBonus)
        {
            bestBonus = bonus;
            bestLure = item;
        }
    };

    // 背包
    for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        checkItem(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

    // 装备的袋子
    for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
    {
        Bag* pBag = player->GetBagByPos(bag);
        if (!pBag)
            continue;
        for (uint8 slot = 0; slot < pBag->GetBagSize(); ++slot)
            checkItem(player->GetItemByPos(bag, slot));
    }

    return bestLure;
}

// 检查已装备的鱼竿是否已有临时附魔（鱼饵）
bool HasLureApplied(Player* player)
{
    Item* mainHand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND);
    if (!mainHand)
        return false;
    return mainHand->GetEnchantmentId(TEMP_ENCHANTMENT_SLOT) != 0;
}

// 使用鱼饵到已装备的鱼竿上
//By leewheel 20260924: 适配本核心 CastItemUseSpell(Item*, uint32 spellId, targets, castCount, misc) 签名
void ApplyLure(Player* player, Item* lure)
{
    if (!lure)
        return;

    Item* mainHand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND);
    if (!mainHand || !IsFishingPole(mainHand->GetTemplate()))
        return;

    // 找到鱼饵的使用型法术 ID（右键使用的那个）
    uint32 useSpellId = 0;
    for (ItemEffectEntry const* effect : lure->GetEffects())
    {
        if (effect->TriggerType == ITEM_SPELLTRIGGER_ON_USE && effect->SpellID)
        {
            useSpellId = uint32(effect->SpellID);
            break;
        }
    }
    if (!useSpellId)
        return;

    InventoryResult result = player->CanUseItem(lure);
    if (result != EQUIP_ERR_OK)
        return;

    SpellCastTargets targets;
    targets.SetItemTarget(mainHand);
    // 生成客户端 cast id（与核心 Spell.cpp 的 m_castId 生成方式一致）
    ObjectGuid castId = ObjectGuid::Create<HighGuid::Cast>(SPELL_CAST_SOURCE_NORMAL, player->GetMapId(), useSpellId, player->GetMap()->GenerateLowGuid<HighGuid::Cast>());
    player->CastItemUseSpell(lure, useSpellId, targets, castId, std::array<int32, 3>{});
}
//End By leewheel

// ==================== 鱼漂检测与拾取 ====================

// 获取玩家的钓鱼鱼漂（通过 channel object slot 0，与客户端一致）
GameObject* GetFishingBobber(Player* player)
{
    // 钓鱼施放后，鱼漂 GUID 被写入 channel object slot 0（见 SpellEffects.cpp EffectTransmitted 的 FISHINGNODE 分支）
    if (player->m_unitData->ChannelObjects.size() == 0)
        return nullptr;

    ObjectGuid channelGuid = player->m_unitData->ChannelObjects[0];
    if (channelGuid.IsEmpty() || !channelGuid.IsGameObject())
        return nullptr;

    GameObject* go = player->GetMap()->GetGameObject(channelGuid);
    if (!go)
        return nullptr;

    // 确认是鱼漂且属于该玩家
    if (go->GetGoType() != GAMEOBJECT_TYPE_FISHINGNODE)
        return nullptr;
    if (go->GetOwnerGUID() != player->GetGUID())
        return nullptr;

    return go;
}

// 鱼漂是否就绪（可拾取）
bool IsBobberReady(GameObject* bobber)
{
    return bobber && bobber->getLootState() == GO_READY;
}

// 自动拾取鱼漂中的所有物品
// 调用 GameObject::Use 走完整的钓鱼判定流程（含技能增长），再自动拾取
void AutoLootBobber(Player* player, GameObject* bobber)
{
    if (!player || !bobber)
        return;

    // 调用 bobber->Use 触发完整的钓鱼流程（与玩家右键点击鱼漂一致）：
    //   1. 计算区域钓鱼技能要求与成功率
    //   2. UpdateFishingSkill() - 钓鱼技能增长
    //   3. SendLoot - 生成 loot 并打开拾取窗口（成功 LOOT_FISHING / 失败 LOOT_FISHING_JUNK）
    //   4. FinishSpell - 结束钓鱼引导
    bobber->Use(player);

    // Use 之后，SendLoot 已被调用，loot 数据已填充
    //By leewheel 20260924: 本核心 GameObject 的 loot 为私有 m_loot(unique_ptr)，
    //  经公开的 GetLootForPlayer 取得（源项目直接访问 go->loot）
    ObjectGuid lootGuid = player->GetLootGUID();
    if (lootGuid.IsEmpty())
        return;  // 没有 loot（例如鱼跑了或钓鱼洞分支）

    Loot* loot = nullptr;
    if (lootGuid.IsGameObject())
    {
        if (GameObject* lootGo = player->GetMap()->GetGameObject(lootGuid))
            loot = lootGo->GetLootForPlayer(player);
    }

    //By leewheel 20260924: 本核心 Loot 无 empty()，改用 items.empty()
    if (!loot || loot->items.empty())
    {
        player->GetSession()->DoLootRelease(loot);
        return;
    }
    //End By leewheel

    // 遍历所有 loot 槽位，尝试存入背包
    //By leewheel 20260924: 本核心无 GetMaxSlotInLootFor()，用 items.size()（钓鱼 loot 无 quest_items，槽位即索引）
    uint32 maxSlot = uint32(loot->items.size());
    for (uint32 slot = 0; slot < maxSlot; ++slot)
    {
        player->StoreLootItem(lootGuid, uint8(slot), loot);
        if (loot->isLooted())
            break;  // 全部拾取完成
    }

    if (!loot->isLooted())
    {
        // 背包已满，剩余物品随 DoLootRelease 丢弃
        ChatHandler(player->GetSession()).PSendSysMessage("|cffffcc00[自动钓鱼]|r 背包已满，部分渔获已丢弃。");
    }

    // 关闭拾取窗口并移除鱼漂
    //By leewheel 20260924: 本核心 DoLootRelease 参数为 Loot*（源项目为 ObjectGuid）
    player->GetSession()->DoLootRelease(loot);
}

// ==================== 状态机核心 ====================

void SetState(AutoFishPlayerState& st, AutoFishState newState)
{
    st.state = newState;
    st.stateSinceMs = getMSTime();
    st.hasCasted = false;
    // 进入 RECAST 状态时重置鱼饵尝试标志
    if (newState == AF_STATE_RECAST)
        st.lureAttempted = false;
}

void StartAutoFish(Player* player, ChatHandler* handler)
{
    // 条件检查 1: 已学钓鱼
    if (!PlayerHasFishingSkill(player))
    {
        handler->PSendSysMessage("|cffff0000[自动钓鱼]|r 你还没有学会钓鱼技能！");
        return;
    }

    // 条件检查 2: 背包有鱼竿或已装备鱼竿
    if (!IsFishingPoleEquipped(player) && !FindFishingPoleInBags(player))
    {
        handler->PSendSysMessage("|cffff0000[自动钓鱼]|r 背包中没有鱼竿！");
        return;
    }

    // 条件检查 3: 在水边
    if (!IsNearWater(player))
    {
        handler->PSendSysMessage("|cffff0000[自动钓鱼]|r 你不在水边，无法钓鱼！");
        return;
    }

    // 额外安全检查
    if (player->IsInCombat())
    {
        handler->PSendSysMessage("|cffff0000[自动钓鱼]|r 战斗中无法钓鱼！");
        return;
    }

    if (player->isDead())
    {
        handler->PSendSysMessage("|cffff0000[自动钓鱼]|r 死亡状态下无法钓鱼！");
        return;
    }

    // 装备鱼竿
    if (!IsFishingPoleEquipped(player))
    {
        Item* pole = FindFishingPoleInBags(player);
        if (pole)
        {
            EquipFishingPole(player, pole);
            handler->PSendSysMessage("|cff00ff00[自动钓鱼]|r 已自动装备鱼竿。");
        }
    }

    // 初始化状态（锁内只做 map 结构操作，之后用 shared_ptr 脱离锁）
    std::shared_ptr<AutoFishPlayerState> st;
    {
        std::lock_guard<std::mutex> lock(AutoFishMutex());
        std::shared_ptr<AutoFishPlayerState>& slot = g_autoFishStates[player->GetGUID()];
        if (!slot)
            slot = std::make_shared<AutoFishPlayerState>();
        st = slot;
    }

    *st = AutoFishPlayerState();
    st->active = true;
    SetState(*st, AF_STATE_RECAST);  // 从 RECAST 开始，短延迟后施放

    handler->PSendSysMessage("|cff00ff00[自动钓鱼]|r 自动钓鱼已开启！再次输入 .自动钓鱼 可停止。");
}

void StopAutoFish(Player* player, ChatHandler* handler)
{
    {
        std::lock_guard<std::mutex> lock(AutoFishMutex());
        auto itr = g_autoFishStates.find(player->GetGUID());
        if (itr == g_autoFishStates.end() || !itr->second || !itr->second->active)
        {
            handler->PSendSysMessage("|cffffcc00[自动钓鱼]|r 自动钓鱼未在运行。");
            return;
        }

        g_autoFishStates.erase(itr);
    }

    handler->PSendSysMessage("|cffff0000[自动钓鱼]|r 自动钓鱼已停止。");
}

void UpdateAutoFish(Player* player, uint32 diff)
{
    // 锁内只取 shared_ptr；对象随后由它保活，即使 world 线程并发 erase 也不会悬垂。
    std::shared_ptr<AutoFishPlayerState> stPtr;
    {
        std::lock_guard<std::mutex> lock(AutoFishMutex());
        auto itr = g_autoFishStates.find(player->GetGUID());
        if (itr != g_autoFishStates.end() && itr->second && itr->second->active)
            stPtr = itr->second;
    }

    if (!stPtr)
        return;

    AutoFishPlayerState& st = *stPtr;

    // 安全检查：死亡/不在世界 → 停止
    if (player->isDead() || !player->IsInWorld())
    {
        st.active = false;
        return;
    }

    // 战斗中暂停（不施放，等战斗结束）
    if (player->IsInCombat())
    {
        st.tickAccum = 0;
        return;
    }

    // 累积 tick
    st.tickAccum += diff;
    if (st.tickAccum < TICK_MS)
        return;
    st.tickAccum = 0;

    uint32 const now = getMSTime();

    switch (st.state)
    {
        case AF_STATE_RECAST:
        {
            if (getMSTimeDiff(st.stateSinceMs, now) < RECAST_DELAY_MS)
                return;

            // 施放前检查鱼饵（每个 RECAST 周期只尝试一次，防止死循环）
            if (IsFishingPoleEquipped(player) && !HasLureApplied(player) && !st.lureAttempted)
            {
                st.lureAttempted = true;
                Item* lure = FindBestLure(player);
                if (lure && !player->IsNonMeleeSpellCast(false, false, true))
                {
                    ApplyLure(player, lure);
                    // 给鱼饵附魔一点时间生效
                    return;
                }
            }

            // 施放钓鱼技能（使用玩家已学的最高级钓鱼法术）
            if (player->IsNonMeleeSpellCast(false, false, true))
                return;  // 正在施放其他法术

            uint32 fishingSpell = GetBestFishingSpell(player);
            if (!fishingSpell)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000[自动钓鱼]|r 未找到已学的钓鱼法术，停止自动钓鱼。");
                st.active = false;
                return;
            }

            player->CastSpell(player, fishingSpell, false);
            SetState(st, AF_STATE_CASTING);
            break;
        }

        case AF_STATE_CASTING:
        {
            // 查找鱼漂
            GameObject* bobber = GetFishingBobber(player);
            if (bobber)
            {
                st.bobberGuid = bobber->GetGUID();
                SetState(st, AF_STATE_WAITING);
                return;
            }

            // 超时未出现鱼漂 → 重新施放
            if (getMSTimeDiff(st.stateSinceMs, now) > CAST_TIMEOUT_MS)
            {
                // 可能施放失败（没水、面向不对等），重新尝试
                SetState(st, AF_STATE_RECAST);
            }
            break;
        }

        case AF_STATE_WAITING:
        {
            GameObject* bobber = player->GetMap()->GetGameObject(st.bobberGuid);
            if (!bobber)
            {
                // 鱼漂消失（可能被移动打断或引导结束）→ 重新施放
                SetState(st, AF_STATE_RECAST);
                return;
            }

            if (IsBobberReady(bobber))
            {
                SetState(st, AF_STATE_LOOTING);
                return;
            }

            // 超时 → 重新施放
            if (getMSTimeDiff(st.stateSinceMs, now) > BOBBER_TIMEOUT_MS)
            {
                SetState(st, AF_STATE_RECAST);
            }
            break;
        }

        case AF_STATE_LOOTING:
        {
            GameObject* bobber = player->GetMap()->GetGameObject(st.bobberGuid);
            if (!bobber)
            {
                SetState(st, AF_STATE_RECAST);
                return;
            }

            // 短暂延迟后拾取（等鱼漂动画稳定）
            if (getMSTimeDiff(st.stateSinceMs, now) < LOOT_DELAY_MS)
                return;

            AutoLootBobber(player, bobber);
            st.bobberGuid.Clear();
            SetState(st, AF_STATE_RECAST);
            break;
        }

        default:
            SetState(st, AF_STATE_RECAST);
            break;
    }
}

// ==================== 脚本注册 ====================

class AutoFishPlayerScript : public PlayerScript
{
public:
    AutoFishPlayerScript() : PlayerScript("AutoFishPlayerScript") { }

    void OnLogout(Player* player) override
    {
        std::lock_guard<std::mutex> lock(AutoFishMutex());
        g_autoFishStates.erase(player->GetGUID());
    }

    //By leewheel 20260924: 依赖核心新增钩子 OnPlayerAfterUpdate（Player::Update 末尾调用）
    void OnPlayerAfterUpdate(Player* player, uint32 diff) override
    {
        UpdateAutoFish(player, diff);
    }
    //End By leewheel
};

class AutoFishCommandHandler : public CommandScript
{
public:
    AutoFishCommandHandler() : CommandScript("AutoFishCommandHandler") { }

    std::span<ChatCommandBuilder const> GetCommands() const override
    {
        static ChatCommandTable commands =
        {
            { "自动钓鱼", HandleAutoFishToggle, AUTOFISH_RBAC_PERM, Console::No },
            { "autofish", HandleAutoFishToggle, AUTOFISH_RBAC_PERM, Console::No },
        };
        return commands;
    }

    static bool HandleAutoFishToggle(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;

        // 读取也要在锁内；值已是 shared_ptr，判空后再取 active
        bool isActive = false;
        {
            std::lock_guard<std::mutex> lock(AutoFishMutex());
            auto itr = g_autoFishStates.find(player->GetGUID());
            isActive = (itr != g_autoFishStates.end() && itr->second && itr->second->active);
        }

        if (isActive)
            StopAutoFish(player, handler);
        else
            StartAutoFish(player, handler);

        return true;
    }
};

} // namespace

void AddSC_AutoFish()
{
    new AutoFishPlayerScript();
    new AutoFishCommandHandler();
}
