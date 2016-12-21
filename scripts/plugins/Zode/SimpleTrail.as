#include "helper"

CCVar@ g_cvarHideChat;
CCVar@ g_cvarSilence;
CCVar@ g_cvarTrailSize;
CCVar@ g_cvarTrailDuration;
CCVar@ g_cvarTrailAlpha;
CCVar@ g_cvarTrailDefaultSprite;
int g_iFixedTrailSize;
int g_iFixedTrailDuration;
int g_iFixedTrailAlpha;
CScheduledFunction@ g_TrailThink = null;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor("Zode");
	g_Module.ScriptInfo.SetContactInfo("Zodemon @ Sven co-op forums, Zode @ Sven co-op discord");
	
	g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientDisconnect );
	g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @PlayerSpawn);

	@g_cvarHideChat = 			CCVar("hidechat", false, "Hide player chat when executing trail command",  ConCommandFlag::AdminOnly);
	@g_cvarSilence =			CCVar("silence", false, "Silent plugin - only print to user instead of everybody", ConCommandFlag::AdminOnly);
	@g_cvarTrailSize = 			CCVar("trailsize", 8, " trail size", ConCommandFlag::AdminOnly);
	@g_cvarTrailDuration = 		CCVar("trailduration", 4.0f, "trail duration (in seconds)", ConCommandFlag::AdminOnly);
	@g_cvarTrailAlpha = 		CCVar("trailalpha", 200, "trail alpha", ConCommandFlag::AdminOnly);
	@g_cvarTrailDefaultSprite = CCVar("trailsprite", "fatline", "default trail sprite", ConCommandFlag::AdminOnly);
	g_bHasColors = false;
	g_isSafe = false;
}

class PlayerTrailData
{
	int id;
	Vector color;
	int sprIndex;
	string sprName;
	bool restart;
	bool enabled;
}

class PlayerCrossoverData
{
	Vector color;
	string sprName;
}

dictionary g_PlayerTrails;
dictionary g_PlayerCrossover;
dictionary g_TrailColors;
bool g_bHasColors = false;
bool g_isSafe = false;

void MapInit()
{
	g_TrailSprites.deleteAll();
	ReadSprites();
	array<string> spriteNames = g_TrailSprites.getKeys();
	for(uint i = 0; i < spriteNames.length(); i++)
	{
		TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[spriteNames[i]]);
		tsData.sprIndex = g_Game.PrecacheModel(tsData.sprPath);
	}
	
	if(@trailMenu !is null)
	{
		trailMenu.Unregister();
		@trailMenu = null;
	}
				
	if(@spriteMenu !is null)
	{
		spriteMenu.Unregister();
		@spriteMenu = null;
	}
	
	g_PlayerTrails.deleteAll();
	g_TrailColors.deleteAll();
	ReadColors();
	g_bHasColors = true;
	g_isSafe = true;
	
	g_iFixedTrailSize = cclamp(g_cvarTrailSize.GetInt(), 1, 255);
	g_iFixedTrailDuration = cclamp(int(g_cvarTrailDuration.GetFloat())*10, 1, 255);
	g_iFixedTrailAlpha = cclamp(g_cvarTrailAlpha.GetInt(), 1, 255);
	
	if(g_TrailThink !is null)
		g_Scheduler.RemoveTimer(g_TrailThink);
		
	@g_TrailThink = g_Scheduler.SetInterval("trailThink", 0.3f);
}

const string g_ColorFile = "scripts/plugins/Zode/colors.txt";
void ReadColors()
{
	File@ file = g_FileSystem.OpenFile(g_ColorFile, OpenFile::READ);
	if(file !is null && file.IsOpen())
	{
		while(!file.EOFReached())
		{
			string sLine;
			file.ReadLine(sLine);
			if(sLine.SubString(sLine.Length()-1,1) == " " || sLine.SubString(sLine.Length()-1,1) == "\n" || sLine.SubString(sLine.Length()-1,1) == "\r" || sLine.SubString(sLine.Length()-1,1) == "\t")
					sLine = sLine.SubString(0, sLine.Length()-1);
			
			if(sLine.SubString(0,1) == "#" || sLine.IsEmpty())
				continue;
			
			array<string> parsed = sLine.Split(" ");
			if(parsed.length() < 4)
				continue;
			
			int iR = cclamp(atoi(parsed[1]), 0, 255);
			int iG = cclamp(atoi(parsed[2]), 0, 255);
			int iB = cclamp(atoi(parsed[3]), 0, 255);
			Vector color = Vector(iR, iG, iB);
			g_TrailColors[parsed[0].ToLowercase()] = color;			
		}
		file.Close();
	}
}

