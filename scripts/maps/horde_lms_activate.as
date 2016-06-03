#include "horde_lms"

Survival g_Survival;

void MapInit() {
	g_Survival.MapInit();
}

// example map config (health/armor parameters depend on map, figure out good values):
//
// nomedkit
// starthealth xxx
// startarmor xxx
// maxhealth xxx
// as_command lms_enabled 1
// as_command lms_rounds 15
// map_script horde_lms_activate
