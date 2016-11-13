string getFixedSteamId(CBasePlayer@ pPlayer)
{
	if(pPlayer is null or !pPlayer.IsConnected())
		return "";	
	
	string steamId = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
	if(steamId == 'STEAM_ID_LAN' or steamId == 'BOT')
		steamId = pPlayer.pev.netname;
		
	return steamId;
}

//yes i know CMath clamps exist but ehhhhh
uint cclamp(uint nIn, uint nMin, uint nMax)
{
	return Math.min(Math.max(nIn, nMin), nMax);
}

float cclamp(float nIn, float nMin, float nMax)
{
	return Math.min(Math.max(nIn, nMin), nMax);
}

int cclamp(int nIn, int nMin, int nMax)
{
	return Math.min(Math.max(nIn, nMin), nMax);
}