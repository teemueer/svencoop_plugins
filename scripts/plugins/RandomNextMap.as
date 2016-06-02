/////////////////////////////////////////////////////////////////////
// RandomNextMap v1.3.0b
// 
//  This plugins decide next map randomly.
//
//  Notice: Remove mapname which is set "nextmap xxxx" in cfg from mapcyclelist.
//           ...or this plugin changes nextmap randomly everytime.
//
//   by takedeppo.50cal  (Im not eng speaker!! è‹±èªžã‚ã‹ã‚“ã­ãˆã‚“ã ã‚ˆ)
//   ("set_nextmap" command by JonnyBoy0719. merged with my coding style :D)
//
/////////////////////////////////////////////////////////////////////

// global 
CCVar@ g_pIgnoreEmpty = null;       // Ignore adding list when server is empty.
bool g_isPlayerConnected = false;   // Flag which is first player joined to server(each maps).
CCVar@ g_pExclude = null;           // Exclude past map count(Cvar)
array<string> g_pastList = {};      // Exclude past map list
CCVar@ g_pRandLogic = null;         // Random Logic type

// Const
const string PLUGIN_TAG = "[RandomNextMap] ";

// ClientCommand
CClientCommand cvar_set_nextmap( "set_nextmap", "Set the next map cycle", @SetNextMap );    // set nextmap
CClientCommand cvar_pastmaplist( "pastmaplist", "show played map list", @ShowPastMapList ); // show g_pastList to client console 

/** Plugin init */
void PluginInit() {
    // ....(^^;)b yay
    g_Module.ScriptInfo.SetAuthor("takedeppo.50cal");
    g_Module.ScriptInfo.SetContactInfo("http://steamcommunity.com/id/takedeppo");
    
    // Event hook
    g_Hooks.RegisterHook(Hooks::Player::ClientPutInServer, @ClientPutInServer);
    g_Hooks.RegisterHook(Hooks::Game::MapChange, @MapChange);
    
    // Cvar
    @g_pExclude     = CCVar("exclude", 10, "Exclude past map number [num]", ConCommandFlag::AdminOnly);
    @g_pIgnoreEmpty = CCVar("ignoreempty", 0, "Ignore adding list when server is empty. [0=disabled, 1=enabled]", ConCommandFlag::AdminOnly);
    @g_pRandLogic   = CCVar("logictype", 1, "Random function logic type. [0=default, 1=xorshift]", ConCommandFlag::AdminOnly);
}

/**  Map init */
void MapInit() {
    g_isPlayerConnected = false;
    
    string old = g_MapCycle.GetNextMap();
    if (isNextmapInList()) {
        execRandomNextMap();
    }
    
    if (old != g_MapCycle.GetNextMap()) {
        g_EngineFuncs.ServerPrint(PLUGIN_TAG + "Nextmap changed: " +  old + "->" + g_MapCycle.GetNextMap() + "\n");
    }
}

/** Player Connected */
HookReturnCode ClientPutInServer(CBasePlayer@ pPlayer) {
    g_isPlayerConnected = true;
    return HOOK_CONTINUE;
}

/** Map change */
HookReturnCode MapChange() {
    // ignoreempty = 1 -> Except No player case.
    if (g_pIgnoreEmpty.GetInt() == 1) {
        if (g_isPlayerConnected) {
            updatePastList(g_Engine.mapname);
        }
    
    // ignoreempty = 0 -> Always add to list.
    } else {
        updatePastList(g_Engine.mapname);
    }
    return HOOK_CONTINUE;
}

/** Check nextmap is in mapcycle list */
bool isNextmapInList() {
    // Check mapcycle num. (first map with cfg overwrote, then return 0 too.)
    if (g_MapCycle.Count() <= 0) {
        return false;
    }    
    // Retrieve maplist
    array<string> mapList = g_MapCycle.GetMapCycle();
    
    return (mapList.find(g_MapCycle.GetNextMap()) >= 0);
}

/** Change nextmap randomly */
void execRandomNextMap() {
    // Check mapcycle num. (first map with cfg overwrote, then return 0 too.)
    if (g_MapCycle.Count() <= 0) {
        return;
    }    
    // Retrieve maplist
    array<string> mapList = g_MapCycle.GetMapCycle();
    
    // Remove past maps
    mapListExclude(mapList);
    if (mapList.length() == 0) {
        return;
    }
    
    // Random choose
    uint target = (g_pRandLogic.GetInt() == 1) ? 
        xorRand(mapList.length() - 1) : Math.RandomLong(0, mapList.length() - 1);
    
    
    // Execute ServerCommand
    g_EngineFuncs.ServerCommand("mp_nextmap_cycle " + mapList[target] + "\n");
    g_EngineFuncs.ServerExecute();
}

