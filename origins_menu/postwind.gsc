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
                              Post-Wind
##############################################################################*/
// Ice completed, the Wind staff crafted and in hand, the Crazy Place rings solved,
// and the overground smoke puzzle ahead, with each smoke already blown into place
// or not. By Start Location (wind_spawn): the player starts at the mound, or comes
// running out of the Wind portal (portal enter). The old Wind Smoke Practice of
// various_origins_practice.gsc. Wind is behind, so the next split is Fire. Pre-Wind
// has the locations before the craft (split from Windstart, user 2026-11-04).

// The player waits, frozen, on the Wind Craft spot while the setup runs. The
// mound start, outside the portal:
#define BULBS_MOUND_ORIGIN  (386, -912, 73)
#define BULBS_MOUND_ANGLES  (0, 180, 0)

// Start Location (wind_spawn).
#define POSTWIND_LOC_MOUND  0
#define POSTWIND_LOC_ENTER  1

postwind_initialize()
{
    // Start Times, every 5 seconds: 18:00 to 20:00, 19:00 by default (guesses at
    // when the smokes come in a run), Custom 16 to 26 minutes. Mound starts at the
    // spawn (release), portal enter in the Wind portal's teleport (user, 2026-11-02).
    shared_start_time_add("bulbs_mound", "release", "Spawn", "18:00", "20:00", 5, "19:00", 16, 26);
    shared_start_time_add("bulbs_enter", "portal", "Portal", "18:00", "20:00", 5, "19:00", 16, 26);
    level.start_time_choices = ::postwind_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_WIND);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("postwind", postwind_default_cfg());
    // Crazy Place Walls: every location starts at visit 4, Wind puzzle (user,
    // 2026-11-02).
    puzzle_rng_set_first_visit(4, false);
    shared_segment_install(postwind_segment());
    shared_held_start_install();
}

// level.start_time_choices: each location has its own time.
postwind_start_time_choices()
{
    if(get_cfg_int("wind_spawn") == POSTWIND_LOC_ENTER) return array("bulbs_enter");
    return array("bulbs_mound");
}

postwind_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_FIRE;
    segment.round = get_cfg_int("bulbs_round");
    segment.round_zombies_keys = array("bulbs_round", "bulbs_zombies"); // Counted once the player is in.
    // One setup trip, parked at the bunkers as Pre-Wind. Wind Bulbs used the
    // default 2 (back to the church) until 2026-11-02.
    segment.tank_trips = 1;
    segment.staffs = array(ICE);
    segment.gems = array(ICE, FIRE, WIND);
    segment.spots = shared_start_spots(CRAFT_WIND_ORIGIN, CRAFT_WIND_ANGLES, EXIT_WIND_ORIGIN, EXIT_WIND_ANGLES);
    segment.use_exit = false;
    segment.setup = ::postwind_setup;
    // Portal enter: the clock waits for the teleport place_player runs.
    segment.start_time_before_place = get_cfg_int("wind_spawn") == POSTWIND_LOC_ENTER;
    segment.place_player = ::postwind_place_player;
    return segment;
}

postwind_setup()
{
    self shared_staff_setup_start();
    self shared_portals_begin(WIND, level.segment.use_exit, false); // Opens while the rest of the setup runs.
    self shared_complete_staff(ICE, 0);

    // The Wind staff, crafted and taken the way shared_complete_staff does it.
    self shared_get_staff_pieces(WIND);
    staff = shared_staff_names(WIND);
    self shared_craft_staff(staff.craftable);
    self shared_take_staff(staff.craftable, staff.weapname);

    self postwind_solve_rings();
    self postwind_solve_smokes();
    self postwind_align_discs();
    self shared_portals_wait();
}

// The crypt discs are turned to the Wind gem, whichever start location, as they
// stand when the Wind orb is ready to go up. The orb scramble of the Ice staff has
// long finished, and the lights are refreshed at the release (shared_refresh_disc_lights).
postwind_align_discs()
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
postwind_solve_rings()
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
postwind_solve_smokes()
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
postwind_place_player()
{
    switch(get_cfg_int("wind_spawn"))
    {
        case POSTWIND_LOC_ENTER:
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
postwind_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Start", level.mode.label);
        shared_add_location_choice(settings, "wind_spawn", array(POSTWIND_LOC_MOUND, POSTWIND_LOC_ENTER), array("mound bulbs", "portal enter"));
        self shared_start_time_menu(settings);
        create_option(settings, "Round: ^3" + get_cfg_int("bulbs_round"), ::cfg_increment_int, "bulbs_round", array(11, 12));
        shared_add_round_zombies_option(settings, "bulbs_round", "bulbs_zombies");

    self shared_build_categories(root);
    shared_add_stg_choice("loadout");
    self shared_boomhilda_menu("loadout");

    // Setup solves the rings, so Wind Rings holds only the smokes here.
    level.puzzle_rng_solved["wind"] = true;
    wind = add_submenu("puzzles", "wind_rings", "Wind Rings");
        add_cfg_toggle(wind, "Smoke 1", "bulbs_smoke_1", "^2completed", "^1incomplete");
        add_cfg_toggle(wind, "Smoke 2", "bulbs_smoke_2", "^2completed", "^1incomplete");
        add_cfg_toggle(wind, "Smoke 3", "bulbs_smoke_3", "^2completed", "^1incomplete");
    self puzzle_rng_build_menus("puzzles");

    add_cfg_toggle("special_ai", "Trio skip", "trioskip");
    self shared_build_ai_menus();
}

postwind_default_cfg()
{
    settings_ar = [];

    settings_ar["wind_spawn"] = POSTWIND_LOC_MOUND; // Start Location (POSTWIND_LOC_*).
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["bulbs_round"] = 12;
    settings_ar["bulbs_zombies"] = 20; // Zombies left in the round.
    settings_ar["bulbs_smoke_1"] = 1; // The first smoke done by default (user, 2026-11-02).
    settings_ar["bulbs_smoke_2"] = 0;
    settings_ar["bulbs_smoke_3"] = 0;
    settings_ar["trioskip"] = 0; // 1: non-standard "No trios" robot timing.
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
