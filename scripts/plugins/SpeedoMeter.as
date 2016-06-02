CScheduledFunction@ g_pSpeedThinkFunc = null;

dictionary g_PlayerSpeed;

void PluginInit() {
  g_Module.ScriptInfo.SetAuthor("Nero & animaliZed");
  g_Module.ScriptInfo.SetContactInfo("Nero & nico @ Svencoop forums");
  
  g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
  //g_Hooks.RegisterHook(Hooks::Player::ClientDisconnect, @ClientDisconnect);
  
  if(g_pSpeedThinkFunc !is null)
    g_Scheduler.RemoveTimer(g_pSpeedThinkFunc);

  @g_pSpeedThinkFunc = g_Scheduler.SetInterval("speedThink", 0.1f);
}

class PlayerSpeedData {
  Vector lastOrigin;
  float lastSpeed;
  float lastTime;
}

HookReturnCode ClientSay(SayParameters@ pParams) {
  CBasePlayer@ pPlayer = pParams.GetPlayer();
  const CCommand@ pArguments = pParams.GetArguments();
 
  if (pArguments.ArgC() == 1) {
    if (pArguments.Arg(0) == "speedometer") {
      pParams.ShouldHide = true;
      string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

      if (g_PlayerSpeed.exists(szSteamId)) {
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[SpeedoMeter] Disabled.\n");
        removeSpeedometer(pPlayer);
      }
      else {
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[SpeedoMeter] Enabled.\n");
        PlayerSpeedData data;
        data.lastOrigin = pPlayer.pev.origin;
        data.lastSpeed = 0.0f;
        data.lastTime = g_Engine.time;
        g_PlayerSpeed[szSteamId] = data;
      }
      return HOOK_HANDLED;
    }
  }
  return HOOK_CONTINUE;
}

void speedMsg(CBasePlayer@ pPlayer, const string szSteamId) {
  PlayerSpeedData@ data = cast<PlayerSpeedData@>(g_PlayerSpeed[szSteamId]);

  HUDTextParams txtPrms;
  Vector origin, velocity;
  float speedh, realSpeedH, currentTime;
  
  txtPrms.x = -1;  
  txtPrms.y = 1.0; 
  txtPrms.effect = 0; // 0 : Fade In/Out, 1 : Credits, 2 : Scan Out  

  //Text colour
  txtPrms.r1 = 0;
  txtPrms.g1 = 255;
  txtPrms.b1 = 0;
  txtPrms.a1 = 100;

  //fade-in colour
  txtPrms.r2 = 240;
  txtPrms.g2 = 110;
  txtPrms.b2 = 0;
  txtPrms.a2 = 0;
  
  txtPrms.fadeinTime = 0.0f;
  txtPrms.fadeoutTime = 0.0f;
  txtPrms.holdTime = 1.0f;
  txtPrms.fxTime = 0.25f; // Only when effect = 2
  txtPrms.channel = 1; // 1-4

  currentTime = g_Engine.time;
  origin = pPlayer.pev.origin;
  velocity = pPlayer.pev.velocity;

  // Calculate different speeds  
  speedh = sqrt( pow( velocity.x, 2.0 ) + pow( velocity.y, 2.0 ) );
  realSpeedH = sqrt( pow( origin.x - data.lastOrigin.x, 2.0 ) + pow( origin.y - data.lastOrigin.y, 2.0 ) ) / ( currentTime - data.lastTime );
  
  // Store current values as old values
  data.lastOrigin = origin;
  data.lastSpeed = speedh;
  data.lastTime = currentTime;

  // Show SpeedoMeter
  g_PlayerFuncs.HudMessage(pPlayer, txtPrms, string(int(speedh)) + "\n");
}

void removeSpeedometer(CBasePlayer@ pPlayer) {
  string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

  if (g_PlayerSpeed.exists(szSteamId))
    g_PlayerSpeed.delete(szSteamId);
}

/* HookReturnCode ClientDisconnect(CBasePlayer@ pPlayer) {
  removeSpeedometer(pPlayer);
 
  return HOOK_CONTINUE;
} */

void speedThink() {
  for (int i = 1; i <= g_Engine.maxClients; ++i) {
    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

    if (pPlayer !is null && pPlayer.IsConnected()) {
      string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

      if (g_PlayerSpeed.exists(szSteamId))
        speedMsg(pPlayer, szSteamId);
    }
  }
}
