#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\buried_menu\buried;
#include scripts\zm\buried_menu\freeroam;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Practice modes
##############################################################################*/
// Skeleton (2026-10-26): structure only. build.py checks this map but does not
// install it until its Install flag is set.
// The first mode is the default.
register_modes()
{
	level.modes = [];
	register_mode("freeroam", "Freeroam", ::freeroam_initialize, ::freeroam_run);
}

main()
{
	if(!buried_map_active()) return;
	register_modes();
	practice_main(buried_practice_map(), "DEV BUILD");
}

init()
{
	if(!buried_map_active()) return;
	practice_init();
}
