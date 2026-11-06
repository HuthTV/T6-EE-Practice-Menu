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
                              Maze Prac
##############################################################################*/
// Richtofen's maze switches, the step Maxis does not have: round 2 with a few zombies
// left, in the maze (user, 2026-11-06).

#define MAZEPRAC_TIME_FIRST   "6:00"   // Start Time limits (user, 2026-11-06).
#define MAZEPRAC_TIME_LAST    "8:00"
#define MAZEPRAC_TIME_DEFAULT "7:00"
#define MAZEPRAC_SPOT         (4857, 371, 32)   // A zone_maze respawn struct.

mazeprac_initialize()
{
    buried_start_install();
    practice_custom_time_setup(MAZEPRAC_TIME_FIRST, MAZEPRAC_TIME_LAST, MAZEPRAC_TIME_DEFAULT);
    mode_cfg_load("mazeprac", mazeprac_default_cfg());
}

mazeprac_run()
{
    start = buried_start();
    start.zombies = get_cfg_int("start_zombies");
    start.spot = MAZEPRAC_SPOT;
    start.past_lamp = true;
    start.fountain_bomb = get_cfg_int("guillotine_max");
    start.first_split = BURIED_SPLIT_SHARPSHOOTER;
    buried_start_run(start);
}

mazeprac_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        practice_custom_time_menu(settings);
        create_option(settings, "Zombies Left: ^3" + get_cfg_int("start_zombies"), ::cfg_increment_int, "start_zombies", array(1, 3));
        add_cfg_toggle(settings, "Guillotine Max", "guillotine_max", "^2yes", "^3no");
}

mazeprac_default_cfg()
{
    settings_ar = [];
    settings_ar = practice_custom_time_defaults(settings_ar);
    settings_ar = buried_quest_defaults(settings_ar);
    settings_ar["start_zombies"] = 2;
    settings_ar["guillotine_max"] = 1; // A time bomb on the fountain (user, 2026-11-06).
    return settings_ar;
}
