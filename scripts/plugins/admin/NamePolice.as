const array<string> g_Names = { 'name1', 'name2', 'name3' };

CScheduledFunction@ g_pThinkFunc = null;

void PluginInit() {
  g_Module.ScriptInfo.SetAuthor("animaliZed");
  g_Module.ScriptInfo.SetContactInfo("irc://irc.rizon.net/#/dev/null");
  g_Module.ScriptInfo.SetMinimumAdminLevel(ADMIN_YES);
}

void MapInit() {
  if (g_pThinkFunc !is null)
    g_Scheduler.RemoveTimer(g_pThinkFunc);

  @g_pThinkFunc = g_Scheduler.SetInterval("NamePolice", 6.0f);
}

void NamePolice() {
  for (int i = 1; i <= g_Engine.maxClients; ++i) {
    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

    if (pPlayer !is null && g_PlayerFuncs.AdminLevel(pPlayer) < ADMIN_YES && g_Names.find(string(pPlayer.pev.netname).ToLowercase()) >= 0) {
      g_EngineFuncs.ServerCommand("kick \"#" + g_EngineFuncs.GetPlayerUserId(pPlayer.edict()) + "\" \"Protected nickname. Change your nick.\"\n");
      g_EngineFuncs.ServerExecute();
    }
  }
}
