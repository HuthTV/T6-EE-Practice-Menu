#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\staffutil;
#include scripts\zm\origins_menu\puzzlerng;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Ice code start
##############################################################################*/
// Icestart, a little further on: the Ice staff is crafted and in hand, round 10 is
// under way with "Zombies killed" zombies already down, and the round's generator
// zombies are gone (every generator is captured, none under attack). The
// gramophone stands at the Fire tunnel with its portal open. The player starts
// in the tunnel looking into the portal (Portal enter), or in the Crazy Place with
// the Ice code solved, about to leave through an open exit (Portal exit). Built on
// Icestart's settings, minus the ones for the time before the craft.

// Portal enter: in the Fire tunnel, in front of its portal (the old Ice code mode's
// spot). The view is turned to the portal at release.
#define ICECODE_TUNNEL_ORIGIN  (3048, 4408, -605)
// Portal exit: how far in front of the exit portal the player stands. The open
// portal takes anyone within 120 units of it (vanilla teleporter_radius_think).
#define ICECODE_EXIT_DISTANCE  180
#define ICECODE_SPAWN_ENTER  0
#define ICECODE_SPAWN_EXIT   1
#define ICECODE_EXIT_FIRE    0
#define ICECODE_EXIT_ICE     1
#define ICECODE_KILLS_MAX    15

icecodestart_initialize()
{
    // Start time presets: 13:00 to 15:30, every 5 seconds, 14:00 by default. A
    // guess at the run clock at the Fire tunnel: set it to the real one.
    // Custom time: 12 to 20 minutes (as Icestart).
    shared_craft_time_setup("13:00", "15:30", 5, "14:00", 12, 20);
    puzzle_rng_install();
    mode_cfg_load("icecodestart", icecodestart_default_cfg());
    shared_segment_install(icecodestart_segment());
    // No staff is completed here, but the gramophone portal and the held-open
    // exit use the staff setup's hooks.
    no_staffs = [];
    shared_staff_install(no_staffs);
    shared_held_start_install();
}

icecodestart_run()
{
    level shared_run_segment(level.segment);
}

icecodestart_segment()
{
    segment = shared_segment();
    // The Ice split is behind: the run clock starts at release on the Start Time,
    // and the next split is the Wind craft.
    segment.split = SPLIT_WIND;
    segment.clock_at_release = true;
    segment.round = 10;
    segment.round_kills = icecodestart_kills();
    segment.use_exit = get_cfg_int("icecode_spawn") == ICECODE_SPAWN_EXIT;
    // The Portal exit has been through the Fire portal: its crystal is up.
    segment.gems = array(ICE);
    if(segment.use_exit) segment.gems[segment.gems.size] = FIRE;

    // Doors, as Icestart. R2L: the Gen 3 spawn door is open, the Gen 2 spawn door
    // closed, and Cycle 1 Foot (trench_path: 1 Gen 2, 2 Gen 3, 0 random) picks
    // which second door is open. Otherwise both Gen 3 doors are closed.
    if(get_cfg_int("r2l"))
    {
        trench_path = get_cfg_int("trench_path");
        if(trench_path == 0) trench_path = 1 + cointoss();
        segment.excluded_doors = array(SPAWN_GEN2);
        if(trench_path == 1) segment.excluded_doors[segment.excluded_doors.size] = GEN3;
        else                 segment.excluded_doors[segment.excluded_doors.size] = GEN2;
    }
    else
        segment.excluded_doors = array(GEN3, SPAWN_GEN3);
    segment.wallbuy_ak = get_cfg_int("r2l");
    segment.tank_trips = 2 - get_cfg_int("r2l");

    segment.points_spent_claimed = false;
    segment.perks = array("specialty_longersprint");
    if(get_cfg_int("dt_start")) segment.perks[segment.perks.size] = "specialty_rof";
    segment.perks[segment.perks.size] = "specialty_armorvest";
    segment.perks[segment.perks.size] = "specialty_additionalprimaryweapon";
    segment.kill_plane = get_cfg_int("kill_plane");
    segment.tablet = ::icecodestart_tablet;
    segment.setup = ::icecodestart_setup;
    return segment;
}

// Zombies killed in round 10 so far, kept within 0 and ICECODE_KILLS_MAX.
icecodestart_kills()
{
    kills = get_cfg_int("icecode_kills");
    if(kills < 0) kills = 0;
    if(kills > ICECODE_KILLS_MAX) kills = ICECODE_KILLS_MAX;
    return kills;
}

icecodestart_setup()
{
    self shared_get_parts();
    shared_setup_trace("parts given, waiting chamber_entrance_opened");
    flag_wait("chamber_entrance_opened");
    // The portals open while the staff is crafted (about 12 s of animation).
    flag_clear("segment_portals_open");
    self thread icecodestart_open_portals();

    staff = shared_staff_names(ICE);
    self shared_get_staff_pieces(ICE);
    shared_setup_trace("ice: craft");
    self shared_craft_staff(staff.craftable);
    shared_setup_trace("ice: take");
    self shared_take_staff(staff.craftable, staff.weapname);

    if(level.segment.use_exit)
        icecodestart_solve_tiles();
    else
        self thread icecodestart_mp40_index();

    flag_wait("segment_portals_open");
    level.segment.spots = icecodestart_spots();
    self.kills = 205 + randomint(26) + icecodestart_kills();
}

