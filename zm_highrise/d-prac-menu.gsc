#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\dierise_menu\dierise;
#include scripts\zm\dierise_menu\dierisefullgame;
#inline scripts\zm\dierise_menu\dierise;

/*##############################################################################
                              Practice modes
##############################################################################*/
// The first mode is the default.
register_modes()
{
	level.modes = [];
	mode_timer(register_mode("dierisefullgame", "Fullgame", ::dierisefullgame_initialize, ::dierisefullgame_run, ::dierisefullgame_build_menu), false, 0);
}

main()
{
	if(!dierise_map_active()) return;
	register_modes();
	practice_main(dierise_practice_map(), "DEV BUILD");
}

init()
{
	if(!dierise_map_active()) return;
	practice_init();
}
