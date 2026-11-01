#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

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

// Start spots (origin, view angles). Craft: excavation floor, facing the Fire
// staff. Exit: Firestart opens the Wind portal, so the Wind Crazy Place exit.
#define FIRE_CRAFT_ORIGIN  (118.633, 163.427, -751.875)
#define FIRE_CRAFT_ANGLES  (15.5005, 49.2187, 0)
#define FIRE_EXIT_ORIGIN   (11234, -8687.25, -407.875)
#define FIRE_EXIT_ANGLES   (0.0976524, 302.888, 0)
#define FIRE_ICE_SOULS_MAX 10   // "Ice prefills": souls already in the placed Ice staff.

firestart_initialize()
{
    // Craft time presets: 19:50 to 21:50, every 5 seconds, 21:25 by default.
    // Custom Craft: 19 to 27 minutes (Windstart + 3).
    shared_craft_time_setup("19:50", "21:50", 5, "21:25", 19, 27);
    puzzle_rng_install();
    mode_cfg_load("firestart", firestart_default_cfg());
    shared_segment_install(firestart_segment());
    shared_held_start_install();
}

firestart_run()
{
    level shared_run_segment(level.segment);
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
    segment.spots = shared_start_spots(FIRE_CRAFT_ORIGIN, FIRE_CRAFT_ANGLES, FIRE_EXIT_ORIGIN, FIRE_EXIT_ANGLES);
    segment.use_exit = get_cfg_int("fire_spawn") == 1;
    segment.solved_relays = array("relay_air"); // The route has the Gen4 Lightning relay solved from here on.
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

firestart_default_cfg()
{
	settings_ar = [];

	settings_ar["dt_start"] = 1;
    settings_ar["fire_spawn"] = 0;   // Start Location: 0 Craft (default, user 2026-10-20), 1 Exit.
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar["ice_souls"] = 0;  // "Ice prefills" (0 to FIRE_ICE_SOULS_MAX).
    settings_ar["skip_first_disc"] = 0;
    settings_ar["last_disc"] = 0; // Craft start disc turn: 0 random, 1 = 0 turns, 2 = 1 turn...
    settings_ar["trioskip"] = 0; // 1: non-standard "No trios" robot timing.
    settings_ar = shared_craft_time_defaults(settings_ar);
	settings_ar = shared_part_defaults(settings_ar);
	settings_ar = shared_segment_item_defaults(settings_ar);
	settings_ar["headshot_reward"] = 0;

	settings_ar["panzer_2"] = 0;
	settings_ar["panzer_3"] = 0;

	settings_ar["relay_start"] = 1;
	settings_ar["relay_tank"] = 1; // Gen2 electrical relay: solved tank_platform orientation.
	settings_ar["relay_air"] = 0;
	settings_ar["relay_elec"] = 1;
	settings_ar["relay_ruins"] = 1;
	settings_ar["relay_ice"] = 0;
	settings_ar["relay_village"] = 1;

	settings_ar = shared_templar_defaults(settings_ar);

	// Robot cycles and feet
	for(cycle = 1; cycle <= ROBOT_CYCLE_COUNT; cycle++)
	{
		settings_ar["cycle_" + cycle] = ROBOT_RANDOM;
		settings_ar["foot_" + cycle] = FOOT_RANDOM;
	}

    for(scramble = 3; scramble <= 4; scramble++)
        settings_ar["disc_" + scramble] = 0;

    settings_ar["rain_foot"] = FOOT_LEFT;
    settings_ar["rain_robot"] = ROBOT_ODIN; // Rain Fire hatch robot (segment default).
    settings_ar["cycle_tracker_ms"] = 0;
    settings_ar["cycle_tracker"] = 1;

    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
