#include "ColorsXKCD"

CCVar@ g_pHideChat;
CCVar@ g_pSilence;
CCVar@ g_pPersistence;
CCVar@ g_pTrailSize;
CCVar@ g_pTrailDuration;
CCVar@ g_pTrailAlpha;

int g_TrailSpriteIndex;
const string g_TrailSpriteName = "sprites/zbeam3.spr";

CScheduledFunction@ g_pThinkFunc = null;

dictionary g_PlayerTrails;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor("Zode");
	g_Module.ScriptInfo.SetContactInfo("Zodemon @ Svencoop forums");

	g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
	g_Hooks.RegisterHook(Hooks::Player::ClientDisconnect, @ClientDisconnect);
	g_Hooks.RegisterHook(Hooks::Player::ClientPutInServer, @ClientPutInServer);

	@g_pHideChat = 		CCVar("hidechat", false, "Hide player chat when executing trail command", ConCommandFlag::AdminOnly);
	@g_pSilence =		CCVar("silence", false, "Silent plugin - only print to user instead of everybody", ConCommandFlag::AdminOnly);
	@g_pPersistence =	CCVar("persistence", false, "Don't remove trails on player disconnect", ConCommandFlag::AdminOnly);
	@g_pTrailSize = 	CCVar("trailsize", 8, "(1-255) trail size", ConCommandFlag::AdminOnly, @TrailSizeCheck);
	@g_pTrailDuration =	CCVar("trailduration", 4.0f, "(float 0.1-25.5) trail duration (in seconds)", ConCommandFlag::AdminOnly, @TrailDurationCheck);
	@g_pTrailAlpha = 	CCVar("trailalpha", 200, "(1-255) trail alpha", ConCommandFlag::AdminOnly, @TrailAlphaCheck);

	if(g_pThinkFunc !is null)
		g_Scheduler.RemoveTimer(g_pThinkFunc);

	@g_pThinkFunc = g_Scheduler.SetInterval("trailThink", 0.3f);
}

class PlayerTrailData
{
	Vector color;
	bool restart;
}

void TrailSizeCheck(CCVar@ cvar, const string& in szOldValue, float flOldValue)
{
	cvar.SetInt(Math.clamp(1, 255, cvar.GetInt()));
	
	if(int(flOldValue) != cvar.GetInt())
		resetTrails();
}

void TrailDurationCheck(CCVar@ cvar, const string& in szOldValue, float flOldValue)
{
	cvar.SetFloat(Math.clamp(0.1f, 25.5f, cvar.GetFloat()));

	if(flOldValue != cvar.GetFloat())
		resetTrails();
}

void TrailAlphaCheck(CCVar@ cvar, const string& in szOldValue, float flOldValue)
{
	cvar.SetInt(Math.clamp(1, 255, cvar.GetInt()));

	if(int(flOldValue) != cvar.GetInt())
		resetTrails();
}

void MapInit()
{
	g_TrailSpriteIndex = g_Game.PrecacheModel(g_TrailSpriteName);
}

HookReturnCode ClientSay(SayParameters@ pParams)
{
	CBasePlayer@ pPlayer = pParams.GetPlayer();
	const CCommand@ pArguments = pParams.GetArguments();

	if(pArguments.ArgC() >=2)
	{
		if(pArguments.Arg(0) == "trail")
		{
			bool bSilent = g_pSilence.GetBool();
			pParams.ShouldHide = g_pHideChat.GetBool();
			
			if(pArguments.Arg(1) == "off") // turn off trail
			{
				if(bSilent)
				{
					g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] You no longer have a trail.\n");
				}else{
					g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] " + pPlayer.pev.netname + " no longer has a trail.\n");
				}
				
				removeTrail(pPlayer);
				
			}else{	// handle colors	
				if(g_Colors.exists(pArguments.Arg(1)))
				{
					if(bSilent)
					{
						g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] You now have a " + pArguments.Arg(1) + " trail.\n");
					}else{
						g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] " + pPlayer.pev.netname + " now has a " + pArguments.Arg(1) + " trail.\n");
					}

					addTrail(pPlayer, Vector(Vector(g_Colors[pArguments.Arg(1)])));
				}else{
					if(bSilent)
					{
						g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] No such color.\n");
					}else{
						if(g_pHideChat.GetBool() == false)
						{
							g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] No such color.\n");
						}else{
							g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] No such color.\n");
						}
					}
				}
			}
			return HOOK_HANDLED;
		}
	}
	return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect(CBasePlayer@ pPlayer)
{
	if(!g_pPersistence.GetBool())
	{
		string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

		if(g_PlayerTrails.exists(szSteamId))
			g_PlayerTrails.delete(szSteamId);
	}

	return HOOK_CONTINUE;
}

