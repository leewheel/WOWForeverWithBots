//By leewheel 20260924 移植自 LWCoreWotlkClassicEdition：junk-to-gold 配置加载（原文件原样保留）
#include "Config.h"
#include "Log.h"

bool junk_Enable = false;

// 在模块加载时调用此函数初始化配置（worldserver.conf: JunkToGold.Enable，缺省开启）
void LoadJunkToGoldConfig()
{
    junk_Enable = sConfigMgr->GetBoolDefault("JunkToGold.Enable", true);
}
