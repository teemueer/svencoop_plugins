const array<string> g_ModelList = { 'replacemodel1', 'replacemodel2' };

const array<string> g_AdditionalModelList = { 'onlyprecachemodel1', 'onlyprecachemodel2' };

const array<string> g_WheelchairModelList = {
'sci_wheelchair',
'security_wheelchair',
'soldier_wheelchair'
};

const int g_MaxVotes = 2;
bool g_Wheelchair = false;
bool g_WheelchairPrev = false;
int g_VoteCount = 0;

dictionary g_OriginalModelList;

CScheduledFunction@ g_pThinkFunc = null;

CClientCommand g_ListModels("listmodels", "List model names and colors of the current players", @ListModels);
CClientCommand g_ListPrecachedModels("listprecachedmodels", "List model names who are currently precached by the server (admin only)", @ListPrecachedModels);

void PluginInit() {
  g_Module.ScriptInfo.SetAuthor("animaliZed");
  g_Module.ScriptInfo.SetContactInfo("irc://irc.rizon.net/#/dev/null");

  g_Hooks.RegisterHook(Hooks::Player::ClientDisconnect, @ClientDisconnect);
  g_Hooks.RegisterHook(Hooks::Player::ClientPutInServer, @ClientPutInServer);
  g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
  g_Hooks.RegisterHook(Hooks::Game::MapChange, @MapChange);
}

void MapInit() {
  for (uint i = 0; i < g_ModelList.length(); ++i) {
    g_Game.PrecacheGeneric("models/player/" + g_ModelList[i] + "/" + g_ModelList[i] + ".mdl");
  }
  
  for (uint i = 0; i < g_AdditionalModelList.length(); ++i) {
    g_Game.PrecacheGeneric("models/player/" + g_AdditionalModelList[i] + "/" + g_AdditionalModelList[i] + ".mdl");
  }

  for (uint i = 0; i < g_WheelchairModelList.length(); ++i) {
    g_Game.PrecacheGeneric("models/player/" + g_WheelchairModelList[i] + "/" + g_WheelchairModelList[i] + ".mdl");
  }

  g_Wheelchair = false;
  g_VoteCount = 0;

  if (g_pThinkFunc !is null)
    g_Scheduler.RemoveTimer(g_pThinkFunc);
}

HookReturnCode MapChange() {
  if (g_WheelchairPrev && !g_Wheelchair)
    g_WheelchairPrev = false;

  if (g_Wheelchair)
    g_WheelchairPrev = true;

  return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect(CBasePlayer@ pPlayer) {
   const string SteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
   g_OriginalModelList.delete(SteamId);
   
   return HOOK_CONTINUE;
}

HookReturnCode ClientPutInServer(CBasePlayer@ pPlayer) {
  KeyValueBuffer@ pInfos = g_EngineFuncs.GetInfoKeyBuffer(pPlayer.edict());
  const string SteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

  if (!g_Map.HasForcedPlayerModels()) {
    if (g_Wheelchair) {
      if (!g_OriginalModelList.exists(SteamId))
        g_OriginalModelList.set(SteamId, pInfos.GetValue("model"));

      pInfos.SetValue("model", g_WheelchairModelList[Math.RandomLong(0, g_WheelchairModelList.length()-1)]);
    }
    else {
      if (g_WheelchairPrev && g_OriginalModelList.exists(SteamId)) {
        pInfos.SetValue("model", string(g_OriginalModelList[SteamId]));
        g_OriginalModelList.delete(SteamId);
      }

      if (pInfos.GetValue("model") == "helmet") {
        if (pInfos.GetValue("topcolor") == 140 && pInfos.GetValue("bottomcolor") == 160) {
          pInfos.SetValue("topcolor", Math.RandomLong(0, 255));
          pInfos.SetValue("bottomcolor", Math.RandomLong(0, 255));
        }

        const string HelmetReplacement = g_ModelList[Math.RandomLong(0, g_ModelList.length()-1)];
        pInfos.SetValue("model", HelmetReplacement);
        g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Info] " + pPlayer.pev.netname + " uses model 'helmet', replacing with '" + HelmetReplacement + "'.\n");
      }
    }
    return HOOK_CONTINUE;
  }
  return HOOK_CONTINUE;
}

