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
                              Firestart
##############################################################################*/
// Ice and Wind completed and placed, Ice with "Ice prefills" souls (0 by default)
// and Wind with none, Gen4 relay solved; the player starts on round 12 with 1
// zombie left, carrying the Fire crystal, with Fire uncrafted and the gramophone
// in hand (Craft) or at the Wind tunnel (Exit).

// Craft start spot: excavation floor, facing the Fire staff. The Exit start is
// the Wind Crazy Place exit: Firestart opens the Wind portal.
#define FIRE_CRAFT_ORIGIN  (118.633, 163.427, -751.875)
#define FIRE_CRAFT_ANGLES  (15.5005, 49.2187, 0)
#define FIRE_ICE_SOULS_MAX 10   // "Ice prefills": souls already in the placed Ice staff.
// Start Location (fire_spawn), listed Craft, STG, Exit.
#define FIRE_LOC_CRAFT  0
#define FIRE_LOC_EXIT   1
#define FIRE_LOC_STG    2

firestart_initialize()
{
    // Start Time on the Fire craft: 19:50 to 21:50, every 5 seconds, 21:25 by
    // default. Custom: 19 to 27 minutes (Windstart + 3). STG has its own, the
    // same range for now (a guess).
    shared_start_time_add("craft", "craft", "Craft", "19:50", "21:50", 5, "21:25", 19, 27);
    shared_start_time_add("stg", "craft", "Craft", "19:50", "21:50", 5, "21:25", 19, 27);
    level.start_time_choices = ::firestart_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_FIRE);
    mode_cfg_load("firestart", firestart_default_cfg());
    shared_segment_install(firestart_segment());
    shared_held_start_install();
}

// level.start_time_choices: STG has its own time.
firestart_start_time_choices()
{
    if(get_cfg_int("fire_spawn") == FIRE_LOC_STG) return array("stg");
    return array("craft");
}

firestart_segment()
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
    segment.spots = shared_start_spots(FIRE_CRAFT_ORIGIN, FIRE_CRAFT_ANGLES, EXIT_WIND_ORIGIN, EXIT_WIND_ANGLES);
    segment.use_exit = get_cfg_int("fire_spawn") == FIRE_LOC_EXIT;
    segment.solved_relays = array("relay_air"); // The route has the Gen4 Lightning relay solved from here on.
    segment.first_scramble = 3;
    if(!segment.use_exit) segment.disc_shortcut_gem = "crypt_gem_fire";
    if(get_cfg_int("fire_spawn") == FIRE_LOC_STG) shared_segment_stg(segment, FIRE_CRAFT_ANGLES);
    segment.drone_option = true;
    segment.setup = ::firestart_setup;

    return segment;
}

firestart_setup()
{
    self shared_staff_setup_start();
    // Craft start: the gramophone comes back to the excavation in hand once the
    // portal is open. The Exit start leaves it at the Wind tunnel portal.
    self shared_portals_begin(WIND, level.segment.use_exit, !level.segment.use_exit);
    souls = get_cfg_int("ice_souls");
    if(souls > FIRE_ICE_SOULS_MAX) souls = FIRE_ICE_SOULS_MAX;
    self shared_complete_staff(ICE, souls);
    self shared_complete_staff(WIND, 0);
    self shared_get_staff_pieces(FIRE);
    self shared_portals_wait();
}

firestart_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        shared_add_location_choice(settings, "fire_spawn", array(FIRE_LOC_CRAFT, FIRE_LOC_STG, FIRE_LOC_EXIT), array("Craft", "STG", "Exit"));
        self shared_start_time_menu(settings);
        add_cfg_toggle(settings, "Trio skip", "trioskip", "^2Yes", "^1No");
        shared_add_stg_choice(settings);
        self shared_boomhilda_menu(settings);
        create_option(settings, "Ice prefills: ^3" + get_cfg_int("ice_souls"), ::cfg_increment_int, "ice_souls", array(0, FIRE_ICE_SOULS_MAX));
        // Disc Turn is for the Craft start: Exit keeps the normal scramble, STG
        // leaves the dials as scrambled.
        if(get_cfg_int("fire_spawn") == FIRE_LOC_CRAFT) shared_add_disc_turn_choice(settings);
        if(get_cfg_int("fire_spawn") != FIRE_LOC_STG) add_cfg_toggle(settings, "Skip First Disc", "skip_first_disc", "^2Yes", "^1No");

    self shared_build_items_menu(root);
    self shared_build_segment_menus(root);
}

firestart_default_cfg()
{
    settings_ar = [];

    settings_ar["dt_start"] = 1;
    settings_ar["fire_spawn"] = FIRE_LOC_CRAFT; // Start Location (FIRE_LOC_*): Craft by default (user 2026-10-20).
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["ice_souls"] = 0;  // "Ice prefills" (0 to FIRE_ICE_SOULS_MAX).
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
