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
                              Windstart
##############################################################################*/
// Ice completed and placed, by Start Location (wind_spawn). Wind Bulbs was its own
// mode until 2026-11-02 (user: one mode, more start locations, each with its own
// Start Time).
//   Craft, STG, Exit: Ice has "Ice prefills" souls (0 by default); the player starts on
//     round 11 or 12 carrying the Wind crystal, with Wind uncrafted. Craft faces
//     the Wind staff, Exit is in the Crazy Place at the Wind exit, STG is
//     STG_START_ORIGIN with the dials as scrambled. Craft and STG start the clock
//     on the craft, each with its own Start Time. Exit offers "Clock starts": on leaving through the exit,
//     or on the craft (the same Start Time as the Craft location).
//   Bulbs: mound, portal enter: Wind is crafted and in hand, the
//     overground smoke puzzle ahead (see "Wind bulbs locations" below). The
//     clock starts at release.

// A Panzer due on the start round (Panzer 2 a 4 rounder, round 12) is already
// out and waiting here when the player comes out of the portal, as in a run
// (user, 2026-10-20).
#define WIND_PANZER_SPOT   (1664, 873, 126)
#define WIND_ICE_SOULS_MAX 10   // "Ice prefills": souls already in the placed Ice staff.

// Start Location (wind_spawn).
#define WIND_LOC_CRAFT        0
#define WIND_LOC_EXIT         1
#define WIND_LOC_BULBS_MOUND  2
#define WIND_LOC_BULBS_ENTER  3
// 4 was bulbs: exit portal, the same start as Exit (user, 2026-11-02): it now loads as Craft.
#define WIND_LOC_STG          5   // listed after Craft

windstart_initialize()
{
    // Start Times, every 5 seconds. Craft: 17:00 to 19:00, 18:20 by default,
    // Custom 16 to 24 minutes (Icestart + 4). Exit, on leaving the Crazy Place:
    // the same range, 17:40 by default (a guess). Bulbs, at release: 18:00 to
    // 20:00, 19:00 by default (guesses at when the smokes come in a run), Custom
    // 16 to 26 minutes. Set the guesses to a run's times.
    shared_start_time_add("craft", "craft", "Craft", "17:00", "19:00", 5, "18:20", 16, 24);
    shared_start_time_add("stg", "craft", "Craft", "17:00", "19:00", 5, "18:20", 16, 24); // STG: a guess
    shared_start_time_add("exit", "exit", "Exit", "17:00", "19:00", 5, "17:40", 16, 24);
    // Bulbs mound starts at the spawn (release), portal enter in the Wind portal's
    // teleport (user, 2026-11-02).
    shared_start_time_add("bulbs_mound", "release", "Spawn", "18:00", "20:00", 5, "19:00", 16, 26);
    shared_start_time_add("bulbs_enter", "portal", "Portal", "18:00", "20:00", 5, "19:00", 16, 26);
    level.start_time_choices = ::windstart_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_WIND);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("windstart", windstart_default_cfg());
    // Crazy Place Walls: every location starts at visit 4, Wind puzzle (user,
    // 2026-11-02). Exit releases the player inside the
    // Crazy Place, a stay that counts as visit 3.
    location = get_cfg_int("wind_spawn");
    puzzle_rng_set_first_visit(4, location == WIND_LOC_EXIT);
    if(windstart_bulbs_location()) shared_segment_install(windstart_bulbs_segment());
    else shared_segment_install(windstart_segment());
    shared_held_start_install();
}

windstart_bulbs_location()
{
    location = get_cfg_int("wind_spawn");
    return location == WIND_LOC_BULBS_MOUND || location == WIND_LOC_BULBS_ENTER;
}

// level.start_time_choices: the Exit location picks exit or craft.
windstart_start_time_choices()
{
    switch(get_cfg_int("wind_spawn"))
    {
        case WIND_LOC_EXIT:        return array("exit", "craft");
        case WIND_LOC_STG:         return array("stg");
        case WIND_LOC_BULBS_MOUND: return array("bulbs_mound");
        case WIND_LOC_BULBS_ENTER: return array("bulbs_enter");
        default:                   return array("craft");
    }
}