HookReturnCode ClientSay(SayParameters@ pParams) {
  const CCommand@ pArguments = pParams.GetArguments();

  if (pArguments.ArgC() > 0 && (pArguments.Arg(0).ToLowercase() == "wheelchairs?" || pArguments.Arg(0).ToLowercase() == "wheelchairs" || pArguments.Arg(0).ToLowercase() == "wheelchair")) {
    if (g_Wheelchair) {
      g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Info] Wheelchairs are already enabled, blocking vote.\n");
    }
    else if (g_VoteCount >= g_MaxVotes) {
      g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Info] Maximum tries to enable wheelchairs reached, try again after map change.\n");
    }
    else if (g_Map.HasForcedPlayerModels()) {
      g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Info] Wheelchairs are not available on this map.\n");
    }
    else {
      Vote@ WCVote = Vote('Wheelchairs?', 'Force players into wheelchairs until the end of the map?', 15.0f, 66.6f);
      WCVote.SetYesText('Yes, let\'s roll');
      WCVote.SetNoText('No, keep walking');
      WCVote.SetVoteBlockedCallback(@WCVoteBlocked);
      WCVote.SetVoteEndCallback(@WCVoteEnd);
      WCVote.Start();
      g_VoteCount++;
    }
    return HOOK_HANDLED;
  }
  return HOOK_CONTINUE;
}

void WCVoteBlocked(Vote@ pVote, float flTime) {
  g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Info] Another vote is currently active, try again in " + ceil(flTime) + " seconds.\n");
}

void WCVoteEnd(Vote@ pVote, bool fResult, int iVoters) {
  if (fResult) {
    g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Info] Placing players in wheelchairs.\n");
    g_Wheelchair = true;
    ForceWheelchairs(false);
    @g_pThinkFunc = g_Scheduler.SetInterval("ForceWheelchairs", 15.0f, g_Scheduler.REPEAT_INFINITE_TIMES, true);
  }
  else {
    g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Info] The players choose to continue on foot.\n");
  }
}

void ForceWheelchairs(bool msg) {
  for (int i = 1; i <= g_Engine.maxClients; ++i) {
    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

    if (pPlayer !is null) {
      KeyValueBuffer@ pInfos = g_EngineFuncs.GetInfoKeyBuffer(pPlayer.edict());
      const string SteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

      if (!g_OriginalModelList.exists(SteamId))
        g_OriginalModelList.set(SteamId, pInfos.GetValue("model"));

      if (g_WheelchairModelList.find(pInfos.GetValue("model")) < 0) {
        pInfos.SetValue("model", g_WheelchairModelList[Math.RandomLong(0, g_WheelchairModelList.length()-1)]);
 
        if (msg)
          g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Info] You can not walk during Sven Co-op special olympics.\n");
      }
    }
  }
}

void ListModels(const CCommand@ pArgs) {
  CBasePlayer@ pCaller = g_ConCommandSystem.GetCurrentPlayer();

  if (g_Wheelchair) {
    g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "WHEELCHAIR MODE IS ENABLED! YOU MAY CHOOSE FROM:\n");
    g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "------------------------------------------------\n");

    for (uint i = 0; i < g_WheelchairModelList.length(); ++i) {
      g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, g_WheelchairModelList[i] + "\n");
    }

    g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "------------------------------------------------\n");
  }

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

void ListPrecachedModels(const CCommand@ pArgs) {
  CBasePlayer@ pCaller = g_ConCommandSystem.GetCurrentPlayer();

  if (g_PlayerFuncs.AdminLevel(pCaller) < ADMIN_YES) {
    g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "You have no access to this command.\n");
    return;
  }

  g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "CURRENTLY PRECACHED MODELS\n");
  g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "--Replacement-------------\n");
  
  for (uint i = 0; i < g_ModelList.length(); ++i) {
    g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, g_ModelList[i] + "\n");
  }

  g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "--Additional--------------\n");

  for (uint i = 0; i < g_AdditionalModelList.length(); ++i) {
    g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, g_AdditionalModelList[i] + "\n");
  }

  g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, "--Wheelchair--------------\n");

  for (uint i = 0; i < g_WheelchairModelList.length(); ++i) {
    g_PlayerFuncs.ClientPrint(pCaller, HUD_PRINTCONSOLE, g_WheelchairModelList[i] + "\n");
  }
}
