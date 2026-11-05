#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\splits;
#include scripts\zm\mob_menu\planeutil;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Plane 1
##############################################################################*/
// The old M-Practice Plane 1 segment: round 3 with 1 to 4 zombies, the route
// done up to the first plane and every plane part in hand, with the drop cycle
// and points the old tool set.

#define PLANE1_ROUND  3
#define PLANE1_TIME_FIRST   "4:30"   // Plane Time presets: the route's boarding window,
#define PLANE1_TIME_LAST    "6:30"   // every 5 s; default in the middle (user,
#define PLANE1_TIME_DEFAULT "5:30"   // 2026-10-14).

plane1_initialize()
{
    mob_plane_install();
    practice_start_time_setup("Plane Time", PLANE1_TIME_FIRST, PLANE1_TIME_LAST, 5, PLANE1_TIME_DEFAULT);
    mode_cfg_load("plane1", plane1_default_cfg());
}

plane1_run()
{
    segment = mob_plane_segment();
    segment.cycles = 0;
    segment.split = MOB_SPLIT_PLANE_1;
    segment.start_round = get_cfg_int("start_round");
    segment.start_zombies = get_cfg_int("start_zombies");
    segment.docks_souls = get_cfg_int("docks_souls");
    segment.prebuilt = get_cfg_int("prebuilt_plane");
    segment.perks = mob_plane_cfg_perks();
    segment.on_start = ::plane1_drops;
    level mob_run_plane_segment(segment);
}

plane1_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_toggle(settings, "Plane built", "prebuilt_plane");
        create_option(settings, "Docks wolf souls: ^3" + plane1_docks_souls_text(), ::cfg_increment_int, "docks_souls", array(0, 6));
        mob_plane_settings_menu(settings, PLANE1_ROUND, 6);
}

plane1_default_cfg()
{
    settings_ar = [];
    settings_ar["docks_souls"] = 0;     // 0: 4 to 6 at random (old "Plane 1 fills").
    settings_ar["prebuilt_plane"] = 1;   // Built and ready to board.
    settings_ar = mob_plane_default_cfg(settings_ar, PLANE1_ROUND, START_ZOMBIES_RANDOM);
    return settings_ar;
}

plane1_docks_souls_text()
{
    if(get_cfg_int("docks_souls")) return get_cfg_int("docks_souls");
    return "random 4-6";
}

// Old M-Practice plane1_drop, unchanged: a nuke second in the drop cycle, the
// cycle index at 3, and points a little short of the next point drop.
plane1_drops()
{
    drops = array_randomize(array("full_ammo", "insta_kill", "double_points", "fire_sale"));
    level.zombie_powerup_array[0] = drops[0];
    level.zombie_powerup_array[1] = "nuke";
    level.zombie_powerup_array[2] = drops[1];
    level.zombie_powerup_array[3] = drops[2];
    level.zombie_powerup_array[4] = drops[3];
    level.zombie_powerup_index = 3;
    self.score_total = 7000 + randomintrange(0, 100) * 10;
    self.score = randomintrange(100, 125) * 10;
    level.score_to_drop = 10000 + randomintrange(0, 10) * 10;
}
