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
                              Post-Ice
##############################################################################*/
// The Ice staff is crafted and in hand, round 10 is under way with "Zombies killed"
// zombies already down, and the round's generator zombies are gone (every generator
// is captured, none under attack). The gramophone stands at the Fire tunnel with its
// portal open. By Start Location (start_loc): the player starts in the tunnel
// looking into the portal (Ice code enter), or in the Crazy Place with the Ice code
// solved, about to leave through the open Fire exit (Ice code exit, always Fire: the
// route leaves that way, user 2026-11-02). A held start with a Start Time for each,
// the clock starting in the Fire portal's teleport (enter: into the Crazy Place,
// exit: out through the Fire exit). Pre-Ice has the locations before the craft
// (split from Icestart, user 2026-11-04).

// Start Location (start_loc).
#define POSTICE_LOC_ENTER  0
#define POSTICE_LOC_EXIT   1

// Ice code enter: in the Fire tunnel, in front of its portal (the old Ice code
// mode's spot). The view is turned to the portal at release.
#define POSTICE_TUNNEL_ORIGIN  (3048, 4408, -605)
// Ice code exit: in front of the Fire exit portal (shared_chamber_exit_spots).
#define POSTICE_KILLS_MAX    15

postice_initialize()
{
    // Start Times, in the portal: 13:00 to 15:30, every 5 seconds, 14:00 by
    // default, Custom 12 to 20 minutes. Guesses: set them to the real ones.
    shared_start_time_add("code_enter", "portal", "Portal", "13:00", "15:30", 5, "14:00", 12, 20);
    shared_start_time_add("code_exit", "portal", "Portal", "13:00", "15:30", 5, "14:00", 12, 20);
    level.start_time_choices = ::postice_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_ICE);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("postice", postice_default_cfg());
    // Crazy Place Walls (user, 2026-11-02): the Ice gem visit is behind, so
    // visits start at 2 (Ice code). Ice code exit is released inside visit 2 and
    // starts at 3 (Wind gem).
    if(get_cfg_int("start_loc") == POSTICE_LOC_EXIT) puzzle_rng_set_first_visit(3, true);
    else puzzle_rng_set_first_visit(2, false);

    shared_segment_install(postice_segment());
    // No staff is completed here, but the gramophone portal and the held-open
    // exit use the staff setup's hooks.
    no_staffs = [];
    shared_staff_install(no_staffs);
    shared_held_start_install();
    // Round 10's Templars are dealt with (user, 2026-11-02): Templar II comes
    // Templar II's gap after round 10 (13, 14 or 15).
    shared_schedule_advance(level.templar_schedule, 10);
}

// level.start_time_choices: each location has its own time.
postice_start_time_choices()
{
    if(get_cfg_int("start_loc") == POSTICE_LOC_EXIT) return array("code_exit");
    return array("code_enter");
}

postice_segment()
{
    segment = shared_segment();
    // The Ice split is behind: the run clock starts in the portal on the Start
    // Time, and the next split is the Wind craft.
    segment.split = SPLIT_WIND;
    segment.round = 10;
    segment.round_kills = postice_kills();
    segment.use_exit = get_cfg_int("start_loc") == POSTICE_LOC_EXIT;
    // Every dial turned to Ice (user, 2026-11-02), the first left as scrambled with Skip First Disc.
    segment.last_disc_aligned = true;
    // A split at the portal, blue for Ice (user, 2026-11-02).
    segment.start_split_label = "^4CODE ENTER ^7";
    if(segment.use_exit) segment.start_split_label = "^4CODE EXIT ^7";
    // Ice code exit has been through the Fire portal: its crystal is up.
    segment.gems = array(ICE);
    if(segment.use_exit) segment.gems[segment.gems.size] = FIRE;

    // Doors, perks, tablet and parts as the Pre-Ice floor, plus Mule Kick.
    shared_ice_route(segment);
    segment.perks[segment.perks.size] = "specialty_additionalprimaryweapon";
    segment.setup = ::postice_setup;
    return segment;
}

// Zombies killed in round 10 so far, kept within 0 and POSTICE_KILLS_MAX.
postice_kills()
{
    kills = get_cfg_int("icecode_kills");
    if(kills < 0) kills = 0;
    if(kills > POSTICE_KILLS_MAX) kills = POSTICE_KILLS_MAX;
    return kills;
}

