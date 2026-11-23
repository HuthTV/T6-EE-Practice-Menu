#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\puzzlerng;
#include scripts\zm\origins_menu\staffutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Quote Skip: Wind
##############################################################################*/
// Maxis quote skip practice (user, 2026-11-22) on the wind clue: round 7 mid-round at Gen 5, after No Man's Land.
// Freya walks next (cycle 4 at 6:42, start time 6:35) with the hatch in her left foot. A dig on the way gives zombie
// blood, the stomp in blood takes you into her head, and grabbing the last wind part (lower, in Freya's head) in
// Samantha's line leaves story_vo_playing stuck: the Maxis drone never speaks. The plane and Panzer clues are
// Quote Skip: Plane / Panzer (quoteskip.gsc).
// Footage first (user): the map state is close to a run, not complete. Open: soul box fill, real start times and
// split starts, which ice part the route has.

#define QUOTESKIPWIND_GEN5_BOX  (-2138.38, -300.07, 176) // Panzerstart's Gen 5 soul box origin
#define QUOTESKIPWIND_LEFT      7 // zombies of the round still alive or to come when the Gen 5 box fills (user)

quoteskipwind_initialize()
{
    shared_start_time_add("release", "release", "release", "6:00", "7:30", 5, "6:35");
    mode_cfg_load("quoteskipwind", quoteskipwind_default_cfg());
    shared_segment_install(quoteskipwind_segment());
    shared_schedules_init(10);
    shared_held_start_install();
    level.segment.upgrade_mauser = false;
    level.shared_dig_zombie_blood = true;
    shared_quoteskip_sprint();
}

quoteskipwind_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_ICE;
    segment.round = 7;
    segment.round_kills = 0; // The whole round ahead (user): the box fills with QUOTESKIPWIND_LEFT zombies left
    segment.gems = [];
    segment.tank_trips = 0;
    segment.kill_plane = false;
    segment.box_rewards = false;
    segment.tablet = ::shared_tablet_dirty; // Picked up at the bunker, not cleaned yet
    segment.generators = ::shared_quoteskip_generators;
    segment.perks = array("specialty_longersprint");
    segment.score = 3000;
    segment.excluded_doors = array(CHURCH_BOX, CHURCH_STAIRS); // The church opens on round 7, after the wind part.
    segment.use_exit = false;
    segment.setup = ::quoteskipwind_setup;
    return segment;
}

quoteskipwind_setup()
{
    spot = shared_gen_spot("generator_nml_left");
    level.segment.spots = shared_start_spots(spot.origin, spot.angles, spot.origin, spot.angles);
    self shared_quoteskip_items();
    // One wind part per robot head: upper in Odin's, middle in Thor's, lower in Freya's
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "upper_staff");
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "middle_staff");
    // The Gen 5 box open and filling: it needs every kill of the round but the last QUOTESKIPWIND_LEFT (box 30 souls)
    souls = 30 - (practice_round_zombie_count(level.segment.round) - QUOTESKIPWIND_LEFT);
    if(souls < 1) souls = 1;
    if(souls > 29) souls = 29;
    self thread shared_prefill_soul_box(QUOTESKIPWIND_GEN5_BOX, souls);
    if(get_cfg_int("qs_hud")) self thread shared_story_vo_hud();
}

quoteskipwind_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_toggle(settings, "Story VO HUD", "qs_hud");
        add_cfg_toggle(settings, "Infinite Sprint", "qs_sprint");
        self shared_start_time_menu(settings);

    self shared_build_categories(root);
    self shared_build_segment_menus();
}

quoteskipwind_default_cfg()
{
    settings_ar = shared_quoteskip_defaults();
    settings_ar["cycle_4"] = ROBOT_FREYA; // Freya walks at 6:42
    settings_ar["foot_4"] = FOOT_LEFT;
    return settings_ar;
}
