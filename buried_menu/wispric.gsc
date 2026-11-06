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
                              Richtofen Wisp
##############################################################################*/
// Round 2, full round, at the oil lamp ready to craft it (user, 2026-11-06).

#define WISPRIC_TIME_FIRST   "3:00"   // Start Time limits (user, 2026-11-06).
#define WISPRIC_TIME_LAST    "5:00"
#define WISPRIC_TIME_DEFAULT "4:00"

wispric_initialize()
{
    buried_start_install();
    practice_custom_time_setup(WISPRIC_TIME_FIRST, WISPRIC_TIME_LAST, WISPRIC_TIME_DEFAULT);
    mode_cfg_load("wispric", wispric_default_cfg());
}

wispric_run()
{
    start = buried_start();
    start.side = BURIED_SIDE_RICHTOFEN;
    buried_start_run(start);
}

wispric_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        practice_custom_time_menu(settings);
        buried_sign_menu(settings);
        buried_fork_menu(settings);
}

wispric_default_cfg()
{
    settings_ar = [];
    settings_ar = practice_custom_time_defaults(settings_ar);
    settings_ar = buried_quest_defaults(settings_ar);
    return settings_ar;
}