class TrailSpriteData
{
	int sprIndex;
	string sprPath;
	bool sprColored;
}
dictionary g_TrailSprites;

const string g_SpriteFile = "scripts/plugins/Zode/trailsprites.txt";
void ReadSprites()
{
	File@ file = g_FileSystem.OpenFile(g_SpriteFile, OpenFile::READ);
	if(file !is null && file.IsOpen())
	{
		while(!file.EOFReached())
		{
			string sLine;
			file.ReadLine(sLine);
			if(sLine.SubString(sLine.Length()-1,1) == " " || sLine.SubString(sLine.Length()-1,1) == "\n" || sLine.SubString(sLine.Length()-1,1) == "\r" || sLine.SubString(sLine.Length()-1,1) == "\t")
					sLine = sLine.SubString(0, sLine.Length()-1);
			
			if(sLine.SubString(0,1) == "#" || sLine.IsEmpty())
				continue;
			
			array<string> parsed = sLine.Split(" ");
			if(parsed.length() < 3)
				continue;
			
			//linux quickfix
			if(parsed[1].SubString(parsed[1].Length()-1,1) == " " || parsed[1].SubString(parsed[1].Length()-1,1) == "\n" || parsed[1].SubString(parsed[1].Length()-1,1) == "\r" || parsed[1].SubString(parsed[1].Length()-1,1) == "\t")
				parsed[1] = parsed[1].SubString(0, parsed[1].Length()-1);
				
			TrailSpriteData tsData;
			tsData.sprPath = parsed[0];
			tsData.sprColored = atoi(parsed[2]) > 0 ? true : false;
			g_TrailSprites[parsed[1].ToLowercase()] = tsData;	
		}
		file.Close();
	}
}

CTextMenu@ trailMenu = null;
void trailMenuCallBack(CTextMenu@ mMenu, CBasePlayer@ pPlayer, int iPage, const CTextMenuItem@ mItem)
{
	if(mItem !is null && pPlayer !is null)
	{
		if(mItem.m_szName == "<off>")
		{
			string steamId = getFixedSteamId(pPlayer);
			if(g_PlayerTrails.exists(steamId) && steamId != "")
			{
				if(g_cvarSilence.GetBool())
				{
					g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail menu] You no longer have a trail.\n");
				}else{
					g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail menu] " + pPlayer.pev.netname + " no longer has a trail.\n");
				}
				
				removeTrail(pPlayer);
				return;
			}
			
			g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail menu] You don't have a trail!\n");
			return;
		}
		
		string steamId = getFixedSteamId(pPlayer);
		PlayerTrailData@ ptData = cast<PlayerTrailData@>(g_PlayerTrails[steamId]);
		if(g_cvarSilence.GetBool())
		{
			g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail menu] You now have a "+mItem.m_szName+" trail (sprite \""+ptData.sprName+"\").\n");
		}else{
			g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail menu] " + pPlayer.pev.netname + " has now a "+mItem.m_szName+" trail (sprite \""+ptData.sprName+"\").\n");
		}
		
		addTrail(pPlayer, Vector(g_TrailColors[mItem.m_szName]), "!NOSET!");
	}
}

