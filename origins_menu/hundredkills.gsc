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
                              Raise Hell (EE step 7, 100 kills)
##############################################################################*/
// The last segment of a run, Easter egg step 7 (Samantha's "raise hell"). Every
// step before it is done: all four staffs upgraded and sitting in their Crazy
// Place chargers, the hole opened and the mech fight won, the Maxis drone
// retrieved and in hand, the upgraded Iron Fist, the gramophone at the Wind
// portal. The player starts on round 16 or 17 in front of the Wind portal, to go
// in and kill 100 zombies in the Crazy Place. Vanilla zm_tomb_ee_main_step_7 only
// counts kills inside the Crazy Place while its soul portal is open, which needs
// all four staffs in their chargers. The setup lets each vanilla stage run and
// sets the flag it waits for, as the devgui "Next Step" does (watch_devgui_ee_main).

// Start spot until the setup finds the Wind portal (hundredkills_portal_spot): the
// Lightning Craft spot on the excavation floor.
#define KILLS_SCORE            100000
// "Templars" (kills_templar): none, round 16, round 17, or random of the two.
#define KILLS_TEMPLAR_NONE    0
#define KILLS_TEMPLAR_RANDOM  3
// Templars I..III are behind by round 16: the attack picks its generator as
// vanilla (no Templars I-III generator settings).
#define KILLS_TEMPLARS_BEHIND  3
// Crazy Place Walls: the route's tenth visit (puzzle_rng_route_visit_labels).
#define KILLS_WALLS_VISIT  10
// The upgraded Iron Fist takes the element of the staff held when its tablet is
// picked up (spawn_punch_upgrade_tablet). The route holds the Fire staff since
// the fire link (Ending prac).
#define KILLS_PUNCH_ELEMENT  "fire"

hundredkills_initialize()
{
    // Start time presets: 31:00 to 35:00, every 5 seconds, 33:00 by default. A
    // guess at the run clock when the kills start (Ending prac guesses 29:00 for
    // the fire link): set it to the real one. Custom time: 29 to 39 minutes.
    shared_start_time_add("release", "release", "Release", "31:00", "35:00", 5, "33:00", 29, 39);
    puzzle_rng_install(PUZZLE_RNG_CHAMBER);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("hundredkills", hundredkills_default_cfg());
    // The STG is always acquired here (user, 2026-11-04): an old cfg's "no" loads as plain.
    if(get_cfg_int("stg_start") == STG_NO) level.mode_cfg["stg_start"] = STG_YES;
    // No Trio skip setting (user, 2026-11-04): an old cfg's value is ignored.
    level.mode_cfg["trioskip"] = 0;
    // Visits 1 to 9 are behind, the player starts outside the Crazy Place.
    puzzle_rng_set_first_visit(KILLS_WALLS_VISIT, false);
    shared_segment_install(hundredkills_segment());
    shared_schedules_init(hundredkills_templar_round());
    level.templar_schedule.count = KILLS_TEMPLARS_BEHIND;
    shared_held_start_install();
}

// The round of the Templar attack: "Templars" (kills_templar). A round before the
// start round has passed and none come during the segment (the schedule moves
// past it). None: a round no segment reaches.
hundredkills_templar_round()
{
    switch(get_cfg_int("kills_templar"))
    {
        case 1: return 16;
        case 2: return 17;
        case KILLS_TEMPLAR_RANDOM:
            first = get_cfg_int("kills_round");
            if(first < 16) first = 16;
            if(first >= 17) return 17;
            return first + randomint(2);
        default: return 999;
    }
}

hundredkills_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_FREEDOM;
    // A fresh round: round_zombies stays undefined.
    segment.round = get_cfg_int("kills_round");
    segment.staffs = array(ICE, WIND, FIRE, LIGHTNING);
    segment.gems = array(ICE, FIRE, WIND, LIGHTNING);
    segment.spots = shared_start_spots(CRAFT_LIGHTNING_ORIGIN, CRAFT_LIGHTNING_ANGLES, CRAFT_LIGHTNING_ORIGIN, CRAFT_LIGHTNING_ANGLES);
    segment.use_exit = false;
    // Every relay is solved by this point of the route.
    segment.solved_relays = shared_relay_keys();
    segment.drone_option = true;
    segment.score = KILLS_SCORE;
    // The upgraded Iron Fist is in hand from the spawn, without its flourish (user, 2026-11-04).
    segment.punch_element = KILLS_PUNCH_ELEMENT;
    segment.setup = ::hundredkills_setup;
    return segment;
}

hundredkills_setup()
{
    hundredkills_portal_spot();
    self shared_staff_setup_start();
    // The gramophone stays at the Wind portal. It opens while the staffs are completed.
    self shared_portals_begin(WIND, false, false);
    self shared_complete_staff(ICE, 20);
    self shared_complete_staff(WIND, 20);
    self shared_complete_staff(FIRE, 20);
    self shared_complete_staff(LIGHTNING, 20);
    self shared_portals_wait();
    self hundredkills_complete_ee_steps();
}

