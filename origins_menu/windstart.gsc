#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\puzzlerng;
#include scripts\zm\origins_menu\staffutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Windstart
##############################################################################*/
// Ice completed and placed with "Ice prefills" souls (0 by default); the player
// starts on round 11 or 12 carrying the Wind crystal, with Wind uncrafted.

// Start spots (origin, view angles). Craft: excavation floor, facing the Wind
// staff. Exit: the Wind Crazy Place exit.
#define WIND_CRAFT_ORIGIN  (-118.34, 157.932, -751.875)
#define WIND_CRAFT_ANGLES  (13.902, 129.183, 0)
#define WIND_EXIT_ORIGIN   (11234, -8687.25, -407.875)
#define WIND_EXIT_ANGLES   (0.0976524, 302.888, 0)
// A Panzer due on the start round (Panzer 2 a 4 rounder, round 12) is already
// out and waiting here when the player comes out of the portal, as in a run
// (user, 2026-10-20).
#define WIND_PANZER_SPOT   (1664, 873, 126)
#define WIND_ICE_SOULS_MAX 10   // "Ice prefills": souls already in the placed Ice staff.

windstart_initialize()
{
    // Craft time presets: 17:00 to 19:00, every 5 seconds, 18:20 by default.
    // Custom Craft: 16 to 24 minutes (Icestart + 4).
    shared_craft_time_setup("17:00", "19:00", 5, "18:20", 16, 24);
    puzzle_rng_install();
    mode_cfg_load("windstart", windstart_default_cfg());
    shared_segment_install(windstart_segment());
    shared_held_start_install();
}

windstart_run()
{
    level shared_run_segment(level.segment);
}

windstart_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_WIND;
    segment.round = get_cfg_int("wind_start_round");
    if(segment.round == 11) segment.round_zombies = 1;
    segment.staffs = array(ICE);
    segment.gems = array(ICE, FIRE, WIND);
    segment.spots = shared_start_spots(WIND_CRAFT_ORIGIN, WIND_CRAFT_ANGLES, WIND_EXIT_ORIGIN, WIND_EXIT_ANGLES);
    segment.use_exit = get_cfg_int("wind_spawn") == 1;
    segment.panzer_spot = WIND_PANZER_SPOT;
    segment.panzer_spot_wave = 2; // Only Panzer 2, and only when it is due on the start round.
    segment.setup = ::windstart_setup;

    return segment;
}

windstart_setup()
{
    self shared_staff_setup_start();
    souls = get_cfg_int("ice_souls");
    if(souls > WIND_ICE_SOULS_MAX) souls = WIND_ICE_SOULS_MAX;
    self shared_complete_staff(ICE, souls);
    self shared_get_staff_pieces(WIND);
    self shared_open_portals(WIND, level.segment.use_exit);
}

windstart_default_cfg()
{
	settings_ar = [];

	settings_ar["dt_start"] = 1;
    settings_ar["wind_start_round"] = 11;
    settings_ar["wind_spawn"] = 1;   // Start Location: 0 Craft, 1 Exit (default, user 2026-10-20).
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar["ice_souls"] = 0;  // "Ice prefills" (0 to WIND_ICE_SOULS_MAX).
    settings_ar["last_disc"] = 0; // Craft start disc turn: 0 random, 1 = 0 turns, 2 = 1 turn...
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

    for(scramble = 2; scramble <= 4; scramble++)
        settings_ar["disc_" + scramble] = 0;

    settings_ar["rain_foot"] = FOOT_LEFT;
    settings_ar["rain_robot"] = ROBOT_ODIN; // Rain Fire hatch robot (segment default).
    settings_ar["cycle_tracker_ms"] = 0;
    settings_ar["cycle_tracker"] = 1;

    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