CTextMenu@ spriteMenu = null;
void spriteMenuCallBack(CTextMenu@ mMenu, CBasePlayer@ pPlayer, int iPage, const CTextMenuItem@ mItem)
{
	if(mItem !is null && pPlayer !is null)
	{
		TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[mItem.m_szName]);
		if(tsData.sprColored)
		{
			addTrail(pPlayer, Vector(255,255,255), mItem.m_szName);
			if(g_cvarSilence.GetBool())
			{
				g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail menu] You now have a colored trail (sprite \""+mItem.m_szName+"\").\n");
			}else{
				g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail menu] " + pPlayer.pev.netname + " has now a colored trail (sprite \""+mItem.m_szName+"\").\n");
			}
		}else{
			setSprite(pPlayer, mItem.m_szName);
			trailMenu.Open(0, 0, pPlayer);
		}
	}
}

HookReturnCode ClientSay(SayParameters@ pParams)
{
	CBasePlayer@ pPlayer = pParams.GetPlayer();
	const CCommand@ cArguments = pParams.GetArguments();
	bool bSilent = g_cvarSilence.GetBool();
	
	if(cArguments.ArgC() >= 2)
	{
		if(cArguments.Arg(0).ToLowercase() == "trail")
		{	
			if(!g_isSafe) // skip
			{
				if(bSilent)
				{
					g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] Please wait until map change, this plugins needs to precache sprites.\n");
				}else{
					g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] Please wait until map change, this plugins needs to precache sprites.\n");
				}
				
				return HOOK_CONTINUE;
			}
			if(!g_bHasColors)
			{ // most likely as_reloadplugins or map change, still cant hurt to re-read colors n stuff
				if(@trailMenu !is null)
				{
					trailMenu.Unregister();
					@trailMenu = null;
				}
				
				if(@spriteMenu !is null)
				{
					spriteMenu.Unregister();
					@spriteMenu = null;
				}
				
				g_TrailColors.deleteAll();
				g_PlayerTrails.deleteAll();
				ReadColors();
				g_bHasColors = true;
			}
			
			pParams.ShouldHide = g_cvarHideChat.GetBool();
			if(cArguments.Arg(1).ToLowercase() == "off")
			{
				if(bSilent)
				{
					g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] You no longer have a trail.\n");
				}else{
					g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] " + pPlayer.pev.netname + " no longer has a trail.\n");
				}
				
				removeTrail(pPlayer);
			}else if(cArguments.Arg(1).ToLowercase() == "menu")
			{
				if(@trailMenu is null)
				{
					@trailMenu = CTextMenu(trailMenuCallBack);
					trailMenu.SetTitle("Trail menu (COLOR): ");
					trailMenu.AddItem("<off>", null);
					array<string> colorNames = g_TrailColors.getKeys();
					colorNames.sortAsc();
					for(uint i = 0; i < colorNames.length(); i++)
					{
						trailMenu.AddItem(colorNames[i].ToLowercase(), null);
					}
					
					trailMenu.Register();
					//trailMenu.Open(0, 0, pPlayer);
				}
				if(@spriteMenu is null)
				{
					@spriteMenu = CTextMenu(spriteMenuCallBack);
					spriteMenu.SetTitle("Trail menu (SPRITE): ");
					array<string> spriteNames = g_TrailSprites.getKeys();
					spriteNames.sortAsc();
					for(uint i = 0; i < spriteNames.length(); i++)
					{
						spriteMenu.AddItem(spriteNames[i].ToLowercase(), null);
					}
					
					spriteMenu.Register();
					spriteMenu.Open(0, 0, pPlayer);
				}else{
					spriteMenu.Open(0, 0, pPlayer);
				}
			}else{
				if(g_TrailColors.exists(cArguments.Arg(1).ToLowercase()))
				{
					string sSprite = g_TrailSprites.exists(cArguments.Arg(2).ToLowercase()) ? cArguments.Arg(2).ToLowercase() : g_cvarTrailDefaultSprite.GetString();
							
					if(bSilent)
					{
						g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] You now have a "+cArguments.Arg(1).ToLowercase()+" trail (sprite \""+sSprite+"\").\n");
					}else{
						g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] " + pPlayer.pev.netname + " has now a "+cArguments.Arg(1).ToLowercase()+" trail (sprite \""+sSprite+"\").\n");
					}
					
					
					
					addTrail(pPlayer, Vector(g_TrailColors[cArguments.Arg(1).ToLowercase()]), sSprite);
				}else if(g_TrailSprites.exists(cArguments.Arg(1).ToLowercase())){
					string sSprite =  cArguments.Arg(1).ToLowercase();
						
					TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);
					if(tsData.sprColored)
					{
						if(bSilent)
						{
							g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] You now have a colored trail (sprite \""+sSprite+"\").\n");
						}else{
							g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] " + pPlayer.pev.netname + " has now a colored trail (sprite \""+sSprite+"\").\n");
						}
						
						addTrail(pPlayer, Vector(255,255,255), sSprite);
					}else{
						if(bSilent)
						{
							g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] \""+sSprite+"\" isnt a colored sprite! use \"trail <color> <sprite>\" or \"trail menu\".\n");
						}else{
							g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] \""+sSprite+"\" isnt a colored sprite! use \"trail <color> <sprite>\" or \"trail menu\".\n");
						}
					}
				}else{
					if(bSilent)
					{
						g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[Trail] No such color or colored sprite, try typing \"trail menu\"?\n");
					}else{
						g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[Trail] No such color or colored sprite, try typing \"trail menu\"?\n");
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
	string steamId = getFixedSteamId(pPlayer);
	if(g_PlayerTrails.exists(steamId) && steamId != "")
		g_PlayerTrails.delete(steamId);

	if(g_PlayerCrossover.exists(steamId) && steamId != "")
		g_PlayerCrossover.delete(steamId);
		
	//removeTrail(pPlayer);
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerSpawn(CBasePlayer@ pPlayer)
{	// check if crossover data exists
	string steamId = getFixedSteamId(pPlayer);
	
	if(g_PlayerCrossover.exists(steamId))
		if(!g_PlayerTrails.exists(steamId))
			g_Scheduler.SetTimeout("plrPostSpawn", 1.0f, g_EngineFuncs.IndexOfEdict(pPlayer.edict()), steamId);
	
	return HOOK_CONTINUE;
	
}

