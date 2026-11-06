#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\buried_menu\buried;
#include scripts\zm\buried_menu\buriedfullgame;
#include scripts\zm\buried_menu\mazeprac;
#include scripts\zm\buried_menu\bellstart;
#include scripts\zm\buried_menu\wispric;
#include scripts\zm\buried_menu\wispmax;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Practice modes
##############################################################################*/
// The first mode is the default.
register_modes()
{
	level.modes = [];
	mode_timer(register_mode("buriedfullgame", "Fullgame", ::buriedfullgame_initialize, ::buriedfullgame_run, ::buriedfullgame_build_menu), false, BURIED_SPLIT_BOXHIT);
	mode_timer(register_mode("mazeprac", "Maze Prac", ::mazeprac_initialize, ::mazeprac_run, ::mazeprac_build_menu), false, BURIED_SPLIT_SHARPSHOOTER);
	mode_timer(register_mode("bellstart", "Bell Start", ::bellstart_initialize, ::bellstart_run, ::bellstart_build_menu), false, BURIED_SPLIT_SHARPSHOOTER);
	mode_timer(register_mode("wispric", "Richtofen Wisp", ::wispric_initialize, ::wispric_run, ::wispric_build_menu), false, BURIED_SPLIT_TIME_TRAVEL);
	mode_timer(register_mode("wispmax", "Maxis Wisp", ::wispmax_initialize, ::wispmax_run, ::wispmax_build_menu), false, BURIED_SPLIT_TIME_TRAVEL);
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
