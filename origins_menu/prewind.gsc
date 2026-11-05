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
                              Pre-Wind
##############################################################################*/
// Ice completed and placed with "Ice prefills" souls (0 by default). The player
// starts on round 11 or 12 carrying the Wind crystal, with Wind uncrafted, by Start
// Location (wind_spawn). Windstart was split in two on 2026-11-04 (user): the
// locations after the craft are Post-Wind.
//   Craft faces the Wind staff, Exit is in the Crazy Place at the Wind exit, STG is
//   STG_START_ORIGIN with the dials as scrambled. Craft and STG start the clock on
//   the craft, each with its own Start Time. Exit offers "Clock starts": on leaving
//   through the exit, or on the craft (the same Start Time as the Craft location).

// A Panzer due on the start round (Panzer 2 a 4 rounder, round 12) is already
// out and waiting here when the player comes out of the portal, as in a run
// (user, 2026-10-20).
#define WIND_PANZER_SPOT   (1664, 873, 126)

// Start Location (wind_spawn).
#define PREWIND_LOC_CRAFT  0
#define PREWIND_LOC_STG    1
#define PREWIND_LOC_EXIT   2

prewind_initialize()
{
    // Start Times, every 5 seconds. Craft: 17:00 to 19:00, 18:20 by default,
    // Custom 16 to 24 minutes (Pre-Ice + 4). Exit, on leaving the Crazy Place:
    // the same range, 17:40 by default (a guess). Set the guesses to a run's times.
    shared_start_time_add("craft", "craft", "Craft", "17:00", "19:00", 5, "18:20", 16, 24);
    shared_start_time_add("stg", "craft", "Craft", "17:00", "19:00", 5, "18:20", 16, 24); // STG: a guess
    shared_start_time_add("exit", "exit", "Exit", "17:00", "19:00", 5, "17:40", 16, 24);
    level.start_time_choices = ::prewind_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_WIND);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("prewind", prewind_default_cfg());
    // Crazy Place Walls: every location starts at visit 4, Wind puzzle (user,
    // 2026-11-02). Exit releases the player inside the
    // Crazy Place, a stay that counts as visit 3.
    puzzle_rng_set_first_visit(4, get_cfg_int("wind_spawn") == PREWIND_LOC_EXIT);
    shared_segment_install(prewind_segment());
    shared_held_start_install();
}

// level.start_time_choices: the Exit location picks exit or craft.
prewind_start_time_choices()
{
    switch(get_cfg_int("wind_spawn"))
    {
        case PREWIND_LOC_EXIT: return array("exit", "craft");
        case PREWIND_LOC_STG:  return array("stg");
        default:               return array("craft");
    }
}

prewind_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_WIND;
    segment.round = get_cfg_int("wind_start_round");
    if(segment.round == 11) segment.round_zombies = 1;
    segment.tank_trips = 1; // One setup trip (church to bunkers), parked at the bunker (user, 2026-11-02).
    segment.staffs = array(ICE);
    segment.gems = array(ICE, FIRE, WIND);
    segment.spots = shared_start_spots(CRAFT_WIND_ORIGIN, CRAFT_WIND_ANGLES, EXIT_WIND_ORIGIN, EXIT_WIND_ANGLES);
    segment.use_exit = get_cfg_int("wind_spawn") == PREWIND_LOC_EXIT;
    segment.panzer_spot = WIND_PANZER_SPOT;
    segment.panzer_spot_wave = 2; // Only Panzer 2, and only when it is due on the start round.
    segment.early_teleport = segment.round == 12; // Round 12 may have the Panzer waiting.
    segment.first_scramble = 2;
    if(!segment.use_exit) segment.disc_shortcut_gem = "crypt_gem_air";
    if(get_cfg_int("wind_spawn") == PREWIND_LOC_STG) shared_segment_stg(segment, CRAFT_WIND_ANGLES);
    segment.drone_option = true;
    segment.setup = ::prewind_setup;

    return segment;
}

prewind_setup()
{
    self shared_staff_setup_start();
    self shared_portals_begin(WIND, level.segment.use_exit, false);
    souls = get_cfg_int("ice_souls");
    if(souls > ICE_SOULS_MAX) souls = ICE_SOULS_MAX;
    self shared_complete_staff(ICE, souls);
    self shared_get_staff_pieces(WIND);
    self shared_portals_wait();
}

/*##############################################################################
                              Menu
##############################################################################*/
prewind_build_menu(root)
{
    location = get_cfg_int("wind_spawn");
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        shared_add_location_choice(settings, "wind_spawn", array(PREWIND_LOC_CRAFT, PREWIND_LOC_STG, PREWIND_LOC_EXIT), array("Craft", "STG", "Exit"));
        self shared_start_time_menu(settings);
        // No Trio skip: Craft, STG and Exit always use the round 12 trio.
        shared_add_stg_choice(settings);
        self shared_boomhilda_menu(settings);
        // Disc Turn is for the Craft start: Exit keeps the normal scramble, STG
        // leaves the dials as scrambled.
        if(location == PREWIND_LOC_CRAFT) shared_add_disc_turn_choice(settings);
        if(location != PREWIND_LOC_STG) add_cfg_toggle(settings, "Skip First Disc", "skip_first_disc", "^2Yes", "^1No");
        create_option(settings, "Start Round: ^3" + get_cfg_int("wind_start_round"), ::cfg_increment_int, "wind_start_round", array(11, 12));
        create_option(settings, "Ice prefills: ^3" + get_cfg_int("ice_souls"), ::cfg_increment_int, "ice_souls", array(0, ICE_SOULS_MAX));

    self shared_build_items_menu(root);
    self shared_build_segment_menus(root);
}

prewind_default_cfg()
{
    settings_ar = [];

    settings_ar["wind_spawn"] = PREWIND_LOC_EXIT; // Start Location (PREWIND_LOC_*): Exit by default (user 2026-10-20).
    settings_ar["dt_start"] = 1;
    settings_ar["wind_start_round"] = 11;
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["ice_souls"] = 0;  // "Ice prefills" (0 to ICE_SOULS_MAX).
    settings_ar["skip_first_disc"] = 0;
    settings_ar["last_disc"] = 0; // Craft start disc turn: 0 random, 1 = 0 turns, 2 = 1 turn...
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, true);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_LEFT);
    settings_ar = shared_disc_defaults(settings_ar, 2);
    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
