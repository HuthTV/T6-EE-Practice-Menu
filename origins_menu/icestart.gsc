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
                              Icestart
##############################################################################*/
// Round 10 around the Ice staff, by Start Location (start_loc). Ice code start
// was its own mode until 2026-11-02 (user: one mode, more start locations).
//   Floor, Mule, STG: the Ice staff is about to be crafted. The game runs from
//     the black screen: the player can first view the Ice code (Peek Code), then
//     is moved to the start spot once the mound is open. Floor and Mule share one
//     Start Time, on the craft. STG has its own, and its dials keep the mound
//     opening's scramble (no shortcut, no Skip First Disc).
//   Ice code enter, Ice code exit: the Ice staff is crafted and in hand (see "Ice
//     code locations" below), a held start with its own Start Time each, the
//     clock starting in the Fire portal's teleport (enter: into the Crazy Place,
//     exit: out through the Fire exit).

// Teleport spots (origin, view angles).
#define ICE_PEEK_CODE_ORIGIN  (11251, -7418.49, -403.875)
#define ICE_PEEK_CODE_ANGLES  (342.943, 53.5034, 0)
#define ICE_FLOOR_ORIGIN      (-46.571, 172.697, -751.875)
#define ICE_FLOOR_ANGLES      (11.6608, 99.3494, 0)
#define ICE_MULE_ORIGIN       (-74.8256, -400.802, -493.875)
#define ICE_MULE_ANGLES       (13.8415, 315.165, 0)

// Start Location (start_loc).
// 0 was random (floor or mule) until 2026-11-02: it now loads as floor.
#define ICE_LOC_FLOOR       1
#define ICE_LOC_MULE        2
#define ICE_LOC_CODE_ENTER  3
#define ICE_LOC_CODE_EXIT   4
#define ICE_LOC_STG         5   // listed after mule

icestart_initialize()
{
    // Start Times, every 5 seconds. Craft (floor and mule): 12:30 to 14:30, 13:30
    // by default, Custom 12 to 20 minutes, STG the same for now. Ice code
    // locations, in the portal: 13:00 to 15:30, 14:00 by default. STG and the
    // code times are guesses: set them to the real ones.
    shared_start_time_add("craft", "craft", "Craft", "12:30", "14:30", 5, "13:30", 12, 20);
    shared_start_time_add("stg", "craft", "Craft", "12:30", "14:30", 5, "13:30", 12, 20);
    shared_start_time_add("code_enter", "portal", "Portal", "13:00", "15:30", 5, "14:00", 12, 20);
    shared_start_time_add("code_exit", "portal", "Portal", "13:00", "15:30", 5, "14:00", 12, 20);
    level.start_time_choices = ::icestart_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_ICE);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("icestart", icestart_default_cfg());
    // Crazy Place Walls (user, 2026-11-02): the Ice gem visit is behind, so
    // visits start at 2 (Ice code). Ice code exit is released inside visit 2 and
    // starts at 3 (Wind gem).
    if(get_cfg_int("start_loc") == ICE_LOC_CODE_EXIT) puzzle_rng_set_first_visit(3, true);
    else puzzle_rng_set_first_visit(2, false);

    if(icestart_code_location())
    {
        shared_segment_install(icestart_code_segment());
        // No staff is completed here, but the gramophone portal and the held-open
        // exit use the staff setup's hooks.
        no_staffs = [];
        shared_staff_install(no_staffs);
        shared_held_start_install();
        // Round 10's Templars are dealt with (user, 2026-11-02): Templar II comes
        // Templar II's gap after round 10 (13, 14 or 15).
        shared_schedule_advance(level.templar_schedule, 10);
        return;
    }

    flag_init("icestart_setup_done");
    flag_clear("icestart_setup_done");
    flag_init("icestart_ready"); // Set when setup is done and the player is released.
    flag_clear("icestart_ready");
    shared_segment_install(icestart_segment());
    shared_set_round(10, 1); // Install before native startup enters its callback.
}

icestart_code_location()
{
    location = get_cfg_int("start_loc");
    return location == ICE_LOC_CODE_ENTER || location == ICE_LOC_CODE_EXIT;
}

// level.start_time_choices: each code location has its own time, floor and mule share the craft's.
icestart_start_time_choices()
{
    switch(get_cfg_int("start_loc"))
    {
        case ICE_LOC_CODE_ENTER: return array("code_enter");
        case ICE_LOC_CODE_EXIT:  return array("code_exit");
        case ICE_LOC_STG:        return array("stg");
        default:                 return array("craft");
    }
}

