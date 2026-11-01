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
#include scripts\zm\origins_menu\firestart;
#include scripts\zm\origins_menu\fullgame;
#include scripts\zm\origins_menu\genprac;
#include scripts\zm\origins_menu\icecode;
#include scripts\zm\origins_menu\icestart;
#include scripts\zm\origins_menu\lightningstart;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\panzprac;
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
	mode_timer(register_mode("icestart",       "Icestart",        ::icestart_initialize,       ::icestart_run,       ::shared_build_segment_menus), true, SPLIT_ICE);
	mode_timer(register_mode("windstart",      "Windstart",       ::windstart_initialize,      ::windstart_run,      ::shared_build_segment_menus), true, SPLIT_WIND);
	mode_timer(register_mode("firestart",      "Firestart",       ::firestart_initialize,      ::firestart_run,      ::shared_build_segment_menus), true, SPLIT_FIRE);
	mode_timer(register_mode("lightningstart", "Lightningstart",  ::lightningstart_initialize, ::lightningstart_run, ::shared_build_segment_menus), true, SPLIT_LIGHTNING);
	register_mode("panzprac",       "Panzer Practice", ::panzprac_initialize,       ::panzprac_run,       ::panzprac_build_menu);
	register_mode("genprac",        "Gen Practice",    ::genprac_initialize,        ::genprac_run,        ::genprac_build_menu);
	register_mode("icecode",        "Ice code",        ::icecode_initialize,        ::icecode_run,        ::icecode_build_menu);
	// Placeholders: listed in the menu but not selectable until implemented.
	register_mode("windbulbs",      "Wind Bulbs");
	register_mode("windcode",       "Wind Code");
	register_mode("firecode",       "Fire Code");
	register_mode("endingprac",     "Ending prac");
	register_mode("raisehellprac",  "Raise hell prac");

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