void plrPostSpawn(int &in iIndex, string &in steamId)
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(iIndex);
	if(pPlayer is null)
		return;
		
	PlayerCrossoverData@ pcData = cast<PlayerCrossoverData@>(g_PlayerCrossover[steamId]);
	if(pcData.sprName == "!NOSET!" || pcData.sprName.IsEmpty())
		return;
		
	addTrail(pPlayer, pcData.color, pcData.sprName);
}

void trailThink()
{
	if(g_PlayerTrails.isEmpty())
		return;
		
	array<string> playerTrailIds = g_PlayerTrails.getKeys();
	for(uint i = 0; i < playerTrailIds.length(); i++)
	{
		PlayerTrailData@ ptData = cast<PlayerTrailData@>(g_PlayerTrails[playerTrailIds[i]]);
		if(!ptData.enabled)
			return;
		
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(ptData.id);
		
		if(pPlayer is null)
			return;
		
		Vector vVel = pPlayer.pev.velocity;
		bool bTemp = false;
		
		if(vVel.x == 0 && vVel.y == 0 && vVel.z == 0)
			ptData.restart = true;
			
		if(ptData.restart)
		{
			if(vVel.x >= 2 || vVel.x <= -2) { bTemp = true; }
			if(vVel.y >= 2 || vVel.y <= -2) { bTemp = true; }
			if(vVel.z >= 2 || vVel.z <= -2) { bTemp = true; }
		}
		
		if(bTemp)
		{
			ptData.restart = false;
			
			killMsg(ptData.id);
			trailMsg(pPlayer, ptData.color, ptData.sprIndex);
		}
	}
}