// The gramophone goes to the Fire tunnel, which opens its portal. Portal exit:
// the chosen Crazy Place exit opens too and stays open until release
// (shared_run_chamber_exit). Both are enabled already: the Fire one by its
// portal, the Ice one by the Ice gem (shared_unlock_gem).
icecodestart_open_portals()
{
    if(level.segment.use_exit) self thread shared_open_exit_portal(icecodestart_exit_element());
    shared_setup_trace("gramophone portal fire");
    self shared_open_gramophone_portal(FIRE);
    if(level.segment.use_exit) flag_wait("segment_exit_open");
    shared_setup_trace("portals open");
    flag_set("segment_portals_open");
}

icecodestart_exit_element()
{
    if(get_cfg_int("icecode_exit") == ICECODE_EXIT_ICE) return ICE;
    return FIRE;
}

// Crazy Place ceiling tiles all flipped back to the stone side, which completes
// the Ice code (native ceiling_tile_flip, as shared_ice_puzzles).
icecodestart_solve_tiles()
{
    while(!isDefined(level.unsolved_tiles)) wait 0.05;
    tiles = arraycopy(level.unsolved_tiles);
    foreach(tile in tiles) tile thread maps\mp\zm_tomb_quest_ice::ceiling_tile_flip(0);
    flag_wait("ice_puzzle_1_complete");
    shared_setup_trace("ice code solved");
}

// The held start's two spots, found once the portals are open (the portal
// structs only have their positions by then). Craft: the Fire tunnel, facing the
// portal. Exit: ICECODE_EXIT_DISTANCE in front of the open exit, on the ground,
// facing it. Neither has been checked in game: the console shows where they are.
icecodestart_spots()
{
    pad = undefined;
    foreach(candidate in getstructarray("trigger_teleport_pad", "targetname"))
        if(candidate.script_int == FIRE) pad = candidate;
    view = vectortoangles(pad.origin - ICECODE_TUNNEL_ORIGIN);
    tunnel_angles = (0, view[1], 0);
    shared_setup_trace("tunnel spot " + ICECODE_TUNNEL_ORIGIN + ", " + distance(ICECODE_TUNNEL_ORIGIN, pad.origin) + " from the Fire portal");

    exit_origin = ICECODE_TUNNEL_ORIGIN;
    exit_angles = tunnel_angles;
    if(level.segment.use_exit)
    {
        element = icecodestart_exit_element();
        portal = level.a_teleport_exits[element].origin;
        // The use trigger stands in front of the portal: go further out that way.
        trigger = level.a_teleport_exit_triggers[element].origin;
        direction = vectornormalize((trigger[0] - portal[0], trigger[1] - portal[1], 0));
        spot = portal + direction * ICECODE_EXIT_DISTANCE;
        exit_origin = groundpos((spot[0], spot[1], trigger[2] + 30));
        view = vectortoangles(portal - spot);
        exit_angles = (0, view[1], 0);
        shared_setup_trace("exit spot " + exit_origin + " angles " + exit_angles);
    }
    return shared_start_spots(ICECODE_TUNNEL_ORIGIN, tunnel_angles, exit_origin, exit_angles);
}

// MP40 Tile Clue (Portal enter): the MP40 clip's last digit is the place, counted
// from the low x side, of the tile the Ice gem shows first.
icecodestart_mp40_index()
{
    self endon("disconnect");
    self endon("death");
    level endon("ice_puzzle_1_complete");

    if(!get_cfg_int("mp40_tile_clue")) return;

    // The gem starts at -1; wait for the quest to select a tile.
    answer = undefined;
    while(!isdefined(answer) || !self hasweapon("mp40_zm"))
    {
        tiles = getentarray("ice_ceiling_tile", "script_noteworthy");
        gem = getent("ice_chamber_gem", "targetname");
        answer = undefined;
        if(isdefined(gem) && isdefined(gem.value) && gem.value >= 0)
        {
            foreach(tile in tiles)
                if(isdefined(tile.value) && tile.value == gem.value) answer = tile;
        }
        if(!isdefined(answer) || !self hasweapon("mp40_zm")) wait 0.05;
    }

    index = 1;
    foreach(tile in tiles) if(tile.origin[0] < answer.origin[0]) index++;

    ammo = self getweaponammoclip("mp40_zm");
    ammo = ammo - ammo % 10 + index;
    if(ammo > weaponclipsize("mp40_zm")) ammo -= 10;
    self setweaponammoclip("mp40_zm", ammo);
}

