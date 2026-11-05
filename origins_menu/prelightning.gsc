#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\staffutil;
#include scripts\zm\origins_menu\puzzlerng;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Pre-Lightning
##############################################################################*/
// Ice and Wind completed and filled with souls, Fire completed with zero souls,
// every Lightning piece collected and the gramophone at the Lightning portal. The
// player starts on round 14 carrying the Lightning crystal, with Lightning
// uncrafted, every Lightning relay solved, and the chosen number of zombies left
// in the round. The tank finishes its setup trips at the church.
// Start spots: Craft faces the Lightning staff, Exit is the Lightning Crazy Place exit,
// STG is STG_START_ORIGIN with the dials as scrambled. Lightningstart was split in
// two on 2026-11-04 (user): the piano start after the craft is Post-Lightning.

// Start Location (lightning_spawn).
#define PRELIGHTNING_LOC_CRAFT  0
#define PRELIGHTNING_LOC_STG    1
#define PRELIGHTNING_LOC_EXIT   2

prelightning_initialize()
{
    // Start Time on the Lightning craft: 24:10 to 26:10, every 5 seconds, 25:10
    // by default. Custom: 23 to 31 minutes (Pre-Fire + 4). STG has its own, the
    // same range for now (a guess).
    shared_start_time_add("craft", "craft", "Craft", "24:10", "26:10", 5, "25:10", 23, 31);
    shared_start_time_add("stg", "craft", "Craft", "24:10", "26:10", 5, "25:10", 23, 31);
    level.start_time_choices = ::prelightning_start_time_choices;
    puzzle_rng_install(PUZZLE_RNG_CHAMBER);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("prelightning", prelightning_default_cfg());
    // Crazy Place Walls: visits 1 to 7 are behind (Fire place), Piano is next.
    puzzle_rng_set_first_visit(8, false);
    shared_segment_install(prelightning_segment());
    shared_held_start_install();
}

// level.start_time_choices: STG has its own time.
prelightning_start_time_choices()
{
    if(get_cfg_int("lightning_spawn") == PRELIGHTNING_LOC_STG) return array("stg");
    return array("craft");
}

prelightning_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_LIGHTNING;
    segment.round = 14;
    zombies = get_cfg_int("lightning_zombies"); // 0: the full round
    if(zombies > 0) segment.round_zombies = zombies;
    segment.staffs = array(ICE, WIND, FIRE);
    segment.gems = array(ICE, FIRE, WIND, LIGHTNING);
    segment.spots = shared_start_spots(CRAFT_LIGHTNING_ORIGIN, CRAFT_LIGHTNING_ANGLES, EXIT_LIGHTNING_ORIGIN, EXIT_LIGHTNING_ANGLES);
    segment.use_exit = get_cfg_int("lightning_spawn") == PRELIGHTNING_LOC_EXIT;
    // Every Lightning relay is solved by this point of the route.
    segment.solved_relays = shared_relay_keys();
    segment.first_scramble = 4;
    if(!segment.use_exit) segment.disc_shortcut_gem = "crypt_gem_elec";
    if(get_cfg_int("lightning_spawn") == PRELIGHTNING_LOC_STG) shared_segment_stg(segment, CRAFT_LIGHTNING_ANGLES);
    segment.drone_option = true;
    segment.setup = ::prelightning_setup;
    return segment;
}

prelightning_setup()
{
    self shared_staff_setup_start();
    self shared_portals_begin(LIGHTNING, level.segment.use_exit, false);
    self shared_complete_staff(ICE, 20);
    self shared_complete_staff(WIND, 20);
    self shared_complete_staff(FIRE, 0);
    self shared_get_staff_pieces(LIGHTNING);
    self shared_portals_wait();
}

prelightning_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Start", level.mode.label);
        shared_add_location_choice(settings, "lightning_spawn", array(PRELIGHTNING_LOC_CRAFT, PRELIGHTNING_LOC_STG, PRELIGHTNING_LOC_EXIT), array("Craft", "STG", "Exit"));
        self shared_start_time_menu(settings);
        create_option(settings, "Zombies left: ^3" + shared_zombies_left_text("lightning_zombies"), ::cfg_increment_int, "lightning_zombies", array(0, 24));

    self shared_build_categories(root);
    shared_add_stg_choice("loadout");
    self shared_boomhilda_menu("loadout");
    self shared_add_item_rows("loadout");
    add_cfg_toggle("special_ai", "Trio skip", "trioskip");
    // Disc Turn is for the Craft start: Exit keeps the normal scramble, STG
    // leaves the dials as scrambled.
    self shared_build_segment_menus(get_cfg_int("lightning_spawn") == PRELIGHTNING_LOC_CRAFT, get_cfg_int("lightning_spawn") != PRELIGHTNING_LOC_STG);
}

prelightning_default_cfg()
{
    settings_ar = [];

    settings_ar["dt_start"] = 1;
    settings_ar["lightning_spawn"] = PRELIGHTNING_LOC_EXIT; // Start Location (PRELIGHTNING_LOC_*): Exit by default (user 2026-10-20).
    settings_ar["stg_start"] = STG_NO; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["lightning_zombies"] = 0; // Zombies left in round 14, 0 the full round.
    settings_ar["skip_first_disc"] = 0;
    settings_ar["last_disc"] = 0; // Craft start disc turn: 0 random, 1 = 0 turns, 2 = 1 turn...
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
