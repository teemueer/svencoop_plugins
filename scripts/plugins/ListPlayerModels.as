CClientCommand g_ListModels("listmodels", "List model names and colors of the current players", @ListModels);

void PluginInit() {
  g_Module.ScriptInfo.SetAuthor("animaliZed");
  g_Module.ScriptInfo.SetContactInfo("irc://irc.rizon.net/#/dev/null");
}

void ListModels(const CCommand@ pArgs) {
  CBasePlayer@ pCaller = g_ConCommandSystem.GetCurrentPlayer();

  g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "PLAYERNAME ==> MODELNAME (TOPCOLOR, BOTTOMCOLOR)\n");
  g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "------------------------------------------------\n");

  for (int i = 1; i <= g_Engine.maxClients; ++i) {
    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

    if (pPlayer !is null && pPlayer.IsConnected()) {
      KeyValueBuffer@ pInfos = g_EngineFuncs.GetInfoKeyBuffer(pPlayer.edict());
      g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, string(pPlayer.pev.netname) + " ==> " + pInfos.GetValue("model") + " (" + pInfos.GetValue("topcolor") + ", " + pInfos.GetValue("bottomcolor") + ")\n");
    }
  }
}