icestart_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_ICE;
    segment.gems = array(ICE);
    shared_icestart_route(segment);
    segment.leave_gramophone = !get_cfg_int("early_gram");
    if(get_cfg_int("start_loc") == ICE_LOC_STG)
    {
        segment.disc_shortcut_gem = undefined;
        segment.discs_untouched = true;
    }

    // Icestart's own start (Peek Code) instead of the held start. The player is
    // held from the spawn, before the black screen ends, until setup is done.
    segment.on_spawn = ::icestart_hold_controls;
    segment.start = ::icestart_start;
    segment.setup = ::icestart_setup;
    return segment;
}

icestart_setup()
{
    self shared_get_parts();
}

// on_spawn: freezes the player every frame (the vanilla intro fade unfreezes
// them) until the start spot is reached and setup is done. Not with Peek Code,
// which freezes only while the timescale is 10.
icestart_hold_controls()
{
    self endon("disconnect");
    if(get_cfg_int("peek_code")) return;

    while(self.sessionstate != "playing") wait 0.05;
    while(!flag("icestart_ready"))
    {
        self freezecontrols(1);
        wait 0.05;
    }
}

icestart_run_setup()
{
    self [[ level.segment.setup ]]();
    flag_set("icestart_setup_done");
}

// start: the game runs from the black screen. Setup, the MP40 clue and the
// teleport (after Peek Code) happen while it does. The Ice craft starts the run
// clock at the selected start time (shared_start_clock). Ice has no Trio skip
// setting: every Ice craft time is before the round 12 trio cycle, so both
// columns give the same schedule.
icestart_start()
{
    setDvar("timescale", 1);
    if(get_cfg_int("cycle_tracker")) level thread shared_cycle_tracker();
    level thread icestart_auto_round_end();
    self shared_start_time_begin();
    self thread icestart_run_setup();
    self thread shared_mp40_tile_clue();
    self thread icestart_start_teleport();
    flag_wait("start_robots");
}

icestart_start_teleport()
{
    // OOPA off during the intro; in memory only, the saved setting is untouched.
    oopa_status = get_cfg_int("oopa");
    level.base_cfg["oopa"] = 0;
    self.ignoreme = 1;

    // Peek Code: view the Ice code in the Crazy Place, then fast-forward past
    // the mound opening. Otherwise teleport as soon as the mound is open.
    if(get_cfg_int("peek_code"))
    {
        self setorigin(ICE_PEEK_CODE_ORIGIN);
        self setplayerangles(ICE_PEEK_CODE_ANGLES);

        wait 5;
        self freezecontrols( 1 );
        setDvar("timescale", 10);
    }

    flag_wait( "chamber_entrance_opened" );
    if(get_cfg_int("peek_code"))
    {
        wait 15;
        setDvar("timescale", 1);
    }
    level.base_cfg["oopa"] = oopa_status;

    // Held until the setup has finished too, and only then moved (Peek Code is
    // the one start with an earlier move, to the code). A failsafe keeps a stuck
    // setup from freezing the player for good.
    setup_wait_start = gettime();
    while(!flag("icestart_setup_done") && gettime() - setup_wait_start < 60000) wait 0.05;

    // Start Location: floor, mule or STG (anything else, like the old random 0, is floor).
    switch(get_cfg_int("start_loc"))
    {
        case ICE_LOC_STG:
            // Floor's points and Mule Kick (a guess), the floor's view.
            self.score = 6500;
            self maps\mp\zombies\_zm_perks::give_perk("specialty_additionalprimaryweapon");
            self setorigin(STG_START_ORIGIN);
            self setplayerangles(ICE_FLOOR_ANGLES);
            break;
        case ICE_LOC_MULE:
            self.score = 11500;
            self setorigin(ICE_MULE_ORIGIN);
            self setplayerangles(ICE_MULE_ANGLES);
            break;
        default:
            self.score = 6500;
            self maps\mp\zombies\_zm_perks::give_perk("specialty_additionalprimaryweapon");
            self setorigin(ICE_FLOOR_ORIGIN);
            self setplayerangles(ICE_FLOOR_ANGLES);
            break;
    }

    // Normal speed for 500 ms before the player is released.
    setDvar("timescale", 1);
    wait 0.5;
    self.ignoreme = 0;
    flag_set("icestart_ready");
    self freezecontrols( 0 );
    self.kills = 205 + randomint( 26 );
}