windstart_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_WIND;
    segment.round = get_cfg_int("wind_start_round");
    if(segment.round == 11) segment.round_zombies = 1;
    segment.tank_trips = 1; // One setup trip (church to bunkers), parked at the bunker (user, 2026-11-02).
    segment.staffs = array(ICE);
    segment.gems = array(ICE, FIRE, WIND);
    segment.spots = shared_start_spots(CRAFT_WIND_ORIGIN, CRAFT_WIND_ANGLES, EXIT_WIND_ORIGIN, EXIT_WIND_ANGLES);
    segment.use_exit = get_cfg_int("wind_spawn") == WIND_LOC_EXIT;
    segment.panzer_spot = WIND_PANZER_SPOT;
    segment.panzer_spot_wave = 2; // Only Panzer 2, and only when it is due on the start round.
    segment.early_teleport = segment.round == 12; // Round 12 may have the Panzer waiting.
    segment.first_scramble = 2;
    if(!segment.use_exit) segment.disc_shortcut_gem = "crypt_gem_air";
    if(get_cfg_int("wind_spawn") == WIND_LOC_STG) shared_segment_stg(segment, CRAFT_WIND_ANGLES);
    segment.drone_option = true;
    segment.setup = ::windstart_setup;

    return segment;
}

windstart_setup()
{
    self shared_staff_setup_start();
    self shared_portals_begin(WIND, level.segment.use_exit, false);
    souls = get_cfg_int("ice_souls");
    if(souls > WIND_ICE_SOULS_MAX) souls = WIND_ICE_SOULS_MAX;
    self shared_complete_staff(ICE, souls);
    self shared_get_staff_pieces(WIND);
    self shared_portals_wait();
}

/*##############################################################################
                              Wind bulbs locations
##############################################################################*/
// Further on: Ice completed, the Wind staff crafted and in hand, the Crazy Place
// rings solved, and the overground smoke puzzle ahead, with each smoke already
// blown into place or not. The player starts at the mound, comes running out of
// the Wind portal (portal enter). The old Wind Smoke Practice of
// various_origins_practice.gsc. Wind is behind, so the next split is Fire.

// The player waits, frozen, on the Wind Craft spot while the setup runs. The
// mound start, outside the portal:
#define BULBS_MOUND_ORIGIN  (386, -912, 73)
#define BULBS_MOUND_ANGLES  (0, 180, 0)

windstart_bulbs_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_FIRE;
    segment.round = get_cfg_int("bulbs_round");
    segment.round_zombies_keys = array("bulbs_round", "bulbs_zombies"); // Counted once the player is in.
    // One setup trip, parked at the bunkers as the other Windstart locations. Wind
    // Bulbs used the default 2 (back to the church) until 2026-11-02.
    segment.tank_trips = 1;
    segment.staffs = array(ICE);
    segment.gems = array(ICE, FIRE, WIND);
    segment.spots = shared_start_spots(CRAFT_WIND_ORIGIN, CRAFT_WIND_ANGLES, EXIT_WIND_ORIGIN, EXIT_WIND_ANGLES);
    segment.use_exit = false;
    segment.setup = ::windstart_bulbs_setup;
    // Portal enter: the clock waits for the teleport place_player runs.
    segment.start_time_before_place = get_cfg_int("wind_spawn") == WIND_LOC_BULBS_ENTER;
    segment.place_player = ::windstart_bulbs_place_player;
    return segment;
}

windstart_bulbs_setup()
{
    self shared_staff_setup_start();
    self shared_portals_begin(WIND, level.segment.use_exit, false); // Opens while the rest of the setup runs.
    self shared_complete_staff(ICE, 0);

    // The Wind staff, crafted and taken the way shared_complete_staff does it.
    self shared_get_staff_pieces(WIND);
    staff = shared_staff_names(WIND);
    self shared_craft_staff(staff.craftable);
    self shared_take_staff(staff.craftable, staff.weapname);

    self windstart_bulbs_solve_rings();
    self windstart_bulbs_solve_smokes();
    self windstart_bulbs_align_discs();
    self shared_portals_wait();
}

// The crypt discs are turned to the Wind gem, whichever start location, as they
// stand when the Wind orb is ready to go up. The orb scramble of the Ice staff has
// long finished, and the lights are refreshed at the release (shared_refresh_disc_lights).
windstart_bulbs_align_discs()
{
    flag_waitopen("disc_rotation_active");
    position = maps\mp\zm_tomb_quest_crypt::chamber_disc_get_gem_position("crypt_gem_air");
    discs = getentarray("crypt_puzzle_disc", "script_noteworthy");
    foreach(disc in discs)
        if(disc.targetname != "crypt_puzzle_disc_main") disc.position = position;
    shared_set_discs_silent(discs);
    level notify("crypt_disc_rotation");
}

