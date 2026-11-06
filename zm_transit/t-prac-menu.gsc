#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\tranzit_menu\tranzit;
#include scripts\zm\tranzit_menu\tranzitfullgame;
#include scripts\zm\tranzit_menu\endingemp;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              Practice modes
##############################################################################*/
// The first mode is the default.
register_modes()
{
	level.modes = [];
	mode_timer(register_mode("tranzitfullgame", "Fullgame", ::tranzitfullgame_initialize, ::tranzitfullgame_run, ::tranzitfullgame_build_menu), false, 0);
	mode_timer(register_mode("endingemp", "Ending EMP", ::endingemp_initialize, ::endingemp_run, ::endingemp_build_menu), false, 0);
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