// tablet: as Icestart, picked up at the bunker and carried.
icecodestart_tablet()
{
    while(!isDefined(level.n_tablets_remaining) || !isDefined(self.sq_one_inch_punch_stage)) wait 0.05;
    self.sq_one_inch_punch_stage++;
    self.sq_one_inch_punch_tablet_num = level.n_tablets_remaining;
    self setclientfieldtoplayer( "player_tablet_state", 2 );
    self thread maps\mp\zm_tomb_ee_side::sq_one_inch_punch_disconnect_watch();
    self thread maps\mp\zm_tomb_ee_side::sq_one_inch_punch_death_watch();
    m_tablet = getent( "tablet_bunker_" + level.n_tablets_remaining, "targetname" );
    m_tablet delete();
    level.n_tablets_remaining--;

    self setclientfieldtoplayer( "player_tablet_state", 1 );
    self.sq_one_inch_punch_stage = 4;
    self thread maps\mp\zm_tomb_ee_side::tablet_cleanliness_thread();
}

/*##############################################################################
                              Menu
##############################################################################*/
icecodestart_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_choice(settings, "Start Location", "icecode_spawn", array("Portal enter", "Portal exit"));
        if(get_cfg_int("icecode_spawn") == ICECODE_SPAWN_EXIT) add_cfg_choice(settings, "Exit", "icecode_exit", array("Fire", "Ice"));
        create_option(settings, "Zombies killed: ^3" + icecodestart_kills() + " ^7(of " + practice_round_zombie_count(10) + ")", ::cfg_increment_int, "icecode_kills", array(0, ICECODE_KILLS_MAX));
        self shared_craft_time_menu(settings, "Start Time");
        add_cfg_choice(settings, "Ice Disc Turn", "last_disc", array("random", "0 turn", "1 turn", "2 turn", "3 turn"));
        add_cfg_toggle(settings, "Skip First Disc", "skip_first_disc", "^2Yes", "^1No");
        add_cfg_toggle(settings, "R2L Route", "r2l", "^2Yes", "^1No");
        // The tile clue is for the code still to do.
        if(get_cfg_int("icecode_spawn") == ICECODE_SPAWN_ENTER) add_cfg_toggle(settings, "MP40 Tile Clue", "mp40_tile_clue", "^2Yes", "^1No");
        // Cycle 1 Foot picks the second bunker door; only R2L has a choice.
        if(get_cfg_int("r2l")) add_cfg_choice(settings, "Cycle 1 Foot", "trench_path", array("random", "gen2", "gen3"));

    items = add_submenu(root, "items", "Items settings", "Items");
        add_cfg_toggle(items, "Plane Shot", "kill_plane");
        create_option(items, "Plane Part: " + cfgint_compare("plane_part", "^2collected", "^1disperse"), ::shared_plane_part_toggle);
        add_cfg_toggle(items, "Fizz DT", "dt_start");
        add_cfg_toggle(items, "115 Reward", "headshot_reward");

    self shared_build_parts_menu(root);
    self shared_build_vinyls_menu(root);
    self shared_build_disc_menu(root);

    relays = add_submenu(root, "relays", "Electric Relays", "Relays");
        shared_add_relay_row(relays, "Spawn", "relay_start");
        shared_add_relay_row(relays, "Gen2", "relay_tank");
        shared_add_relay_row(relays, "Gen4", "relay_air");
        shared_add_relay_row(relays, "Gen5", "relay_elec");
        shared_add_relay_row(relays, "Middle", "relay_ruins");
        shared_add_relay_row(relays, "Bot Church", "relay_ice");
        shared_add_relay_row(relays, "Top Church", "relay_village");

    self shared_build_templar_menu(root);
    self shared_build_panzer_menu(root);
    self shared_build_robot_menus(root, ::shared_segment_all_random_cycles, shared_robot_earliest_cycle());
    self puzzle_rng_build_root_menu(root);
}

icecodestart_default_cfg()
{
    settings_ar = [];

    settings_ar["icecode_spawn"] = ICECODE_SPAWN_ENTER; // Start Location: Portal enter or Portal exit.
    settings_ar["icecode_exit"] = ICECODE_EXIT_FIRE;    // Portal exit: the Fire exit (route, user 2026-11-01) or the Ice exit.
    settings_ar["icecode_kills"] = 0;                   // Round 10 zombies killed so far (0 to ICECODE_KILLS_MAX).
    settings_ar = shared_craft_time_defaults(settings_ar); // Start Time.
    settings_ar["dt_start"] = 0;
    settings_ar["trench_path"] = 0; // 0 random, 1 gen2, 2 gen3
    settings_ar["kill_plane"] = 1;
    settings_ar["plane_part"] = 1;
    settings_ar["r2l"] = 1;
    settings_ar["mp40_tile_clue"] = 1;
    settings_ar["last_disc"] = 0;
    settings_ar["skip_first_disc"] = 0;
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar["panzer_2"] = 0;
    settings_ar["panzer_3"] = 0;

    settings_ar["relay_start"] = 1;
    settings_ar["relay_tank"] = 0;
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

    for(scramble = 1; scramble <= 4; scramble++)
        settings_ar["disc_" + scramble] = 0;

    settings_ar["rain_foot"] = FOOT_LEFT;
    settings_ar["rain_robot"] = ROBOT_ODIN; // Rain Fire hatch robot (segment default).
    settings_ar["cycle_tracker_ms"] = 0;
    settings_ar["cycle_tracker"] = 1;

    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
