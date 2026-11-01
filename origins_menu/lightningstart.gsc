#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\staffutil;
#include scripts\zm\origins_menu\puzzlerng;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Lightningstart
##############################################################################*/
// Ice and Wind completed and filled with souls, Fire completed with zero souls,
// every Lightning piece collected and the gramophone at the Lightning portal;
// the player starts on round 14 carrying the Lightning crystal, with Lightning
// uncrafted, every Lightning relay solved, and the chosen number of zombies left
// in the round. The tank finishes its setup trips at the church.

// Start spots (origin, view angles). Craft: excavation floor, facing the
// Lightning staff. Exit: the Lightning Crazy Place exit.
#define LIGHTNING_CRAFT_ORIGIN  (50.0612, 199.082, -751.875)
#define LIGHTNING_CRAFT_ANGLES  (11.5839, 79.2444, 0)
#define LIGHTNING_EXIT_ORIGIN   (9633.01, -6973.31, -345.875)
#define LIGHTNING_EXIT_ANGLES   (359.462, 139.132, 0)

lightningstart_initialize()
{
    // Craft time presets: 24:10 to 26:10, every 5 seconds, 25:10 by default.
    // Custom Craft: 23 to 31 minutes (Firestart + 4).
    shared_craft_time_setup("24:10", "26:10", 5, "25:10", 23, 31);
    puzzle_rng_install();
    mode_cfg_load("lightningstart", lightningstart_default_cfg());
    shared_segment_install(lightningstart_segment());
    shared_held_start_install();
}

lightningstart_run()
{
    level shared_run_segment(level.segment);
}

lightningstart_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_LIGHTNING;
    segment.round = 14;
    zombies = get_cfg_int("lightning_zombies"); // 0: the full round
    if(zombies > 0) segment.round_zombies = zombies;
    segment.staffs = array(ICE, WIND, FIRE);
    segment.gems = array(ICE, FIRE, WIND, LIGHTNING);
    segment.spots = shared_start_spots(LIGHTNING_CRAFT_ORIGIN, LIGHTNING_CRAFT_ANGLES, LIGHTNING_EXIT_ORIGIN, LIGHTNING_EXIT_ANGLES);
    segment.use_exit = get_cfg_int("lightning_spawn") == 1;
    // Every Lightning relay is solved by this point of the route.
    segment.solved_relays = array("relay_start", "relay_tank", "relay_air", "relay_elec", "relay_ruins", "relay_ice", "relay_village");
    segment.setup = ::lightningstart_setup;
    return segment;
}

lightningstart_setup()
{
    self shared_staff_setup_start();
    self shared_portals_begin(LIGHTNING, level.segment.use_exit, false);
    self shared_complete_staff(ICE, 20);
    self shared_complete_staff(WIND, 20);
    self shared_complete_staff(FIRE, 0);
    self shared_get_staff_pieces(LIGHTNING);
    self shared_portals_wait();
}

lightningstart_default_cfg()
{
	settings_ar = [];

	settings_ar["dt_start"] = 1;
    settings_ar["lightning_spawn"] = 1;   // Start Location: 0 Craft, 1 Exit (default, user 2026-10-20).
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar["lightning_zombies"] = 0; // Zombies left in round 14; 0 the full round.
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

    settings_ar["disc_4"] = 0;

    settings_ar["rain_foot"] = FOOT_LEFT;
    settings_ar["rain_robot"] = ROBOT_ODIN; // Rain Fire hatch robot (segment default).
    settings_ar["cycle_tracker_ms"] = 0;
    settings_ar["cycle_tracker"] = 1;

    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
