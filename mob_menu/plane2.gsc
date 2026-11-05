#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\splits;
#include scripts\zm\mob_menu\planeutil;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Plane 2
##############################################################################*/
// The second plane: one trip to the bridge counted as done, the plane built and
// refuelled and ready to board, every soul catcher full. New in this tool
// (the old M-Practice listed it as "coming soon"); the start round and items
// are settings until the route's real state is known.

#define PLANE2_CYCLES      1     // Trips to the bridge already done.
#define PLANE2_ROUND       6     // Default start round (placeholder, see multimap_plan.md).
#define PLANE2_TIME_FIRST   "9:00"   // Plane Time presets: the route's boarding window,
#define PLANE2_TIME_LAST    "11:00"   // every 5 s; default in the middle (user,
#define PLANE2_TIME_DEFAULT "10:00"   // 2026-10-14).
#define PLANE2_MAX_ROUND   20

plane2_initialize()
{
    mob_plane_install();
    practice_start_time_setup("Plane Time", PLANE2_TIME_FIRST, PLANE2_TIME_LAST, 5, PLANE2_TIME_DEFAULT);
    mode_cfg_load("plane2", plane2_default_cfg());
}

plane2_run()
{
    segment = mob_plane_segment();
    segment.cycles = PLANE2_CYCLES;
    segment.split = MOB_SPLIT_PLANE_2;
    segment.start_round = get_cfg_int("start_round");
    segment.start_zombies = get_cfg_int("start_zombies");
    segment.all_wolves = true;
    segment.tomahawk = get_cfg_int("tomahawk");
    segment.perks = mob_plane_cfg_perks();
    level mob_run_plane_segment(segment);
}

plane2_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        mob_plane_settings_menu(settings, 3, PLANE2_MAX_ROUND);
        add_cfg_toggle(settings, "Tomahawk", "tomahawk");
}

plane2_default_cfg()
{
    settings_ar = [];
    settings_ar = mob_plane_default_cfg(settings_ar, PLANE2_ROUND, START_ZOMBIES_FULL);
    settings_ar["tomahawk"] = 1;
    settings_ar["perk_jugg"] = 1;
    return settings_ar;
}
