#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\splits;
#include scripts\zm\mob_menu\planeutil;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Plane 3
##############################################################################*/
// The third plane: two trips to the bridge counted as done, the plane built and
// refuelled and ready to board, every soul catcher full. New in this tool
// (the old M-Practice listed it as "coming soon"); the start round and items
// are settings until the route's real state is known.

#define PLANE3_CYCLES      2     // Trips to the bridge already done.
#define PLANE3_ROUND       9     // Default start round (placeholder, see multimap_plan.md).
#define PLANE3_TIME_FIRST   "13:00"   // Plane Time presets: the route's boarding window,
#define PLANE3_TIME_LAST    "15:00"   // every 5 s; default in the middle (user,
#define PLANE3_TIME_DEFAULT "14:00"   // 2026-10-14).
#define PLANE3_MAX_ROUND   20

plane3_initialize()
{
    mob_plane_install();
    practice_start_time_setup("Plane Time", PLANE3_TIME_FIRST, PLANE3_TIME_LAST, 5, PLANE3_TIME_DEFAULT);
    mode_cfg_load("plane3", plane3_default_cfg());
}

plane3_run()
{
    segment = mob_plane_segment();
    segment.cycles = PLANE3_CYCLES;
    segment.split = MOB_SPLIT_PLANE_3;
    segment.start_round = get_cfg_int("start_round");
    segment.start_zombies = get_cfg_int("start_zombies");
    segment.all_wolves = true;
    segment.tomahawk = get_cfg_int("tomahawk");
    segment.perks = mob_plane_cfg_perks();
    level mob_run_plane_segment(segment);
}

plane3_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        mob_plane_settings_menu(settings, 3, PLANE3_MAX_ROUND);
        add_cfg_toggle(settings, "Tomahawk", "tomahawk", "^2Yes", "^1No");
}

plane3_default_cfg()
{
    settings_ar = [];
    settings_ar = mob_plane_default_cfg(settings_ar, PLANE3_ROUND, START_ZOMBIES_FULL);
    settings_ar["tomahawk"] = 1;
    settings_ar["perk_jugg"] = 1;
    return settings_ar;
}