// Crazy Place: each ceiling ring one turn short of solved, turned with the native
// rotate, which also checks for completion (as shared_wind_puzzles).
windstart_bulbs_solve_rings()
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
windstart_bulbs_solve_smokes()
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
windstart_bulbs_place_player()
{
    switch(get_cfg_int("wind_spawn"))
    {
        case WIND_LOC_BULBS_ENTER:
            maps\mp\zm_tomb_teleporter::stargate_teleport_player("air_teleport_return", self);
            break;
        default:
            self setorigin(BULBS_MOUND_ORIGIN);
            self setplayerangles(BULBS_MOUND_ANGLES);
            break;
    }
}

/*##############################################################################
                              Menu
##############################################################################*/
windstart_build_menu(root)
{
    location = get_cfg_int("wind_spawn");
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        shared_add_location_choice(settings, "wind_spawn", array(WIND_LOC_CRAFT, WIND_LOC_STG, WIND_LOC_EXIT, WIND_LOC_BULBS_MOUND, WIND_LOC_BULBS_ENTER), array("Craft", "STG", "Exit", "mound bulbs", "bulbs: portal enter"));
        self shared_start_time_menu(settings);
        if(windstart_bulbs_location())
        {
            create_option(settings, "Round: ^3" + get_cfg_int("bulbs_round"), ::cfg_increment_int, "bulbs_round", array(11, 12));
            shared_add_round_zombies_option(settings, "bulbs_round", "bulbs_zombies");
            shared_add_stg_choice(settings);
            self shared_boomhilda_menu(settings);
            add_cfg_toggle(settings, "Smoke 1", "bulbs_smoke_1", "^2completed", "^1incomplete");
            add_cfg_toggle(settings, "Smoke 2", "bulbs_smoke_2", "^2completed", "^1incomplete");
            add_cfg_toggle(settings, "Smoke 3", "bulbs_smoke_3", "^2completed", "^1incomplete");
            add_cfg_toggle(settings, "Trio skip", "trioskip", "^2Yes", "^1No");

            self shared_build_panzer_menu(root);
            self shared_build_templar_menu(root);
            self shared_build_robot_menus(root, ::shared_segment_all_random_cycles, shared_robot_earliest_cycle());
            self puzzle_rng_build_root_menu(root);
            return;
        }
        // No Trio skip: Craft, STG and Exit always use the round 12 trio.
        shared_add_stg_choice(settings);
        self shared_boomhilda_menu(settings);
        // Disc Turn is for the Craft start: Exit keeps the normal scramble, STG
        // leaves the dials as scrambled.
        if(location == WIND_LOC_CRAFT) shared_add_disc_turn_choice(settings);
        if(location != WIND_LOC_STG) add_cfg_toggle(settings, "Skip First Disc", "skip_first_disc", "^2Yes", "^1No");
        create_option(settings, "Start Round: ^3" + get_cfg_int("wind_start_round"), ::cfg_increment_int, "wind_start_round", array(11, 12));
        create_option(settings, "Ice prefills: ^3" + get_cfg_int("ice_souls"), ::cfg_increment_int, "ice_souls", array(0, WIND_ICE_SOULS_MAX));

    self shared_build_items_menu(root);
    self shared_build_segment_menus(root);
}

windstart_default_cfg()
{
    settings_ar = [];

    settings_ar["wind_spawn"] = WIND_LOC_EXIT; // Start Location (WIND_LOC_*): Exit by default (user 2026-10-20).
    settings_ar["dt_start"] = 1;
    settings_ar["wind_start_round"] = 11;
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["ice_souls"] = 0;  // "Ice prefills" (0 to WIND_ICE_SOULS_MAX).
    settings_ar["skip_first_disc"] = 0;
    settings_ar["last_disc"] = 0; // Craft start disc turn: 0 random, 1 = 0 turns, 2 = 1 turn...
    settings_ar["bulbs_round"] = 12;
    settings_ar["bulbs_zombies"] = 20; // Bulbs: zombies left in the round.
    settings_ar["bulbs_smoke_1"] = 1; // Bulbs: the first smoke done by default (user, 2026-11-02).
    settings_ar["bulbs_smoke_2"] = 0;
    settings_ar["bulbs_smoke_3"] = 0;
    settings_ar["trioskip"] = 0; // Bulbs only.
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
