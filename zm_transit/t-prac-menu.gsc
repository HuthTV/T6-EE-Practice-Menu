#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\tranzit_menu\tranzit;
#include scripts\zm\tranzit_menu\tranzitfullgame;
#include scripts\zm\tranzit_menu\endingemp;
#include scripts\zm\tranzit_menu\freeroam;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              Practice modes
##############################################################################*/
// The first mode is the default.
register_modes()
{
	level.modes = [];
	register_mode("tranzitfullgame", "Fullgame",   ::tranzitfullgame_initialize, ::tranzitfullgame_run, ::tranzitfullgame_build_menu);
	register_mode("endingemp",       "Ending EMP", ::endingemp_initialize,       ::endingemp_run,       ::endingemp_build_menu);
	register_mode("freeroam",        "Freeroam",   ::freeroam_initialize,        ::freeroam_run);
}

main()
{
	if(!tranzit_map_active()) return;
	register_modes();
	practice_main(tranzit_practice_map(), "DEV BUILD");
}

init()
{
	if(!tranzit_map_active()) return;
	practice_init();
}
