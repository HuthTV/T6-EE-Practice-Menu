#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\puzzlerng;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Pre-Ice
##############################################################################*/
// Round 10 with the Ice staff about to be crafted, by Start Location (start_loc).
// Icestart was split in two on 2026-11-04 (user): the locations after the craft
// are Post-Ice.
//   The game runs from the black screen: the player can first view the Ice code
//   (Peek Code), then is moved to the start spot once the mound is open. Floor and
//   Mule share one Start Time, on the craft. STG has its own, and its dials keep the
//   mound opening's scramble (no shortcut, no Skip First Disc).

// Teleport spots (origin, view angles).
#define ICE_PEEK_CODE_ORIGIN  (11251, -7418.49, -403.875)
#define ICE_PEEK_CODE_ANGLES  (342.943, 53.5034, 0)
#define ICE_FLOOR_ORIGIN      (-46.571, 172.697, -751.875)
#define ICE_FLOOR_ANGLES      (11.6608, 99.3494, 0)
#define ICE_MULE_ORIGIN       (-74.8256, -400.802, -493.875)
#define ICE_MULE_ANGLES       (13.8415, 315.165, 0)

// Start Location (start_loc).
#define PREICE_LOC_FLOOR  0
#define PREICE_LOC_MULE   1
#define PREICE_LOC_STG    2

preice_initialize()
{
    // Start Times on the Ice craft, every 5 seconds. Floor and mule share one, STG
    // has its own, the same for now.
    shared_start_time_add("craft", "craft", "Craft", ICE_CRAFT_MIN, ICE_CRAFT_MAX, 5, ICE_CRAFT_DEFAULT);
    puzzle_rng_install(PUZZLE_RNG_ICE);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("preice", preice_default_cfg());
    // Crazy Place Walls (user, 2026-11-02): the Ice gem visit is behind, so
    // visits start at 2 (Ice code).
    puzzle_rng_set_first_visit(2, false);

    flag_init("preice_setup_done");
    flag_clear("preice_setup_done");
    flag_init("preice_ready"); // Set when setup is done and the player is released.
    flag_clear("preice_ready");
    shared_segment_install(preice_segment());
    shared_set_round(10, 1); // Install before native startup enters its callback.
}

preice_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_ICE;
    segment.gems = array(ICE);
    shared_ice_route(segment);
    segment.leave_gramophone = !get_cfg_int("early_gram");
    if(get_cfg_int("start_loc") == PREICE_LOC_STG)
    {
        segment.disc_shortcut_gem = undefined;
        segment.discs_untouched = true;
    }

    // Pre-Ice's own start (Peek Code) instead of the held start. The player is
    // held from the spawn, before the black screen ends, until setup is done.
    segment.on_spawn = ::preice_hold_controls;
    segment.start = ::preice_start;
    segment.setup = ::preice_setup;
    return segment;
}

preice_setup()
{
    self shared_get_parts();
}

// on_spawn: freezes the player every frame (the vanilla intro fade unfreezes
// them) until the start spot is reached and setup is done. Not with Peek Code,
// which freezes only while the timescale is 10.
preice_hold_controls()
{
    self endon("disconnect");
    if(get_cfg_int("peek_code")) return;

    while(self.sessionstate != "playing") wait 0.05;
    while(!flag("preice_ready"))
    {
        self freezecontrols(1);
        wait 0.05;
    }
}

preice_run_setup()
{
    self [[ level.segment.setup ]]();
    flag_set("preice_setup_done");
}

// start: the game runs from the black screen. Setup, the MP40 clue and the
// teleport (after Peek Code) happen while it does. The Ice craft starts the run
// clock at the selected start time (shared_start_clock). Ice has no Trio skip
// setting: every Ice craft time is before the round 12 trio cycle, so both
// columns give the same schedule.
preice_start()
{
    setDvar("timescale", 1);
    if(get_cfg_int("cycle_tracker")) level thread shared_cycle_tracker();
    level thread preice_auto_round_end();
    self shared_start_time_begin();
    self thread preice_run_setup();
    self thread shared_mp40_tile_clue();
    self thread preice_start_teleport();
    flag_wait("start_robots");
}

preice_start_teleport()
{
    // OOPA off during the intro, in memory only: the saved setting is untouched.
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
    while(!flag("preice_setup_done") && gettime() - setup_wait_start < 60000) wait 0.05;

    // Start Location: floor, mule or STG.
    switch(get_cfg_int("start_loc"))
    {
        case PREICE_LOC_STG:
            // Floor's points and Mule Kick (a guess), the floor's view.
            self.score = 6500;
            self maps\mp\zombies\_zm_perks::give_perk("specialty_additionalprimaryweapon");
            self setorigin(STG_START_ORIGIN);
            self setplayerangles(ICE_FLOOR_ANGLES);
            break;
        case PREICE_LOC_MULE:
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
    flag_set("preice_ready");
    self freezecontrols( 0 );
    self.kills = 205 + randomint( 26 );
}

preice_auto_round_end()
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
                              Menu
##############################################################################*/
preice_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        shared_add_location_choice(settings, "start_loc", array(PREICE_LOC_FLOOR, PREICE_LOC_MULE, PREICE_LOC_STG), array("floor", "mule", "STG"));
        self shared_start_time_menu(settings);
        add_cfg_toggle(settings, "R2L Route", "r2l");
        // Cycle 1 Foot picks the second bunker door: only R2L has a choice.
        if(get_cfg_int("r2l")) add_cfg_choice(settings, "Cycle 1 Foot", "trench_path", array("random", "gen 2", "gen 3"));
        add_cfg_toggle(settings, "Gram", "early_gram", "^2in hand", "^3placed");
        add_cfg_toggle(settings, "Auto Round End", "auto_round_end");
        if(get_cfg_int("auto_round_end")) create_option(settings, "Auto End Delay: ^3" + get_cfg_int("auto_round_end_delay") + "s", ::cfg_increment_int, "auto_round_end_delay", array(1, 10));

    self shared_build_categories(root);
    self shared_add_item_rows("loadout");
    // STG leaves the dials as the mound opening scrambled them.
    has_disc_rows = get_cfg_int("start_loc") != PREICE_LOC_STG;
    self shared_build_segment_menus(has_disc_rows, has_disc_rows);
    add_cfg_toggle("ice_code", "MP40 Tile Clue", "mp40_tile_clue");
    add_cfg_toggle("ice_code", "Peek Code", "peek_code");
}

preice_default_cfg()
{
    settings_ar = [];

    settings_ar["start_loc"] = PREICE_LOC_FLOOR; // PREICE_LOC_*
    settings_ar["peek_code"] = 0; // 1: view the Ice code before the mound opens. Off by default (user, 2026-10-25).
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