// In front of the Wind portal, facing it: where leaving the Crazy Place by the
// Wind exit puts the player (shared_tunnel_portal_spots). The held start moves
// the player there at the release.
hundredkills_portal_spot()
{
    spots = shared_tunnel_portal_spots(WIND);
    if(!isdefined(spots))
    {
        shared_setup_trace("Wind portal spot not found, starting on the excavation floor");
        return;
    }
    level.segment.spots = spots;
}

// Steps 1 to 6, each finished while its vanilla stage (zm_tomb_ee_main_step_N) is
// running, in order: step 4 needs ee_quadrotor_disabled when it starts and the
// drone pickup of step 5 clears it again.
hundredkills_complete_ee_steps()
{
    // Step 1: set by the fourth upgraded staff (staff_charger_check).
    shared_setup_trace("EE: waiting all staffs upgraded");
    flag_wait("ee_all_staffs_upgraded");
    // Step 2: the staffs placed in the robot heads. They stay in their chargers.
    hundredkills_wait_stage("step_2");
    flag_set("ee_all_staffs_placed");
    // Step 3: the fire link opened the hole (watch_for_triple_attack).
    hundredkills_wait_stage("step_3");
    shared_open_ee_hole();
    // Step 4: the fight is won before the drone reaches the hole, so the stage
    // spawns no Panzers.
    hundredkills_wait_stage("step_4");
    flag_set("ee_mech_zombie_fight_completed");
    flag_set("ee_quadrotor_disabled");
    // Step 5: the drone taken back from the pilot (quadrotor_pickup_think).
    hundredkills_wait_stage("step_5");
    flag_clear("ee_quadrotor_disabled");
    flag_set("ee_maxis_drone_retrieved");
    level thread hundredkills_remove_biplane();
    // Step 6: the upgraded Iron Fist, already in hand (segment.punch_element).
    hundredkills_wait_stage("step_6");
    flag_set("ee_all_players_upgraded_punch");
    // Step 7 is the segment: its soul portal opens with all four staffs in place.
    hundredkills_wait_stage("step_7");
    flag_wait("ee_sam_portal_active");
    shared_setup_trace("EE: soul portal open");
}

// Each stage's init_stage names it in level._cur_stage_name.
hundredkills_wait_stage(stage)
{
    shared_setup_trace("EE: waiting " + stage);
    while(!isdefined(level._cur_stage_name) || level._cur_stage_name != stage) wait 0.05;
}

// Step 5 sends out its zombie blood biplane even with the drone already retrieved
// (spawn_zombie_blood_plane). It is gone by this point of a run.
hundredkills_remove_biplane()
{
    for(i = 0; i < 100; i++)
    {
        biplane = getent("zombie_blood_biplane", "targetname");
        if(isdefined(biplane))
        {
            biplane delete();
            return;
        }
        wait 0.05;
    }
    shared_setup_trace("EE: zombie blood biplane not found");
}

/*##############################################################################
                              Menu
##############################################################################*/
hundredkills_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        self shared_start_time_menu(settings);
        create_option(settings, "Round: ^3" + get_cfg_int("kills_round"), ::cfg_increment_int, "kills_round", array(16, 17));
        stg_text = "^1No";
        if(get_cfg_int("stg_start") == STG_PAPPED) stg_text = "^2Yes";
        create_option(settings, "STG PaP: " + stg_text, ::hundredkills_stg_toggle);
        self shared_boomhilda_menu(settings);
        // The Raise Hell visit's walls (puzzle_rng): up to two staffs the wall
        // never lands on (user, 2026-11-04).
        names = puzzle_rng_chamber_names();
        choices = array("none", names[0], names[1], names[2], names[3]);
        add_cfg_choice(settings, "Clear wall", "chamber_v" + KILLS_WALLS_VISIT + "_a", choices);
        add_cfg_choice(settings, "Clear wall", "chamber_v" + KILLS_WALLS_VISIT + "_b", choices);

    // No Panzer or robot menus (user, 2026-11-04): the segment needs neither.
    templars = add_submenu(root, "templars", "Templars");
        add_cfg_choice(templars, "Templars", "kills_templar", array("no", "round 16", "round 17", "random"));
}

// "STG PaP": the STG is always acquired, plain or upgraded.
hundredkills_stg_toggle()
{
    value = STG_PAPPED;
    if(get_cfg_int("stg_start") == STG_PAPPED) value = STG_YES;
    self cfg_set_int("stg_start", value);
}

hundredkills_default_cfg()
{
    settings_ar = [];

    settings_ar["kills_round"] = 16;
    settings_ar["stg_start"] = STG_PAPPED; // "STG PaP": STG_YES or STG_PAPPED.
    settings_ar["kills_templar"] = KILLS_TEMPLAR_NONE; // "Templars": 0 no, 1 round 16, 2 round 17, 3 random.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    // Every disc and Maxis part collected, and the drone crafted and in hand. This
    // mode has no setting for the drone: step 8 needs it.
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, true);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_RANDOM);
    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
