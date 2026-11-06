#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\mob_menu\freeroam;
#include scripts\zm\mob_menu\mob;
#include scripts\zm\mob_menu\mobfullgame;
#include scripts\zm\mob_menu\plane1;
#include scripts\zm\mob_menu\plane2;
#include scripts\zm\mob_menu\plane3;
#include scripts\zm\mob_menu\wardensnade;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Practice modes
##############################################################################*/
// The first mode is the default.
register_modes()
{
	level.modes = [];
	mode_timer(register_mode("mobfullgame", "Fullgame",  ::mobfullgame_initialize, ::mobfullgame_run, ::mobfullgame_build_menu), false, MOB_SPLIT_DRYER);
	mode_timer(register_mode("plane1",      "Plane I",   ::plane1_initialize,      ::plane1_run,      ::plane1_build_menu), false, MOB_SPLIT_PLANE_1);
	mode_timer(register_mode("plane2",      "Plane II",  ::plane2_initialize,      ::plane2_run,      ::plane2_build_menu), false, MOB_SPLIT_PLANE_2);
	mode_timer(register_mode("plane3",      "Plane III", ::plane3_initialize,      ::plane3_run,      ::plane3_build_menu), false, MOB_SPLIT_PLANE_3);
	register_mode("wardensnade", "Warden's Nade", ::wardensnade_initialize, ::wardensnade_run, ::wardensnade_build_menu);
	register_mode("freeroam",    "Freeroam",  ::freeroam_initialize,    ::freeroam_run);
}

main()
{
	if(!mob_map_active()) return;
	register_modes();
	practice_main(mob_practice_map(), "DEV BUILD");
}

init()
{
	if(!mob_map_active()) return;
	practice_init();
}
