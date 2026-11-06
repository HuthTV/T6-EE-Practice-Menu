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
                              Bell Start
##############################################################################*/
// Maxis's bells, in place of Richtofen's maze: round 2 with a few zombies left, outside
// the mansion (user, 2026-11-06). The times are placeholders, after Maxis Wisp's.

#define BELLSTART_TIME_FIRST   "7:00"   // Placeholders.
#define BELLSTART_TIME_LAST    "9:00"
#define BELLSTART_TIME_DEFAULT "8:00"
#define BELLSTART_SPOT         (2307, 588, 104)  // A zone_mansion respawn struct, on the lawn.

bellstart_initialize()
{
    buried_start_install();
    practice_custom_time_setup(BELLSTART_TIME_FIRST, BELLSTART_TIME_LAST, BELLSTART_TIME_DEFAULT);
    mode_cfg_load("bellstart", bellstart_default_cfg());
}

bellstart_run()
{
    start = buried_start();
    start.zombies = get_cfg_int("start_zombies");
    start.spot = BELLSTART_SPOT;
    start.past_lamp = true;
    start.side = BURIED_SIDE_MAXIS;
    start.first_split = BURIED_SPLIT_SHARPSHOOTER;
    buried_start_run(start);
}

bellstart_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        practice_custom_time_menu(settings);
        create_option(settings, "Zombies Left: ^3" + get_cfg_int("start_zombies"), ::cfg_increment_int, "start_zombies", array(1, 3));
}

bellstart_default_cfg()
{
    settings_ar = [];
    settings_ar = practice_custom_time_defaults(settings_ar);
    settings_ar = buried_quest_defaults(settings_ar);
    settings_ar["start_zombies"] = 2;
    return settings_ar;
}
