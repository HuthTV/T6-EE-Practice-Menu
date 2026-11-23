#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\puzzlerng;
#include scripts\zm\origins_menu\staffutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Quote Skip: Plane / Panzer
##############################################################################*/
// Maxis quote skip practice (user, 2026-11-22) on the plane or Panzer clue (Clue setting): end of round 7 at Gen 4
// with 2 zombies left, every wind part, the first church door open. Kill the last zombie at 8:45: cycle 5 (8:44) is
// a single robot, never Odin. A dig gives zombie blood, power Gen 4 and buy Juggernog, then shoot the plane or kill
// Panzer 1 in Samantha's line. The wind clue is Quote Skip: Wind (quoteskipwind.gsc).
// Footage first (user): the map state is close to a run, not complete. Open: which church door is the first one
// (CHURCH_BOX left open is a guess), soul box fill, real start times and split starts.

#define QUOTESKIP_PLANE   0
#define QUOTESKIP_PANZER  1

quoteskip_initialize()
{
    shared_start_time_add("release", "release", "release", "8:00", "9:00", 5, "8:30");
    mode_cfg_load("quoteskip", quoteskip_default_cfg());
    shared_segment_install(quoteskip_segment());
    shared_schedules_init(10);
    shared_held_start_install();
    level.segment.upgrade_mauser = false;
    level.shared_dig_zombie_blood = true;
    shared_quoteskip_sprint();
}

quoteskip_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_ICE;
    segment.round = 7;
    segment.round_zombies = 2;
    segment.gems = [];
    segment.tank_trips = 0;
    segment.kill_plane = false;
    segment.box_rewards = false;
    segment.tablet = ::shared_tablet_dirty; // Picked up at the bunker, not cleaned yet
    segment.generators = ::shared_quoteskip_generators;
    segment.perks = array("specialty_longersprint");
    segment.score = 3000;
    segment.excluded_doors = array(CHURCH_STAIRS);
    segment.use_exit = false;
    segment.setup = ::quoteskip_setup;
    return segment;
}

quoteskip_setup()
{
    spot = shared_gen_spot("generator_nml_right");
    level.segment.spots = shared_start_spots(spot.origin, spot.angles, spot.origin, spot.angles);
    self shared_quoteskip_items();
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "upper_staff");
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "middle_staff");
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "lower_staff");
    if(get_cfg_int("qs_hud")) self thread shared_story_vo_hud();
}

quoteskip_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_choice(settings, "Clue", "qs_clue", array("plane", "Panzer"));
        add_cfg_toggle(settings, "Story VO HUD", "qs_hud");
        add_cfg_toggle(settings, "Infinite Sprint", "qs_sprint");
        self shared_start_time_menu(settings);

    self shared_build_categories(root);
    self shared_build_segment_menus();
}

quoteskip_default_cfg()
{
    settings_ar = shared_quoteskip_defaults();
    settings_ar["qs_clue"] = QUOTESKIP_PLANE;
    settings_ar["cycle_5"] = ROBOT_THOR; // The 8:44 single robot is never Odin
    return settings_ar;
}
