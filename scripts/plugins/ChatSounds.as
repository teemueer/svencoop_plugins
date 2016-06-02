const dictionary g_SoundList = {
  {'*cheer*', 'tfc/ambience/goal_1.wav'},
  // ...
  {'groovey', 'bluecell/groovey.wav'},
  {'gw', 'sectore/goodwork.wav'}
};

const array<string> @g_SoundListKeys = g_SoundList.getKeys();
const string g_SpriteName = 'sprites/voiceicon.spr';
const uint g_Delay = 8000;

dictionary g_ChatTimes;

void PluginInit() {
  g_Module.ScriptInfo.SetAuthor("animaliZed");
  g_Module.ScriptInfo.SetContactInfo("irc://irc.rizon.net/#/dev/null");

  g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
}

void MapInit() {
  g_ChatTimes.deleteAll();

  for (uint i = 0; i < g_SoundListKeys.length(); ++i) {
    g_Game.PrecacheGeneric("sound/" + string(g_SoundList[g_SoundListKeys[i]]));
    g_SoundSystem.PrecacheSound(string(g_SoundList[g_SoundListKeys[i]]));
  }
  g_Game.PrecacheModel(g_SpriteName);
}

HookReturnCode ClientSay(SayParameters@ pParams) {
  const CCommand@ pArguments = pParams.GetArguments();

  if (pArguments.ArgC() > 0) {
    const string soundArg = pArguments.Arg(0).ToLowercase();

    if (g_SoundList.exists(soundArg)) {
      CBasePlayer@ pPlayer = pParams.GetPlayer();
      string sid = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

      if (!g_ChatTimes.exists(sid)) {
        g_ChatTimes[sid] = 0;
      }

      uint t = uint(g_EngineFuncs.Time()*1000);
      uint d = t - uint(g_ChatTimes[sid]);

      if (d < g_Delay) {
        float w = float(g_Delay - d) / 1000.0f;
        g_PlayerFuncs.SayText(pPlayer, "[ChatSounds] AntiSpam: Your sounds are muted for " + ceil(w) + " seconds.\n");
        return HOOK_CONTINUE;
      }
      else {
        g_SoundSystem.PlaySound(pPlayer.edict(), CHAN_AUTO, string(g_SoundList[soundArg]), 1.0f, ATTN_NORM, 0, 100, 0, true, pPlayer.pev.origin);
        pPlayer.ShowOverheadSprite(g_SpriteName, 56.0f, 2.0f);
      }
      g_ChatTimes[sid] = t;
      return HOOK_HANDLED;
    }
  }
  return HOOK_CONTINUE;
}
