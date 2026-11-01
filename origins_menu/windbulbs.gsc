#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\staffutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Wind bulbs
##############################################################################*/
// Windstart, further on: Ice completed, the Wind staff crafted and in hand, the
// Crazy Place rings solved, and the overground smoke puzzle ahead, with each smoke
// already blown into place or not. The player starts outside the Wind portal, or
// comes running out of it (the old Wind Smoke Practice of
// various_origins_practice.gsc).

// Where the player waits, frozen, while the setup runs: the excavation floor.
#define BULBS_HOLD_ORIGIN  (-118.34, 157.932, -751.875)
#define BULBS_HOLD_ANGLES  (13.902, 129.183, 0)
// Outside the portal, by the mound.
#define BULBS_OUTSIDE_ORIGIN  (386, -912, 73)
#define BULBS_OUTSIDE_ANGLES  (0, 180, 0)
#define BULBS_SPAWN_OUTSIDE   0
#define BULBS_SPAWN_PORTAL    1

windbulbs_initialize()
{
    // Start time presets: 18:00 to 20:00, every 5 seconds, 19:00 by default. A
    // guess at when the smokes come in a run: set it to the real one.
    // Custom time: 16 to 26 minutes.
    shared_craft_time_setup("18:00", "20:00", 5, "19:00", 16, 26);
    mode_cfg_load("windbulbs", windbulbs_default_cfg());
    shared_segment_install(windbulbs_segment());
    shared_held_start_install();
}

windbulbs_run()
{
    level shared_run_segment(level.segment);
}

windbulbs_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_WIND;
    segment.round = get_cfg_int("bulbs_round");
    segment.round_zombies = windbulbs_zombies();
    segment.staffs = array(ICE);
    segment.gems = array(ICE, FIRE, WIND);
    segment.spots = shared_start_spots(BULBS_HOLD_ORIGIN, BULBS_HOLD_ANGLES, BULBS_HOLD_ORIGIN, BULBS_HOLD_ANGLES);
    segment.use_exit = false;
    segment.setup = ::windbulbs_setup;
    segment.place_player = ::windbulbs_place_player;
    return segment;
}

windbulbs_setup()
{
    self shared_staff_setup_start();
    self shared_portals_begin(WIND, false, false); // Opens while the rest of the setup runs.
    self shared_complete_staff(ICE, 0);

    // The Wind staff, crafted and taken the way shared_complete_staff does it.
    self shared_get_staff_pieces(WIND);
    staff = shared_staff_names(WIND);
    self shared_craft_staff(staff.craftable);
    self shared_take_staff(staff.craftable, staff.weapname);

    self windbulbs_solve_rings();
    self windbulbs_solve_smokes();
    self shared_portals_wait();
}

// Crazy Place: each ceiling ring one turn short of solved, turned with the native
// rotate, which also checks for completion (as shared_wind_puzzles).
windbulbs_solve_rings()
{
    while(!isDefined(level.a_ceiling_rings)) wait 0.05;
    foreach(ring in level.a_ceiling_rings)
    {
        ring.position = (ring.script_int + 3) % 4;
        ring thread maps\mp\zm_tomb_quest_air::ceiling_ring_rotate();
    }
    flag_wait("air_puzzle_1_complete");
}

// The smokes the settings call completed are blown to their destination through
// the native damage handler. Setting 1, 2 and 3 are structs 1, 2 and 0.
windbulbs_solve_smokes()
{
    destination = getstruct("puzzle_smoke_dest", "targetname");
    smokes = getstructarray("puzzle_smoke_origin", "targetname");
    order = array(1, 2, 0);
    for(setting = 1; setting <= 3; setting++)
    {
        if(!get_cfg_int("bulbs_smoke_" + setting)) continue;
        smoke = smokes[order[setting - 1]];
        while(!isDefined(smoke.e_fx) || !isDefined(smoke.solved)) wait 0.05;
        direction = vectornormalize(destination.origin - smoke.origin);
        smoke.detector_brush notify("damage", 1, self, direction, smoke.origin, "MOD_PROJECTILE", "", "", "", "staff_air_zm");
        wait 0.1;
    }
}

// Called by the held start when the setup is done, before the player is released.
windbulbs_place_player()
{
    if(get_cfg_int("bulbs_spawn") == BULBS_SPAWN_PORTAL)
        maps\mp\zm_tomb_teleporter::stargate_teleport_player("air_teleport_return", self);
    else
    {
        self setorigin(BULBS_OUTSIDE_ORIGIN);
        self setplayerangles(BULBS_OUTSIDE_ANGLES);
    }
}

// Most zombies the chosen round can have.
windbulbs_zombies_max()
{
    return practice_round_zombie_count(get_cfg_int("bulbs_round"));
}

// Zombies remaining, kept within 1 and the round's maximum.
windbulbs_zombies()
{
    zombies = get_cfg_int("bulbs_zombies");
    max = windbulbs_zombies_max();
    if(zombies > max) zombies = max;
    if(zombies < 1) zombies = 1;
    return zombies;
}

windbulbs_next_zombies()
{
    zombies = windbulbs_zombies() + 1;
    if(zombies > windbulbs_zombies_max()) zombies = 1;
    self cfg_set_int("bulbs_zombies", zombies);
}

/*##############################################################################
                              Menu
##############################################################################*/
windbulbs_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_choice(settings, "Start Location", "bulbs_spawn", array("Outside portal", "Out of portal"));
        create_option(settings, "Round: ^3" + get_cfg_int("bulbs_round"), ::cfg_increment_int, "bulbs_round", array(11, 12));
        create_option(settings, "Zombies: ^3" + windbulbs_zombies() + " ^7(" + windbulbs_zombies_max() + ")", ::windbulbs_next_zombies);
        add_cfg_choice(settings, "STG acquired", "stg_start", array("no", "yes", "papped"));
        add_cfg_toggle(settings, "Smoke 1", "bulbs_smoke_1", "^2completed", "^1incomplete");
        add_cfg_toggle(settings, "Smoke 2", "bulbs_smoke_2", "^2completed", "^1incomplete");
        add_cfg_toggle(settings, "Smoke 3", "bulbs_smoke_3", "^2completed", "^1incomplete");
        self shared_craft_time_menu(settings, "Start Time");
        add_cfg_toggle(settings, "Trio skip", "trioskip", "^2Yes", "^1No");

    self shared_build_panzer_menu(root);
    self shared_build_templar_menu(root);
    self shared_build_robot_menus(root, ::shared_segment_all_random_cycles, shared_robot_earliest_cycle());
}

windbulbs_default_cfg()
{
    settings_ar = [];

    settings_ar["bulbs_spawn"] = BULBS_SPAWN_PORTAL;
    settings_ar["bulbs_round"] = 12;
    settings_ar["bulbs_zombies"] = 20; // Zombies left in the round.
    settings_ar["bulbs_smoke_1"] = 0;
    settings_ar["bulbs_smoke_2"] = 0;
    settings_ar["bulbs_smoke_3"] = 0;
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar["trioskip"] = 0;
    settings_ar = shared_craft_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar["panzer_2"] = 0;
    settings_ar["panzer_3"] = 0;

    settings_ar["relay_start"] = 1;
    settings_ar["relay_tank"] = 1;
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
    settings_ar["rain_robot"] = ROBOT_ODIN;
    settings_ar["cycle_tracker_ms"] = 0;
    settings_ar["cycle_tracker"] = 1;
    return settings_ar;
}
