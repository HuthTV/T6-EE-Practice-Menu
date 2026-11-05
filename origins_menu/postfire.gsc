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
                              Post-Fire
##############################################################################*/
// Ice and Wind completed and placed, Ice with "Ice prefills" souls (0 by default)
// and Wind with none, Gen4 relay solved, the player on round 12 with 1 zombie left,
// the Fire staff crafted and in hand, the gramophone at the Lightning portal (open).
// By Start Location (fire_spawn, user 2026-11-04): fire kills enter, in the Lightning
// tunnel about to go in for the Crazy Place kills, and torches, in the Crazy Place
// with the kills done, about to leave through the Ice exit (open) for the church
// torches. Pre-Fire has the locations before the craft (split from Firestart, user
// 2026-11-04).

// Start Location (fire_spawn).
#define POSTFIRE_LOC_KILLS    0
#define POSTFIRE_LOC_TORCHES  1

postfire_initialize()
{
    // Fire kills enter in the Lightning portal's teleport, torches on leaving
    // the Crazy Place. Custom: 19 to 27 minutes. Guesses: set them to the real ones.
    shared_start_time_add("kills", "portal", "Portal", "20:30", "22:30", 5, "21:50", 19, 27);
    shared_start_time_add("torches", "exit", "Exit", "21:30", "23:30", 5, "22:40", 19, 27);
    level.start_time_choices = ::postfire_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_FIRE);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("postfire", postfire_default_cfg());
    // Crazy Place Walls: visits 1 to 5 are behind (the Fire gem). Torches is
    // released inside visit 6 (Fire kills) and starts at 7.
    if(get_cfg_int("fire_spawn") == POSTFIRE_LOC_TORCHES) puzzle_rng_set_first_visit(7, true);
    else puzzle_rng_set_first_visit(6, false);
    shared_segment_install(postfire_segment());
    shared_held_start_install();
}

// level.start_time_choices: each location has its own time.
postfire_start_time_choices()
{
    if(get_cfg_int("fire_spawn") == POSTFIRE_LOC_TORCHES) return array("torches");
    return array("kills");
}

postfire_segment()
{
    segment = shared_segment();
    // The Fire split is behind: a split on it would start the run clock at once,
    // ahead of the start condition. The next split is the Lightning craft.
    segment.split = SPLIT_LIGHTNING;
    // Round 12 with 1 zombie left, as Pre-Fire.
    segment.round = 12;
    segment.round_zombies = 1;
    segment.tank_trips = 1; // One setup trip (church to bunkers), not two (user, 2026-10-20).
    segment.staffs = array(ICE, WIND);
    segment.gems = array(ICE, FIRE, WIND);
    // Replaced at the end of the setup: only a missing portal spot leaves this one.
    segment.spots = shared_start_spots(CRAFT_FIRE_ORIGIN, CRAFT_FIRE_ANGLES, CRAFT_FIRE_ORIGIN, CRAFT_FIRE_ANGLES);
    segment.use_exit = false;
    segment.solved_relays = array("relay_air"); // The route has the Gen4 Lightning relay solved from here on.
    segment.first_scramble = 3;
    segment.disc_shortcut_gem = "crypt_gem_fire";
    segment.drone_option = true;
    segment.setup = ::postfire_setup;

    return segment;
}

postfire_setup()
{
    self shared_staff_setup_start();
    torches = get_cfg_int("fire_spawn") == POSTFIRE_LOC_TORCHES;
    // The gramophone goes to the Lightning portal, torches with the Ice exit open
    // too (the Wind exit stays enabled after its portal closed).
    self shared_portals_begin(LIGHTNING, torches, false, ICE);
    souls = get_cfg_int("ice_souls");
    if(souls > ICE_SOULS_MAX) souls = ICE_SOULS_MAX;
    self shared_complete_staff(ICE, souls);
    self shared_complete_staff(WIND, 0);
    self shared_craft_and_take_staff(FIRE);
    if(torches)
    {
        shared_setup_trace("fire: sacrifices");
        shared_fire_sacrifices();
    }
    self shared_portals_wait();
    if(torches)
    {
        level.segment.spots = shared_chamber_exit_spots(ICE);
        return;
    }
    spots = shared_tunnel_portal_spots(LIGHTNING);
    if(isdefined(spots)) level.segment.spots = spots;
}

postfire_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Start", level.mode.label);
        shared_add_location_choice(settings, "fire_spawn", array(POSTFIRE_LOC_KILLS, POSTFIRE_LOC_TORCHES), array("fire kills enter", "torches"));
        self shared_start_time_menu(settings);

    self shared_build_categories(root);
    shared_add_stg_choice("loadout");
    self shared_boomhilda_menu("loadout");
    self shared_add_item_rows("loadout");
    shared_add_ice_souls_row("puzzles");
    add_cfg_toggle("special_ai", "Trio skip", "trioskip");
    self shared_build_segment_menus(false, true);
}

postfire_default_cfg()
{
    settings_ar = [];

    settings_ar["fire_spawn"] = POSTFIRE_LOC_KILLS; // Start Location (POSTFIRE_LOC_*).
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["ice_souls"] = 0;  // "Ice prefills" (0 to ICE_SOULS_MAX).
    settings_ar["skip_first_disc"] = 0;
    settings_ar["trioskip"] = 0; // 1: non-standard "No trios" robot timing.
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, true);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_LEFT);
    settings_ar = shared_disc_defaults(settings_ar, 3);
    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
