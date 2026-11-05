#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\buried_menu\buried;
#include scripts\zm\buried_menu\buriedfullgame;
#include scripts\zm\buried_menu\freeroam;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Practice modes
##############################################################################*/
// The first mode is the default.
register_modes()
{
	level.modes = [];
	register_mode("buriedfullgame", "Fullgame", ::buriedfullgame_initialize, ::buriedfullgame_run, ::buriedfullgame_build_menu);
	register_mode("freeroam",       "Freeroam", ::freeroam_initialize,       ::freeroam_run);
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