void trailThink()
{
	// check vel difference
	for(int i = 1; i <= g_Engine.maxClients; ++i)
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

		if(pPlayer !is null && pPlayer.IsConnected())
		{
			string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

			if(g_PlayerTrails.exists(szSteamId))
			{
				PlayerTrailData@ data = cast<PlayerTrailData@>(g_PlayerTrails[szSteamId]);

				Vector tempVel = pPlayer.pev.velocity;
				bool tempBool = false;
				
				if(tempVel.x == 0 && tempVel.y == 0 && tempVel.z == 0) { data.restart = true; }

				if(data.restart)
				{
					if(tempVel.x >= 2) { tempBool = true; }
					if(tempVel.y >= 2) { tempBool = true; }
					if(tempVel.z >= 2) { tempBool = true; }
				}
				
				if(tempBool)
				{
					data.restart = false;
					killMsg(g_EntityFuncs.EntIndex(pPlayer.edict()));
					trailMsg(pPlayer, g_pTrailSize.GetInt(), int(g_pTrailDuration.GetFloat()*10), g_pTrailAlpha.GetInt(), data.color);
				}
			}
		}
	}
}

void resetTrails()
{
	for(int i = 1; i <= g_Engine.maxClients; ++i)
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);

		if(pPlayer !is null && pPlayer.IsConnected())
		{
			string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

			if(g_PlayerTrails.exists(szSteamId))
			{
				PlayerTrailData@ data = cast<PlayerTrailData@>(g_PlayerTrails[szSteamId]);

				killMsg(g_EntityFuncs.EntIndex(pPlayer.edict()));
				trailMsg(pPlayer, g_pTrailSize.GetInt(), int(g_pTrailDuration.GetFloat()*10), g_pTrailAlpha.GetInt(), data.color);
			}
		}
	}
}

void addTrail(CBasePlayer@ pPlayer, Vector color)
{
	string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

	if(g_PlayerTrails.exists(szSteamId))
	{
		PlayerTrailData@ data = cast<PlayerTrailData@>(g_PlayerTrails[szSteamId]);
		data.color = color;
		data.restart = false;

		killMsg(g_EntityFuncs.EntIndex(pPlayer.edict())); // set trail 
	}else{
		PlayerTrailData data; // add trail
		data.color = color;
		data.restart = false;

		g_PlayerTrails[szSteamId] = data;
	}

	trailMsg(pPlayer, g_pTrailSize.GetInt(), int(g_pTrailDuration.GetFloat()*10), g_pTrailAlpha.GetInt(), color);
}

void trailMsg(CBasePlayer@ pPlayer, int trailSize, int trailDuration, int trailAlpha, Vector color)
{
	// send trail message
	NetworkMessage message(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
		message.WriteByte(TE_BEAMFOLLOW);
		message.WriteShort(g_EntityFuncs.EntIndex(pPlayer.edict()));
		message.WriteShort(g_TrailSpriteIndex);
		message.WriteByte(trailDuration);
		message.WriteByte(trailSize);
		message.WriteByte(int(color.x));
		message.WriteByte(int(color.y));
		message.WriteByte(int(color.z));
		message.WriteByte(trailAlpha);
	message.End();
}

void removeTrail(CBasePlayer@ pPlayer)
{
	string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
	g_PlayerTrails.delete(szSteamId);
	killMsg(g_EntityFuncs.EntIndex(pPlayer.edict()));
}

void killMsg(int id)
{
	// send kill trail message
	NetworkMessage message(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
		message.WriteByte(TE_KILLBEAM);
		message.WriteShort(id);
	message.End();
}

HookReturnCode ClientPutInServer(CBasePlayer@ pPlayer)
{
        string szSteamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());

        if(g_PlayerTrails.exists(szSteamId))
        {
                PlayerTrailData@ data = cast<PlayerTrailData@>(g_PlayerTrails[szSteamId]);
                g_Scheduler.SetTimeout("PlayerPostConnect", 1.0f, g_EngineFuncs.IndexOfEdict(pPlayer.edict()), data.color);
        }

        return HOOK_CONTINUE;
}

void PlayerPostConnect(int pIndex, Vector color)
{
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(pIndex);
        
	if (pPlayer !is null && pPlayer.IsConnected())
		addTrail(pPlayer, color);
}
