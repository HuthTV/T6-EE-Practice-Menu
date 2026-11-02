#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zm_tomb_utility;
#include maps\mp\zm_tomb_quest_crypt;
#include maps\mp\zm_tomb_main_quest;
#include maps\mp\zm_tomb_craftables;
#include maps\mp\zombies\_zm_craftables;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\endingprac;
#include scripts\zm\origins_menu\firestart;
#include scripts\zm\origins_menu\fullgame;
#include scripts\zm\origins_menu\genprac;
#include scripts\zm\origins_menu\hundredkills;
#include scripts\zm\origins_menu\icestart;
#include scripts\zm\origins_menu\lightningstart;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\panzerstart;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\windstart;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Practice modes
##############################################################################*/
// The first mode is the default.
register_modes()
{
	level.modes = [];
	mode_timer(register_mode("fullgame",       "Fullgame",        ::fullgame_initialize,       ::fullgame_run,       ::fullgame_build_menu), true, SPLIT_NML);
	mode_timer(register_mode("icestart",       "Icestart",        ::icestart_initialize,       ::shared_run_segment, ::icestart_build_menu), true, SPLIT_ICE);
	mode_timer(register_mode("windstart",      "Windstart",       ::windstart_initialize,      ::shared_run_segment, ::windstart_build_menu), true, SPLIT_WIND);
	mode_timer(register_mode("firestart",      "Firestart",       ::firestart_initialize,      ::shared_run_segment, ::firestart_build_menu), true, SPLIT_FIRE);
	mode_timer(register_mode("lightningstart", "Lightningstart",  ::lightningstart_initialize, ::shared_run_segment, ::lightningstart_build_menu), true, SPLIT_LIGHTNING);
	mode_timer(register_mode("endingprac",     "Ending prac",     ::endingprac_initialize,     ::shared_run_segment, ::endingprac_build_menu), true, SPLIT_FREEDOM);
	mode_timer(register_mode("hundredkills",   "Raise Hell",      ::hundredkills_initialize,   ::shared_run_segment, ::hundredkills_build_menu), true, SPLIT_FREEDOM);
	mode_timer(register_mode("panzerstart",    "Panzerstart",     ::panzerstart_initialize,    ::shared_run_segment, ::panzerstart_build_menu), true, SPLIT_ICE);
	register_mode("genprac",        "Gen Practice",    ::genprac_initialize,        ::genprac_run,        ::genprac_build_menu);

	// Template for new modes (origins_menu\examplemode.gsc); uncomment it and its
	// #include to try it.
	//register_mode("examplemode",  "Example Mode",    ::examplemode_initialize,    ::examplemode_run,    ::examplemode_build_menu);
}

main()
{
	if(!shared_map_active()) return;
	// Robot and foot names for the menus.
	level.robot[ROBOT_RANDOM] = "random";
	level.robot[ROBOT_ODIN] = "odin";
	level.robot[ROBOT_THOR] = "thor";
	level.robot[ROBOT_FREYA] = "freya";
	level.foot[FOOT_RANDOM] = "random";
	level.foot[FOOT_LEFT] = "left";
	level.foot[FOOT_RIGHT] = "right";

	register_modes();
	practice_main(shared_practice_map(), "DEV BUILD");
}

init()
{
	if(!shared_map_active()) return;
	practice_init();
}
