#include "helper"

CCVar@ g_cvarFloodTime;
CCVar@ g_cvarMuteTime;
CCVar@ g_cvarWarnTime;
CScheduledFunction@ g_AntiFloodThink = null;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor("Zode");
	g_Module.ScriptInfo.SetContactInfo("Zodemon @ Sven co-op forums, Zode @ Sven co-op discord");
	
	g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientDisconnect );
	
	@g_cvarFloodTime = CCVar("floodtime", 1.25, "time (default: 1.25) in seconds between messages", ConCommandFlag::AdminOnly);
	@g_cvarMuteTime = CCVar("mutetime", 30.0, "mute time (default: 30.0) in seconds", ConCommandFlag::AdminOnly);
	@g_cvarWarnTime = CCVar("warntime", 4.0, "warn cooldown time (default 4.0) in seconds", ConCommandFlag::AdminOnly);
}

class PlayerChatData
{
	float lastTime;
	bool floodWarn;
	bool isMuted;
	float muteTime;
	float warnTime;
	int id;
}
dictionary g_PlayerChat;

void MapInit()
{
	g_PlayerChat.deleteAll();
	
	if(g_AntiFloodThink !is null)
		g_Scheduler.RemoveTimer(g_AntiFloodThink);
		
	@g_AntiFloodThink = g_Scheduler.SetInterval("antifloodthink", 1.0f);
}

HookReturnCode ClientSay(SayParameters@ pParams)
{
	CBasePlayer@ pPlayer = pParams.GetPlayer();
	string steamId = getFixedSteamId(pPlayer);
	if(g_PlayerChat.exists(steamId))
	{
		PlayerChatData@ pcData = cast<PlayerChatData@>(g_PlayerChat[steamId]);
		if(pcData.isMuted)
		{
			pParams.ShouldHide = true;
			return HOOK_CONTINUE;
		}
		
		if(pcData.lastTime+g_cvarFloodTime.GetFloat() >= g_EngineFuncs.Time()) // flood!
		{
			if(pcData.floodWarn && !pcData.isMuted)
			{
				if(g_cvarMuteTime.GetFloat() < 60.0)
				{
					g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[AntiFlood] You have been muted for "+g_cvarMuteTime.GetFloat()+" seconds.\n"); 
				}else{
					g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[AntiFlood] You have been muted for "+g_cvarMuteTime.GetFloat()/60.0f+" minutes.\n"); 
				}
				
				pcData.isMuted = true;
				pcData.muteTime = g_EngineFuncs.Time()+g_cvarMuteTime.GetFloat();
			}else if(!pcData.floodWarn && !pcData.isMuted){
				g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[AntiFlood] Stop spamming the server!\n"); 
				pcData.floodWarn = true;
				pcData.warnTime = g_EngineFuncs.Time()+g_cvarWarnTime.GetFloat();
			}
		}
		pcData.lastTime = g_EngineFuncs.Time();
	}else{
		PlayerChatData pcData;
		pcData.lastTime = g_EngineFuncs.Time();
		pcData.floodWarn = false;
		pcData.isMuted = false;
		pcData.muteTime = g_EngineFuncs.Time()-1.0f;
		pcData.warnTime = g_EngineFuncs.Time()-1.0f;
		pcData.id = g_EntityFuncs.EntIndex(pPlayer.edict());
		g_PlayerChat[steamId] = pcData;
	}
	
	return HOOK_CONTINUE;
}

void antifloodthink()
{
	if(g_PlayerChat.isEmpty())
		return;
		
	array<string> playerChatIds = g_PlayerChat.getKeys();
	for(uint i = 0; i < playerChatIds.length(); i++)
	{
		PlayerChatData@ pcData = cast<PlayerChatData@>(g_PlayerChat[playerChatIds[i]]);
		if(!pcData.isMuted && !pcData.floodWarn)
			continue;
			
		if(pcData.isMuted && pcData.muteTime <= g_EngineFuncs.Time())
		{
			pcData.isMuted = false;
			pcData.floodWarn = false;
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(pcData.id);
			g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[AntiFlood] Your mute is no longer active.\n");
		}else if(pcData.floodWarn && pcData.warnTime <= g_EngineFuncs.Time())
		{
			pcData.floodWarn = false;
		}
	}
}

HookReturnCode ClientDisconnect(CBasePlayer@ pPlayer)
{
	string steamId = getFixedSteamId(pPlayer);
	if(g_PlayerChat.exists(steamId) && steamId != "")
		g_PlayerChat.delete(steamId);

	return HOOK_CONTINUE;
}
