CClientCommand g_KickID("kickid", "Kick Player by SteamID", @KickPlayerBySteamID);

void PluginInit() {
  g_Module.ScriptInfo.SetAuthor("animaliZed");
  g_Module.ScriptInfo.SetContactInfo("irc://irc.rizon.net/#/dev/null");

  g_Module.ScriptInfo.SetMinimumAdminLevel(ADMIN_YES);
}

void KickPlayerBySteamID(const CCommand@ pArgs) {
  CBasePlayer@ pCaller = g_ConCommandSystem.GetCurrentPlayer();

  if (pArgs.ArgC() > 0) {
    for (int i = 1; i <= g_Engine.maxClients; ++i) {
      CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
      string szPlayerID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

      if (pPlayer !is null && szPlayerID.ToLowercase() == pArgs.GetArgumentsString().ToLowercase().SubString(1) && g_PlayerFuncs.AdminLevel(pPlayer) < ADMIN_YES) {
        g_EngineFuncs.ServerCommand("kicksteamid " + pArgs.GetArgumentsString().ToLowercase().SubString(1) + "\n");
        g_EngineFuncs.ServerExecute();
        g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "Kicked Player with ID: " + pArgs.GetArgumentsString().ToLowercase().SubString(1) + "\n");
      }
    }
  }
}
