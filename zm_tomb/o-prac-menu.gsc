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
#include scripts\zm\origins_menu\fullgame;
#include scripts\zm\origins_menu\genprac;
#include scripts\zm\origins_menu\hundredkills;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\panzerstart;
#include scripts\zm\origins_menu\postfire;
#include scripts\zm\origins_menu\postice;
#include scripts\zm\origins_menu\postlightning;
#include scripts\zm\origins_menu\postwind;
#include scripts\zm\origins_menu\prefire;
#include scripts\zm\origins_menu\preice;
#include scripts\zm\origins_menu\prelightning;
#include scripts\zm\origins_menu\prewind;
#include scripts\zm\origins_menu\segmentutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Practice modes
##############################################################################*/
// The first mode is the default.
register_modes()
{
	level.modes = [];
	mode_timer(register_mode("fullgame",       "Fullgame",        ::fullgame_initialize,       ::fullgame_run,       ::fullgame_build_menu), true, SPLIT_NML);
	mode_timer(register_mode("preice",         "Pre-Ice",         ::preice_initialize,         ::shared_run_segment, ::preice_build_menu), true, SPLIT_ICE);
	mode_timer(register_mode("postice",        "Post-Ice",        ::postice_initialize,        ::shared_run_segment, ::postice_build_menu), true, SPLIT_WIND);
	mode_timer(register_mode("prewind",        "Pre-Wind",        ::prewind_initialize,        ::shared_run_segment, ::prewind_build_menu), true, SPLIT_WIND);
	mode_timer(register_mode("postwind",       "Post-Wind",       ::postwind_initialize,       ::shared_run_segment, ::postwind_build_menu), true, SPLIT_FIRE);
	mode_timer(register_mode("prefire",        "Pre-Fire",        ::prefire_initialize,        ::shared_run_segment, ::prefire_build_menu), true, SPLIT_FIRE);
	mode_timer(register_mode("postfire",       "Post-Fire",       ::postfire_initialize,       ::shared_run_segment, ::postfire_build_menu), true, SPLIT_LIGHTNING);
	mode_timer(register_mode("prelightning",   "Pre-Lightning",   ::prelightning_initialize,   ::shared_run_segment, ::prelightning_build_menu), true, SPLIT_LIGHTNING);
	mode_timer(register_mode("postlightning",  "Post-Lightning",  ::postlightning_initialize,  ::shared_run_segment, ::postlightning_build_menu), true, SPLIT_FREEDOM);
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