icestart_auto_round_end()
{
    while(level.n_staffs_crafted < 1) wait 0.05;
    wait get_cfg_int("auto_round_end_delay");

    if(get_cfg_int("auto_round_end") && level.round_number == 10)
    {
        zombies = getaiarray("axis");
        if(isDefined(zombies))
        {
            for(i = 0; i < zombies.size; i++)
            {
                if(isDefined(zombies[i]))
                    zombies[i] dodamage(zombies[i].health + 666, zombies[i].origin);
            }
        }
    }
}

/*##############################################################################
                              Ice code locations
##############################################################################*/
// A little further on: the Ice staff is crafted and in hand, round 10 is under way
// with "Zombies killed" zombies already down, and the round's generator zombies
// are gone (every generator is captured, none under attack). The gramophone
// stands at the Fire tunnel with its portal open. The player starts in the tunnel
// looking into the portal (Ice code enter), or in the Crazy Place with the Ice
// code solved, about to leave through the open Fire exit (Ice code exit, always
// Fire: the route leaves that way, user 2026-11-02).

// Portal enter: in the Fire tunnel, in front of its portal (the old Ice code mode's
// spot). The view is turned to the portal at release.
#define ICECODE_TUNNEL_ORIGIN  (3048, 4408, -605)
// Portal exit: how far in front of the exit portal the player stands. The open
// portal takes anyone within 120 units of it (vanilla teleporter_radius_think).
#define ICECODE_EXIT_DISTANCE  180
#define ICECODE_KILLS_MAX    15

icestart_code_segment()
{
    segment = shared_segment();
    // The Ice split is behind: the run clock starts at release on the Start Time,
    // and the next split is the Wind craft.
    segment.split = SPLIT_WIND;
    segment.round = 10;
    segment.round_kills = icestart_code_kills();
    segment.use_exit = get_cfg_int("start_loc") == ICE_LOC_CODE_EXIT;
    // Every dial turned to Ice (user, 2026-11-02), the first left as scrambled with Skip First Disc.
    segment.last_disc_aligned = true;
    // A split at the portal, blue for Ice (user, 2026-11-02).
    segment.start_split_label = "^4CODE ENTER ^7";
    if(segment.use_exit) segment.start_split_label = "^4CODE EXIT ^7";
    // The Portal exit has been through the Fire portal: its crystal is up.
    segment.gems = array(ICE);
    if(segment.use_exit) segment.gems[segment.gems.size] = FIRE;

    // Doors, perks, tablet and parts as the floor start, plus Mule Kick.
    shared_icestart_route(segment);
    segment.perks[segment.perks.size] = "specialty_additionalprimaryweapon";
    segment.setup = ::icestart_code_setup;
    return segment;
}

// Zombies killed in round 10 so far, kept within 0 and ICECODE_KILLS_MAX.
icestart_code_kills()
{
    kills = get_cfg_int("icecode_kills");
    if(kills < 0) kills = 0;
    if(kills > ICECODE_KILLS_MAX) kills = ICECODE_KILLS_MAX;
    return kills;
}

icestart_code_setup()
{
    self shared_get_parts();
    shared_setup_trace("parts given, waiting chamber_entrance_opened");
    flag_wait("chamber_entrance_opened");
    // The gramophone goes to the Fire tunnel, which opens its portal, while the
    // staff is crafted (about 12 s of animation). Portal exit: the chosen Crazy
    // Place exit opens too and stays open until release (shared_run_chamber_exit).
    // Both are enabled already: the Fire one by its portal, the Ice one by the
    // Ice gem (shared_unlock_gem).
    self shared_portals_begin(FIRE, level.segment.use_exit, false, FIRE);

    staff = shared_staff_names(ICE);
    self shared_get_staff_pieces(ICE);
    shared_setup_trace("ice: craft");
    self shared_craft_staff(staff.craftable);
    shared_setup_trace("ice: take");
    self shared_take_staff(staff.craftable, staff.weapname);

    if(level.segment.use_exit)
        icestart_code_solve_tiles();
    else
        self thread shared_mp40_tile_clue();

    self shared_portals_wait();
    level.segment.spots = icestart_code_spots();
    self.kills = 205 + randomint(26) + icestart_code_kills();
}