/** Remove past maps from list */
void mapListExclude(array<string> &inout mapList) {
    // mapList - g_pastList
    int searchIndex;
    for (uint i = 0; (i < g_pastList.length()) && (mapList.length() > 0); i++) {
        searchIndex = mapList.find(g_pastList[i]);
        if (searchIndex >= 0) { 
            mapList.removeAt(searchIndex);
        }
    }
    
    // played all maps, reset g_pastList
    if (mapList.length() == 0) {
        g_pastList.resize(0);
        mapList = g_MapCycle.GetMapCycle();
    }
    
    // remove current map
    searchIndex = mapList.find(g_Engine.mapname);
    if (searchIndex >= 0) { 
        mapList.removeAt(searchIndex);
    }
}

/** Update past maps */
void updatePastList(string &in mapName) {
    array<string> mapList = g_MapCycle.GetMapCycle();
    
    // if mapName is not included mapList, return
    if (mapList.find(mapName) < 0) {
        return;
    }
    // if mapName duplicated, return
    if (g_pastList.find(mapName) >= 0) {
        return;
    }
    
    // Remove old map if over exclude list.
    uint exclude = g_pExclude.GetInt();
    if (g_pastList.length() >= exclude) {
        g_pastList.removeAt(0);
    }
    // Add past map
    g_pastList.insertLast(mapName);
}

/**
 * Changes the next map
 *  (Referenced: JonnyBoy0719's code) 
 *   thx, but Im following my coding style ....(^^;)b yay
 */
void SetNextMap(const CCommand@ args) {
    CBasePlayer@ client = g_ConCommandSystem.GetCurrentPlayer();    
    if (g_PlayerFuncs.AdminLevel(client) < ADMIN_YES) {
        g_PlayerFuncs.ClientPrint(client, HUD_PRINTCONSOLE, PLUGIN_TAG + "You must be an admin to use this command!\n");
        return;
    }
    
    // Check map
    const string mapName = args[1];
    if (mapName == "") {
        g_PlayerFuncs.ClientPrint(client, HUD_PRINTCONSOLE, PLUGIN_TAG + ".set_nextmap <mapname>\n");
        return;
    }
    if (!g_EngineFuncs.IsMapValid(mapName)) {
        g_PlayerFuncs.ClientPrint(client, HUD_PRINTCONSOLE, PLUGIN_TAG + mapName + " does not exist.\n");
        return;
    }
    
    // Grab the current nextmap
    string old = g_MapCycle.GetNextMap();
    if (old == mapName) {
        g_PlayerFuncs.ClientPrint(client, HUD_PRINTCONSOLE, PLUGIN_TAG + "You can't change to the same map. Please select another map.\n");
        return;
    }
    
    // Console message
    const string msg = PLUGIN_TAG + "Nextmap changed (by admin): " +  old + "->" + mapName + "\n";
    g_PlayerFuncs.ClientPrint(client, HUD_PRINTCONSOLE, msg);
    g_EngineFuncs.ServerPrint(msg);
    
    // Execute the changes
    g_EngineFuncs.ServerCommand("mp_nextmap_cycle " + mapName + "\n");
    g_EngineFuncs.ServerExecute();
}

/** Show g_pastList to player's console */
void ShowPastMapList(const CCommand@ args) {
    CBasePlayer@ client = g_ConCommandSystem.GetCurrentPlayer();
    
    g_PlayerFuncs.ClientPrint(client, HUD_PRINTCONSOLE, "--Past maplist---------------\n");
    for (uint i = 0; i < g_pastList.length(); i++) {
       g_PlayerFuncs.ClientPrint(client, HUD_PRINTCONSOLE, " " + (i + 1) +  ": "  + g_pastList[i] + "\n");
    }
    g_PlayerFuncs.ClientPrint(client, HUD_PRINTCONSOLE, "-----------------------------\n");
}

/** xorshift 32bit logic */
uint xorshift(uint &in seed) {
    uint y = seed;
    y = y ^ (y << 13);
    y = y ^ (y >> 17);
    y = y ^ (y << 5);
    return y;
}

/** xorshift random function */
int xorRand(int &in max) {
    // use current unixtime as seed value
    const DateTime dt = DateTime();
    const time_t unixtime = dt.ToUnixTimestamp();    
    const uint randSeed = uint(unixtime);
    
    // Cast to int FORCIBLY :D
    //  uint can not obtain correct value.
    //  ...maybe modulo(%) result depend on the types of the operand.
    int ret = xorshift(randSeed) % max;
    ret = (ret > 0) ? ret : -ret;
    
    return ret;
}
