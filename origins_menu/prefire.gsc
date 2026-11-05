#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\puzzlerng;
#include scripts\zm\origins_menu\staffutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Pre-Fire
##############################################################################*/
// Ice and Wind completed and placed, Ice with "Ice prefills" souls (0 by default)
// and Wind with none, Gen4 relay solved. The player starts on round 12 with 1
// zombie left, carrying the Fire crystal, with Fire uncrafted and the gramophone
// in hand (Craft) or at the Wind tunnel (Exit). Firestart was split in two on
// 2026-11-04 (user): the locations after the craft are Post-Fire.

// Craft start spot: CRAFT_FIRE_*. The Exit start is the Wind Crazy Place exit:
// Pre-Fire opens the Wind portal.
// Start Location (fire_spawn).
#define PREFIRE_LOC_CRAFT  0
#define PREFIRE_LOC_STG    1
#define PREFIRE_LOC_EXIT   2

prefire_initialize()
{
    // Start Time on the Fire craft: 19:50 to 21:50, every 5 seconds, 21:25 by
    // default. Custom: 19 to 27 minutes (Pre-Wind + 3). STG has its own, the
    // same range for now (a guess).
    shared_start_time_add("craft", "craft", "Craft", "19:50", "21:50", 5, "21:25", 19, 27);
    shared_start_time_add("stg", "craft", "Craft", "19:50", "21:50", 5, "21:25", 19, 27);
    level.start_time_choices = ::prefire_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_FIRE);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("prefire", prefire_default_cfg());
    // Crazy Place Walls: visits 1 to 5 are behind (the Fire gem).
    puzzle_rng_set_first_visit(6, false);
    shared_segment_install(prefire_segment());
    shared_held_start_install();
}

// level.start_time_choices: STG has its own time.
prefire_start_time_choices()
{
    if(get_cfg_int("fire_spawn") == PREFIRE_LOC_STG) return array("stg");
    return array("craft");
}

prefire_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_FIRE;
    // Round 12 with 1 zombie left (user, 2026-10-20). shared_set_round counts
    // anything planned for round 12 as done: a 4 rounder Panzer 2 never comes,
    // and Panzer 3 (its setting, or random) counts from 12: 16 or 17. A 5
    // rounder Panzer 2 comes on 13.
    segment.round = 12;
    segment.round_zombies = 1;
    segment.tank_trips = 1; // One setup trip (church to bunkers), not two (user, 2026-10-20).
    segment.staffs = array(ICE, WIND);
    segment.gems = array(ICE, FIRE, WIND);
    segment.spots = shared_start_spots(CRAFT_FIRE_ORIGIN, CRAFT_FIRE_ANGLES, EXIT_WIND_ORIGIN, EXIT_WIND_ANGLES);
    segment.use_exit = get_cfg_int("fire_spawn") == PREFIRE_LOC_EXIT;
    segment.solved_relays = array("relay_air"); // The route has the Gen4 Lightning relay solved from here on.
    segment.first_scramble = 3;
    if(!segment.use_exit) segment.disc_shortcut_gem = "crypt_gem_fire";
    if(get_cfg_int("fire_spawn") == PREFIRE_LOC_STG) shared_segment_stg(segment, CRAFT_FIRE_ANGLES);
    segment.drone_option = true;
    segment.setup = ::prefire_setup;

    return segment;
}

prefire_setup()
{
    self shared_staff_setup_start();
    // Craft start: the gramophone comes back to the excavation in hand once the
    // portal is open. The Exit start leaves it at the Wind tunnel portal.
    self shared_portals_begin(WIND, level.segment.use_exit, !level.segment.use_exit);
    souls = get_cfg_int("ice_souls");
    if(souls > ICE_SOULS_MAX) souls = ICE_SOULS_MAX;
    self shared_complete_staff(ICE, souls);
    self shared_complete_staff(WIND, 0);
    self shared_get_staff_pieces(FIRE);
    self shared_portals_wait();
}

prefire_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        shared_add_location_choice(settings, "fire_spawn", array(PREFIRE_LOC_CRAFT, PREFIRE_LOC_STG, PREFIRE_LOC_EXIT), array("Craft", "STG", "Exit"));
        self shared_start_time_menu(settings);
        add_cfg_toggle(settings, "Trio skip", "trioskip", "^2Yes", "^1No");
        shared_add_stg_choice(settings);
        self shared_boomhilda_menu(settings);
        create_option(settings, "Ice prefills: ^3" + get_cfg_int("ice_souls"), ::cfg_increment_int, "ice_souls", array(0, ICE_SOULS_MAX));
        // Disc Turn is for the Craft start: Exit keeps the normal scramble, STG
        // leaves the dials as scrambled.
        if(get_cfg_int("fire_spawn") == PREFIRE_LOC_CRAFT) shared_add_disc_turn_choice(settings);
        if(get_cfg_int("fire_spawn") != PREFIRE_LOC_STG) add_cfg_toggle(settings, "Skip First Disc", "skip_first_disc", "^2Yes", "^1No");

    self shared_build_items_menu(root);
    self shared_build_segment_menus(root);
}

prefire_default_cfg()
{
    settings_ar = [];

    settings_ar["dt_start"] = 1;
    settings_ar["fire_spawn"] = PREFIRE_LOC_CRAFT; // Start Location (PREFIRE_LOC_*): Craft by default (user 2026-10-20).
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["ice_souls"] = 0;  // "Ice prefills" (0 to ICE_SOULS_MAX).
    settings_ar["skip_first_disc"] = 0;
    settings_ar["last_disc"] = 0; // Craft start disc turn: 0 random, 1 = 0 turns, 2 = 1 turn...
    settings_ar["trioskip"] = 0; // 1: non-standard "No trios" robot timing.
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, true);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_LEFT);
    settings_ar = shared_disc_defaults(settings_ar, 3);
    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