void setSprite(CBasePlayer@ pPlayer, string sSprite)
{
	string steamId = getFixedSteamId(pPlayer);
	if(g_PlayerTrails.exists(steamId) && steamId != "")
	{
		PlayerTrailData@ ptData = cast<PlayerTrailData@>(g_PlayerTrails[steamId]);
		TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);
		PlayerCrossoverData@ pcData = cast<PlayerCrossoverData@>(g_PlayerCrossover[steamId]);
		ptData.enabled = false;
		ptData.sprIndex = tsData.sprIndex;
		ptData.sprName = sSprite;
		pcData.sprName = sSprite;
	}else{
		PlayerTrailData ptData;
		TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);
		PlayerCrossoverData pcData;
		ptData.enabled = false;
		ptData.sprIndex = tsData.sprIndex;
		ptData.sprName = sSprite;
		pcData.sprName = sSprite;
		g_PlayerTrails[steamId] = ptData;
		g_PlayerCrossover[steamId] = pcData;
	}
}

void addTrail(CBasePlayer@ pPlayer, Vector color, string sSprite)
{
	string steamId = getFixedSteamId(pPlayer);
	if(g_PlayerTrails.exists(steamId) && steamId != "")
	{ // replace
		Vector TargetColor = color;
		PlayerTrailData@ ptData = cast<PlayerTrailData@>(g_PlayerTrails[steamId]);
		ptData.id = g_EntityFuncs.EntIndex(pPlayer.edict());
		ptData.color = TargetColor;
		ptData.restart = false;
		ptData.enabled = true;
		PlayerCrossoverData@ pcData = cast<PlayerCrossoverData@>(g_PlayerCrossover[steamId]);
		pcData.color = TargetColor;
		TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);
		if(tsData.sprColored)
		{
			ptData.color = Vector(255,255,255);
			pcData.color = Vector(255,255,255);
			TargetColor = Vector(255,255,255);
		}
		if(sSprite != "!NOSET!")
		{
			ptData.sprIndex = tsData.sprIndex;
			pcData.sprName = sSprite;
		}
		
		
		killMsg(ptData.id);
		trailMsg(pPlayer, TargetColor, ptData.sprIndex);
	}else{ // new
		Vector TargetColor = color;
		PlayerTrailData ptData;
		ptData.id = g_EntityFuncs.EntIndex(pPlayer.edict());
		ptData.color = TargetColor;
		ptData.restart = false;
		ptData.enabled = true;
		PlayerCrossoverData pcData;
		pcData.color = TargetColor;
		TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);
		if(tsData.sprColored)
		{
			ptData.color = Vector(255,255,255);
			pcData.color = Vector(255,255,255);
			TargetColor = Vector(255,255,255);
		}
		if(sSprite != "!NOSET!")
		{
			ptData.sprIndex = tsData.sprIndex;
			pcData.sprName = sSprite;	
		}
		
		g_PlayerTrails[steamId] = ptData;
		g_PlayerCrossover[steamId] = pcData;
		trailMsg(pPlayer, TargetColor, ptData.sprIndex);
	}
		
}

void trailMsg(CBasePlayer@ pPlayer, Vector color, int sprIndex)
{
	int iId = g_EntityFuncs.EntIndex(pPlayer.edict());
	//send trail message
	NetworkMessage message(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
		message.WriteByte(TE_BEAMFOLLOW);
		message.WriteShort(iId);
		message.WriteShort(sprIndex);
		message.WriteByte(g_iFixedTrailDuration);
		message.WriteByte(g_iFixedTrailSize);
		message.WriteByte(int(color.x));
		message.WriteByte(int(color.y));
		message.WriteByte(int(color.z));
		message.WriteByte(g_iFixedTrailAlpha);
	message.End();
}

void removeTrail(CBasePlayer@ pPlayer)
{
	string steamId = getFixedSteamId(pPlayer);
	if(g_PlayerTrails.exists(steamId) && steamId != "")
		g_PlayerTrails.delete(steamId);
		
	if(g_PlayerCrossover.exists(steamId) && steamId != "")
		g_PlayerCrossover.delete(steamId);
		
	int iId = g_EntityFuncs.EntIndex(pPlayer.edict());
	killMsg(iId);
}

void killMsg(int iId)
{
	//send kill trail message
	NetworkMessage message(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
		message.WriteByte(TE_KILLBEAM);
		message.WriteShort(iId);
	message.End();
}
