#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\splits;
#include scripts\zm\buried_menu\buriedquest;
#include scripts\zm\buried_menu\buriedstart;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Maxis Wisp
##############################################################################*/
// Round 2, full round, at the oil lamp ready to craft it (user, 2026-11-06).

#define WISPMAX_TIME_FIRST   "5:00"   // Start Time limits (user, 2026-11-06).
#define WISPMAX_TIME_LAST    "7:00"
#define WISPMAX_TIME_DEFAULT "6:00"

wispmax_initialize()
{
    buried_start_install();
    practice_custom_time_setup(WISPMAX_TIME_FIRST, WISPMAX_TIME_LAST, WISPMAX_TIME_DEFAULT);
    mode_cfg_load("wispmax", wispmax_default_cfg());
}

wispmax_run()
{
    start = buried_start();
    start.side = BURIED_SIDE_MAXIS;
    buried_start_run(start);
}

wispmax_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        practice_custom_time_menu(settings);
        buried_sign_menu(settings);
}

wispmax_default_cfg()
{
    settings_ar = [];
    settings_ar = practice_custom_time_defaults(settings_ar);
    settings_ar = buried_quest_defaults(settings_ar);
    return settings_ar;
}