// Crazy Place ceiling tiles all flipped back to the stone side, which completes
// the Ice code (native ceiling_tile_flip, as shared_ice_puzzles).
icestart_code_solve_tiles()
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
icestart_code_spots()
{
    pad = shared_teleport_pad(FIRE);
    view = vectortoangles(pad.origin - ICECODE_TUNNEL_ORIGIN);
    tunnel_angles = (0, view[1], 0);
    shared_setup_trace("tunnel spot " + ICECODE_TUNNEL_ORIGIN + ", " + distance(ICECODE_TUNNEL_ORIGIN, pad.origin) + " from the Fire portal");

    exit_origin = ICECODE_TUNNEL_ORIGIN;
    exit_angles = tunnel_angles;
    if(level.segment.use_exit)
    {
        element = FIRE;
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

/*##############################################################################
                              Menu
##############################################################################*/
icestart_build_menu(root)
{
    location = get_cfg_int("start_loc");
    code = location == ICE_LOC_CODE_ENTER || location == ICE_LOC_CODE_EXIT;
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        shared_add_location_choice(settings, "start_loc", array(ICE_LOC_FLOOR, ICE_LOC_MULE, ICE_LOC_STG, ICE_LOC_CODE_ENTER, ICE_LOC_CODE_EXIT), array("floor", "mule", "STG", "ice code enter", "ice code exit"));
        self shared_start_time_menu(settings);
        if(code)
        {
            create_option(settings, "Zombies killed: ^3" + icestart_code_kills() + " ^7(of " + practice_round_zombie_count(10) + ")", ::cfg_increment_int, "icecode_kills", array(0, ICECODE_KILLS_MAX));
            self shared_boomhilda_menu(settings);
        }
        // STG leaves the dials as the mound opening scrambled them.
        // The ice code locations have every dial turned (no Last Disc Turn).
        if(location != ICE_LOC_STG)
        {
            if(!code) shared_add_disc_turn_choice(settings);
            add_cfg_toggle(settings, "Skip First Disc", "skip_first_disc", "^2Yes", "^1No");
        }
        add_cfg_toggle(settings, "R2L Route", "r2l", "^2Yes", "^1No");
        if(!code) add_cfg_toggle(settings, "Early Gram", "early_gram", "^2yes", "^1no");
        // The tile clue is for the code still to do.
        if(location != ICE_LOC_CODE_EXIT) add_cfg_toggle(settings, "MP40 Tile Clue", "mp40_tile_clue", "^2Yes", "^1No");
        // Cycle 1 Foot picks the second bunker door: only R2L has a choice.
        if(get_cfg_int("r2l")) add_cfg_choice(settings, "Cycle 1 Foot", "trench_path", array("random", "gen2", "gen3"));
        if(!code)
        {
            add_cfg_toggle(settings, "Auto round end", "auto_round_end");
            create_option(settings, "Auto round end delay: ^3" + get_cfg_int("auto_round_end_delay") + "s", ::cfg_increment_int, "auto_round_end_delay", array(1, 10));
            add_cfg_toggle(settings, "Peek Code", "peek_code", "^2Yes", "^1No");
        }

    self shared_build_items_menu(root);
    self shared_build_segment_menus(root);
}

icestart_default_cfg()
{
    settings_ar = [];

    settings_ar["start_loc"] = ICE_LOC_FLOOR; // ICE_LOC_*
    settings_ar["peek_code"] = 0; // 1: view the Ice code before the mound opens. Off by default (user, 2026-10-25).
    settings_ar["icecode_kills"] = 0;                // Ice code locations: round 10 zombies killed so far (0 to ICECODE_KILLS_MAX).
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["dt_start"] = 0;
    settings_ar["trench_path"] = 0; // 0 random, 1 gen2, 2 gen3
    settings_ar["kill_plane"] = 1;
    settings_ar["plane_part"] = 1;
    settings_ar["r2l"] = 1;
    settings_ar["mp40_tile_clue"] = 1; // On by default (user, 2026-10-20).
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar["last_disc"] = 0;
    settings_ar["skip_first_disc"] = 0;
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;
    settings_ar["early_gram"] = 1;
    settings_ar["auto_round_end"] = 1; // On by default (user, 2026-10-25).
    settings_ar["auto_round_end_delay"] = 5;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, false);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_LEFT);
    settings_ar = shared_disc_defaults(settings_ar, 1);
    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
