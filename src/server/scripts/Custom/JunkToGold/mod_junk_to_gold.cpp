/*
 * mod_junk_to_gold - 灰色物品拾取自动出售换钱
 *
 * 来源：LWCoreWotlkClassicEdition（E:\1.ClassicCataSlym）src\server\scripts\Custom\junk-to-gold\
 * 移植：By leewheel 20260924 适配 WoWMidnight（TrinityCore 系 WOWSimulator）：
 *   1. 依赖核心新增钩子 OnPlayerLootItem（Player::StoreLootItem 调用，仅普通拾取路径）
 *      与 OnPlayerAfterUpdate（Player::Update 末尾调用）——两钩子已同步加入核心
 *   2. 其余逻辑（延迟售物队列、防刷钱二次校验）与源项目一致
 * 再移植：By leewheel 20261018 移植回 TrinityCoreForever（钩子名适配为 OnLootItem / OnPlayerAfterUpdate）
 * 再移植：By leewheel 20261029 移植到 ForeverWithMod\WoWForeverWithBots ——
 *   本核心已有 PlayerScript::OnLootItem（Player::StoreLootItem 内
 *   sScriptMgr->OnPlayerLootItem 派发）；OnPlayerAfterUpdate 为本次新增钩子
 *
 * 配置（worldserver.conf，缺省开启）:
 *   JunkToGold.Enable = 1
 */

#include "Chat.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Config.h"
#include "mod_junk_to_gold_config.h"

#include <unordered_map>
#include <vector>

static std::string BuildItemLink(Player* player, Item* item)
{
    ItemTemplate const* proto = item->GetTemplate();
    if (!proto)
        return "";

    uint32 color = ItemQualityColors[proto->GetQuality()];
    LocaleConstant locale = player->GetSession()->GetSessionDbcLocale();
    std::string itemName = proto->GetName(locale);

    return Trinity::StringFormat(
        "|c{:08x}|Hitem:{}::::::::{}:::::|h[{}]|h|r",
        color,
        proto->GetId(),
        player->GetLevel(),
        itemName
    );
}

// JunkToGold，物品自动显示客户端语言相同名称
class JunkToGold : public PlayerScript
{
public:
    JunkToGold() : PlayerScript("JunkToGold") {}

    //By leewheel 20261018 换树后适配：新树核心钩子是 OnLootItem(Player*, Item*)（原老树为 4 参 OnPlayerLootItem）
    void OnLootItem(Player* player, Item* item) override
    {
        // 检查模块是否启用
        if (!junk_Enable)
            return;

        if (!player || !item)
            return;

        ItemTemplate const* proto = item->GetTemplate();
        if (!proto)
            return;

        // 仅处理灰色物品 (ITEM_QUALITY_POOR = 0)
        if (proto->GetQuality() != ITEM_QUALITY_POOR)
            return;

        // 卖价为 0 的灰色不处理
        if (proto->GetSellPrice() == 0)
            return;

        // 拾取回调是通知型 hook（核心 Player::StoreLootItem 持有 newitem 并继续 SendNewItem 等），
        // 不得在回调内同步 DestroyItem；记录待售队列，延迟到 OnPlayerAfterUpdate(拾取流程结束后)再销毁+给钱
        _pending[player->GetGUID()].push_back({ item->GetGUID(), item->GetEntry() });
    }
    //End By leewheel

    // 延迟处理拾取队列——下一 AI tick 执行，避开 StoreLootItem 对 newitem 的使用窗口
    //By leewheel 20261018 换树后移植回：依赖本次新增钩子 OnPlayerAfterUpdate
    void OnPlayerAfterUpdate(Player* player, uint32 /*diff*/) override
    {
        auto itr = _pending.find(player->GetGUID());
        if (itr == _pending.end())
            return;

        std::vector<PendingSale> pending = std::move(itr->second);
        _pending.erase(itr);

        for (PendingSale const& sale : pending)
        {
            Item* item = player->GetItemByGuid(sale.itemGuid);
            if (!item)
                continue;                        // 物品已不在(被使用/卖出/移动)，跳过且不给钱，防止刷钱

            ItemTemplate const* proto = item->GetTemplate();
            if (!proto || item->GetEntry() != sale.entry || proto->GetQuality() != ITEM_QUALITY_POOR || proto->GetSellPrice() == 0)
                continue;                        // 二次校验仍为可售灰色物品

            uint8 bag = item->GetBagSlot();
            uint8 slot = item->GetSlot();
            if (bag == NULL_BAG || slot == NULL_SLOT || item->IsEquipped())
                continue;                        // 不在背包或已被穿上，跳过(钱物一致，不销毁)

            uint32 count = item->GetCount();     // 按当前实际数量结算，避免延迟期间数量变化导致钱物不符
            SendTransactionInformation(player, item, count);

            player->DestroyItem(bag, slot, true);
            player->ModifyMoney(proto->GetSellPrice() * count);
        }
    }
    //End By leewheel

    // 登出清空未处理队列，避免跨会话残留导致误销毁/钱物不一致
    void OnLogout(Player* player) override
    {
        _pending.erase(player->GetGUID());
    }

private:
    struct PendingSale
    {
        ObjectGuid itemGuid;
        uint32 entry;
    };

    std::unordered_map<ObjectGuid, std::vector<PendingSale>> _pending;

    void SendTransactionInformation(Player* player, Item* item, uint32 count)
    {
        // 官方 ItemLink（自动语言 / 颜色 / suffix / level）
        std::string name = BuildItemLink(player, item);

        if (count > 1)
            name += Trinity::StringFormat("x{}", count);

        uint32 money = item->GetTemplate()->GetSellPrice() * count;

        uint32 gold = money / GOLD;
        uint32 silver = (money % GOLD) / SILVER;
        uint32 copper = (money % SILVER);

        std::string info;

        if (money < SILVER)
        {
            info = Trinity::StringFormat("{} 已出售，获得 {} 铜币。", name, copper);
        }
        else if (money < GOLD)
        {
            if (copper)
                info = Trinity::StringFormat("{} 已出售，获得 {} 银币和 {} 铜币。", name, silver, copper);
            else
                info = Trinity::StringFormat("{} 已出售，获得 {} 银币。", name, silver);
        }
        else
        {
            if (silver && copper)
                info = Trinity::StringFormat("{} 已出售，获得 {} 金币、{} 银币和 {} 铜币。", name, gold, silver, copper);
            else if (silver)
                info = Trinity::StringFormat("{} 已出售，获得 {} 金币和 {} 银币。", name, gold, silver);
            else if (copper)
                info = Trinity::StringFormat("{} 已出售，获得 {} 金币和 {} 铜币。", name, gold, copper);
            else
                info = Trinity::StringFormat("{} 已出售，获得 {} 金币。", name, gold);
        }

        ChatHandler(player->GetSession()).SendSysMessage(info);
    }
};

void Addmod_junk_to_goldScripts()
{
    // 加载配置
    LoadJunkToGoldConfig();

    new JunkToGold();
}
