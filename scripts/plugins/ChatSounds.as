const string g_SpriteName = 'sprites/voiceicon.spr';
const uint g_Delay = 8000;

dictionary g_SoundList;
dictionary g_ChatTimes;

array<string> @g_SoundListKeys = g_SoundList.getKeys();

CClientCommand g_ListSounds("listsounds", "List all chat sounds", @listsounds);

void PluginInit() {
  g_Module.ScriptInfo.SetAuthor("animaliZed");
  g_Module.ScriptInfo.SetContactInfo("irc://irc.rizon.net/#/dev/null");

  g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
}

void MapInit() {
  g_SoundList.deleteAll();
  g_ChatTimes.deleteAll();

  ReadSounds();

  for (uint i = 0; i < g_SoundListKeys.length(); ++i) {
    g_Game.PrecacheGeneric("sound/" + string(g_SoundList[g_SoundListKeys[i]]));
    g_SoundSystem.PrecacheSound(string(g_SoundList[g_SoundListKeys[i]]));
  }
  g_Game.PrecacheModel(g_SpriteName);
}

const string g_SoundFile = "scripts/plugins/ChatSounds.txt";
void ReadSounds() {
  File@ file = g_FileSystem.OpenFile(g_SoundFile, OpenFile::READ);
  if (file !is null && file.IsOpen()) {
    while(!file.EOFReached()) {
      string sLine;
      file.ReadLine(sLine);
      if (sLine.SubString(0,1) == "#" || sLine.IsEmpty())
        continue;

      array<string> parsed = sLine.Split(" ");
      if (parsed.length() < 2)
        continue;

      g_SoundList[parsed[0]] = parsed[1];
    }
    file.Close();
  }
}

void listsounds(const CCommand@ pArgs) {
  CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

  g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, "AVAILABLE SOUND TRIGGERS\n");
  g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, "------------------------\n");

  string sMessage = "";

  for (uint i = 1; i < g_SoundListKeys.length()+1; ++i) {
    sMessage += g_SoundListKeys[i-1] + " | ";

    if (i % 5 == 0) {
      sMessage.Resize(sMessage.Length() -2);
      g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, sMessage);
      g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, "\n");
      sMessage = "";
    }
  }

  if (sMessage.Length() > 2) {
    sMessage.Resize(sMessage.Length() -2);
    g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, sMessage + "\n");
  }

  g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, "\n");
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
