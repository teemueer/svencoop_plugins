#include "ColorsXKCD"

CCVar@ g_pHideChat;
CCVar@ g_pSilence;
CCVar@ g_pPersistence;

dictionary g_PlayerGlows;
const array<string> @g_ColorKeys = g_Colors.getKeys();

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor("Zode");
	g_Module.ScriptInfo.SetContactInfo("Zodemon @ Svencoop forums");
	
	g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
	g_Hooks.RegisterHook(Hooks::Player::ClientDisconnect, @ClientDisconnect);
	g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @PlayerSpawn);
	
	@g_pHideChat = CCVar("hidechat", false, "Hide player chat when executing glow command",  ConCommandFlag::AdminOnly);
	@g_pSilence = CCVar("silence", false, "Silent plugin - only print to user instead of everybody", ConCommandFlag::AdminOnly);
	@g_pPersistence = CCVar("persistence", false, "Don't remove glows on player disconnect", ConCommandFlag::AdminOnly);
}

HookReturnCode ClientSay(SayParameters@ pParams)
{
	CBasePlayer@ pPlayer = pParams.GetPlayer();
	const CCommand@ pArguments = pParams.GetArguments();
	bool bSilent = g_pSilence.GetBool();
	if(pArguments.ArgC() >=2)
	{
		if(pArguments.Arg(0) == "glow")
		{
			pParams.ShouldHide = g_pHideChat.GetBool();
			
			if(pArguments.Arg(1) == "off") // turn off glow
			{
				if(bSilent)
				{
					g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Glow] You are no longer glowing.\n");
				}
				else
				{
					g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Glow] " + pPlayer.pev.netname + " is no longer glowing.\n");
				}
				
				setRenderMode(pPlayer, kRenderNormal, kRenderFxNone, 255.0f, Vector(255,255,255), false);
				string szSteamId = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
				g_PlayerGlows.delete(szSteamId);

			}
			else
			{	// handle colors
				if(g_Colors.exists(pArguments.Arg(1)))
				{
					if(bSilent)
					{
						g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Glow] You are now glowing " + pArguments.Arg(1) + ".\n");
					}else{
						g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Glow] " + pPlayer.pev.netname + " is now glowing " + pArguments.Arg(1) + ".\n");
					}
					setRenderMode(pPlayer, kRenderNormal, kRenderFxGlowShell, 4.0f, Vector(g_Colors[pArguments.Arg(1)]), true);
				}else{
					if(bSilent)
					{
						g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Glow] No such color.\n");
					}else{
						if(g_pHideChat.GetBool() == false)
						{
							g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Glow] No such color.\n");
						}else{
							g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Glow] No such color.\n");
						}
					}
				}
			}
			return HOOK_HANDLED;
		}
	}
	return HOOK_CONTINUE;
}

void setRenderMode(CBasePlayer@ pPlayer, int rendermode, int renderfx, float renderamt, Vector color, bool saveSettings)
{
	if(saveSettings)
	{
		string szSteamId = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
		PlayerGlowData data;
		data.color = color;
		g_PlayerGlows[szSteamId] = data;
	}
	pPlayer.pev.rendermode = rendermode;
	pPlayer.pev.renderfx = renderfx;
	pPlayer.pev.renderamt = renderamt;
	pPlayer.pev.rendercolor = color;
}

HookReturnCode PlayerSpawn(CBasePlayer@ pPlayer)
{
	string szSteamId = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
	if(g_PlayerGlows.exists(szSteamId))
	{
		PlayerGlowData@ data = cast<PlayerGlowData@>(g_PlayerGlows[szSteamId]);
		g_Scheduler.SetTimeout("PlayerPostSpawn", 1.0f, g_EngineFuncs.IndexOfEdict(pPlayer.edict()), data.color, false);
	}
	
	return HOOK_CONTINUE;
}

void PlayerPostSpawn(int pIndex, Vector color, bool savesettings)
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(pIndex);

		if (pPlayer !is null)
			setRenderMode(pPlayer, kRenderNormal, kRenderFxGlowShell, 4.0f, color, savesettings);
}

HookReturnCode ClientDisconnect(CBasePlayer@ pPlayer)
{
	if(!g_pPersistence.GetBool())
	{
		string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
		if(g_PlayerGlows.exists(szSteamId))
		{
			g_PlayerGlows.delete(szSteamId);
		}
	}
	
	return HOOK_CONTINUE;
}

class PlayerGlowData // fuck it, im too tired to think about another way lol
{
	Vector color;
}