postice_setup()
{
    self shared_get_parts();
    shared_setup_trace("parts given, waiting chamber_entrance_opened");
    flag_wait("chamber_entrance_opened");
    // The gramophone goes to the Fire tunnel, which opens its portal, while the
    // staff is crafted (about 12 s of animation). Ice code exit: the chosen Crazy
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
        postice_solve_tiles();
    else
        self thread shared_mp40_tile_clue();

    self shared_portals_wait();
    level.segment.spots = postice_spots();
    self.kills = 205 + randomint(26) + postice_kills();
}

// Crazy Place ceiling tiles all flipped back to the stone side, which completes
// the Ice code (native ceiling_tile_flip, as shared_ice_puzzles).
postice_solve_tiles()
{
    while(!isDefined(level.unsolved_tiles)) wait 0.05;
    tiles = arraycopy(level.unsolved_tiles);
    foreach(tile in tiles) tile thread maps\mp\zm_tomb_quest_ice::ceiling_tile_flip(0);
    flag_wait("ice_puzzle_1_complete");
    shared_setup_trace("ice code solved");
}

// The held start's two spots, found once the portals are open (the portal
// structs only have their positions by then). Craft: the Fire tunnel, facing the
// portal. Exit: in front of the open exit, on the ground, facing it. Neither has been checked in game: the console shows where they are.
postice_spots()
{
    pad = shared_teleport_pad(FIRE);
    view = vectortoangles(pad.origin - POSTICE_TUNNEL_ORIGIN);
    tunnel_angles = (0, view[1], 0);
    shared_setup_trace("tunnel spot " + POSTICE_TUNNEL_ORIGIN + ", " + distance(POSTICE_TUNNEL_ORIGIN, pad.origin) + " from the Fire portal");

    exit_origin = POSTICE_TUNNEL_ORIGIN;
    exit_angles = tunnel_angles;
    if(level.segment.use_exit)
    {
        exit_spots = shared_chamber_exit_spots(FIRE);
        exit_origin = exit_spots.exit_origin;
        exit_angles = exit_spots.exit_angles;
    }
    return shared_start_spots(POSTICE_TUNNEL_ORIGIN, tunnel_angles, exit_origin, exit_angles);
}

/*##############################################################################
                              Menu
##############################################################################*/
postice_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Start", level.mode.label);
        shared_add_location_choice(settings, "start_loc", array(POSTICE_LOC_ENTER, POSTICE_LOC_EXIT), array("ice code enter", "ice code exit"));
        self shared_start_time_menu(settings);
        create_option(settings, "Zombies killed: ^3" + postice_kills() + " ^7(of " + practice_round_zombie_count(10) + ")", ::cfg_increment_int, "icecode_kills", array(0, POSTICE_KILLS_MAX));
        add_cfg_toggle(settings, "R2L Route", "r2l");
        // Cycle 1 Foot picks the second bunker door: only R2L has a choice.
        if(get_cfg_int("r2l")) add_cfg_choice(settings, "Cycle 1 Foot", "trench_path", array("random", "gen2", "gen3"));

    self shared_build_categories(root);
    self shared_boomhilda_menu("loadout");
    self shared_add_item_rows("loadout");
    // The exit start has the code done: only the code still to do has rows.
    code_ahead = get_cfg_int("start_loc") != POSTICE_LOC_EXIT;
    level.puzzle_rng_solved["ice"] = !code_ahead;
    self shared_build_segment_menus(false, true);
    if(code_ahead) add_cfg_toggle("ice_code", "MP40 Tile Clue", "mp40_tile_clue");
}

postice_default_cfg()
{
    settings_ar = [];

    settings_ar["start_loc"] = POSTICE_LOC_ENTER; // POSTICE_LOC_*
    settings_ar["icecode_kills"] = 0;                // Round 10 zombies killed so far (0 to POSTICE_KILLS_MAX).
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["dt_start"] = 0;
    settings_ar["trench_path"] = 0; // 0 random, 1 gen2, 2 gen3
    settings_ar["kill_plane"] = 1;
    settings_ar["plane_part"] = 1;
    settings_ar["r2l"] = 1;
    settings_ar["mp40_tile_clue"] = 1; // On by default (user, 2026-10-20).
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar["skip_first_disc"] = 0;
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, false);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_LEFT);
    settings_ar = shared_disc_defaults(settings_ar, 1);
    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
