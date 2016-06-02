CCVar@ g_ReservedSlots;

void PluginInit() {
  g_Module.ScriptInfo.SetAuthor("animaliZed");
  g_Module.ScriptInfo.SetContactInfo("irc://irc.rizon.net/#/dev/null");
  g_Module.ScriptInfo.SetMinimumAdminLevel(ADMIN_YES);

  g_Hooks.RegisterHook(Hooks::Player::CanPlayerUseReservedSlot, @CanPlayerUseReservedSlot);
  
  @g_ReservedSlots = CCVar("num", 0, "Number of slots to reserve for players listed in admins.txt", ConCommandFlag::AdminOnly, @NumSlotsChanged);

  SlotUpdate(g_ReservedSlots.GetInt());
}

HookReturnCode CanPlayerUseReservedSlot(edict_t@ player, const string& in, const string& in, bool& out can) {
  if (g_EntityFuncs.IsValidEntity(player)) {
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(g_EntityFuncs.Instance(player));

    if (pPlayer !is null && g_PlayerFuncs.AdminLevel(pPlayer) >= ADMIN_YES) {
      can = true;
      return HOOK_HANDLED;
    }
  }

  return HOOK_CONTINUE;
}

void NumSlotsChanged(CCVar@ cvar, const string& in szOldValue, float flOldValue) {
   cvar.SetInt(Math.clamp(0, g_Engine.maxClients-1, cvar.GetInt()));
   SlotUpdate(cvar.GetInt());
}

void SlotUpdate(uint slots) {
  g_AdminControl.SetReservedSlots(slots);
}
