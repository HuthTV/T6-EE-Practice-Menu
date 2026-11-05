#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\staffutil;
#include scripts\zm\origins_menu\puzzlerng;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Post-Lightning
##############################################################################*/
// Ice and Wind completed and filled with souls, Fire completed with zero souls, the
// gramophone at the Lightning portal, every Lightning relay solved, and the chosen
// number of zombies left in round 14. One start, piano (user, 2026-11-04): the
// Lightning staff crafted and in hand, in the Lightning tunnel about to go through
// the portal for the piano, so there is no Start Location row. Pre-Lightning has the
// locations before the craft (split from Lightningstart, user 2026-11-04).

postlightning_initialize()
{
    // Start Time in the Lightning portal's teleport: 24:40 to 26:40, every 5
    // seconds, 25:40 by default. Custom: 23 to 31 minutes. A guess.
    shared_start_time_add("piano", "portal", "Portal", "24:40", "26:40", 5, "25:40", 23, 31);
    puzzle_rng_install(PUZZLE_RNG_CHAMBER);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("postlightning", postlightning_default_cfg());
    // Crazy Place Walls: visits 1 to 7 are behind (Fire place), Piano is next.
    puzzle_rng_set_first_visit(8, false);
    shared_segment_install(postlightning_segment());
    shared_held_start_install();
}

postlightning_segment()
{
    segment = shared_segment();
    // Every staff is crafted: as in Ending prac, no split starts the run clock (the
    // portal does) and the only row is the live Freedom one.
    segment.split = SPLIT_FREEDOM;
    segment.round = 14;
    zombies = get_cfg_int("lightning_zombies"); // 0: the full round
    if(zombies > 0) segment.round_zombies = zombies;
    segment.staffs = array(ICE, WIND, FIRE);
    segment.gems = array(ICE, FIRE, WIND, LIGHTNING);
    // Replaced at the end of the setup: only a missing portal spot leaves this one.
    segment.spots = shared_start_spots(CRAFT_LIGHTNING_ORIGIN, CRAFT_LIGHTNING_ANGLES, CRAFT_LIGHTNING_ORIGIN, CRAFT_LIGHTNING_ANGLES);
    segment.use_exit = false;
    // Every Lightning relay is solved by this point of the route.
    segment.solved_relays = shared_relay_keys();
    segment.first_scramble = 4;
    segment.disc_shortcut_gem = "crypt_gem_elec";
    segment.drone_option = true;
    segment.setup = ::postlightning_setup;
    return segment;
}

postlightning_setup()
{
    self shared_staff_setup_start();
    self shared_portals_begin(LIGHTNING, false, false);
    self shared_complete_staff(ICE, 20);
    self shared_complete_staff(WIND, 20);
    self shared_complete_staff(FIRE, 0);
    self shared_craft_and_take_staff(LIGHTNING);
    self shared_portals_wait();
    spots = shared_tunnel_portal_spots(LIGHTNING);
    if(isdefined(spots)) level.segment.spots = spots;
}

postlightning_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        self shared_start_time_menu(settings);
        add_cfg_toggle(settings, "Trio skip", "trioskip", "^2Yes", "^1No");
        shared_add_stg_choice(settings);
        self shared_boomhilda_menu(settings);
        add_cfg_toggle(settings, "Skip First Disc", "skip_first_disc", "^2Yes", "^1No");
        create_option(settings, "Zombies left: ^3" + shared_zombies_left_text("lightning_zombies"), ::cfg_increment_int, "lightning_zombies", array(0, 24));

    self shared_build_items_menu(root);
    self shared_build_segment_menus(root);
}

postlightning_default_cfg()
{
    settings_ar = [];

    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["lightning_zombies"] = 0; // Zombies left in round 14, 0 the full round.
    settings_ar["skip_first_disc"] = 0;
    settings_ar["trioskip"] = 0; // 1: non-standard "No trios" robot timing.
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, true);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_LEFT);
    settings_ar = shared_disc_defaults(settings_ar, 4);
    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
