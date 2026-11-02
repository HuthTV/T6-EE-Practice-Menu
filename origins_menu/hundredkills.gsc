#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\staffutil;
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
// Templars I..III before this round are not scheduled (as Ending prac).
#define KILLS_FIRST_TEMPLAR_ROUND  19
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
    mode_cfg_load("hundredkills", hundredkills_default_cfg());
    shared_segment_install(hundredkills_segment());
    shared_schedules_init(KILLS_FIRST_TEMPLAR_ROUND);
    shared_held_start_install();
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
// Wind exit puts the player. Vanilla run_chamber_exit sends them to the exit
// trigger's target (Wind Bulbs' "air_teleport_return"). The held start moves the
// player there at the release.
hundredkills_portal_spot()
{
    pad = shared_teleport_pad(WIND);
    landing = undefined;
    exit_trigger = level.a_teleport_exit_triggers[WIND];
    if(isdefined(exit_trigger) && isdefined(exit_trigger.target))
        landing = getstructarray(exit_trigger.target, "targetname")[0];
    if(!isdefined(pad) || !isdefined(landing))
    {
        shared_setup_trace("Wind portal spot not found, starting on the excavation floor");
        return;
    }
    // run_chamber_entrance_teleporter has moved the pad to the portal's middle.
    yaw = vectortoangles(pad.origin - landing.origin)[1];
    level.segment.spots = shared_start_spots(landing.origin, (0, yaw, 0), landing.origin, (0, yaw, 0));
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
    // Step 6: the upgraded Iron Fist.
    hundredkills_wait_stage("step_6");
    self hundredkills_upgrade_punch();
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

// Step 6 as picking up the punch tablet ends it (spawn_punch_upgrade_tablet).
hundredkills_upgrade_punch()
{
    // The Iron Fist given at spawn (shared_run_segment) finishes its flourish
    // first, so the two weapon switches do not overlap.
    while(self get_player_melee_weapon() != "one_inch_punch_zm") wait 0.05;
    self.b_punch_upgraded = 1;
    self.str_punch_element = KILLS_PUNCH_ELEMENT;
    self thread maps\mp\zombies\_zm_weap_one_inch_punch::one_inch_punch_melee_attack();
    flag_set("ee_all_players_upgraded_punch");
}

/*##############################################################################
                              Menu
##############################################################################*/
hundredkills_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        self shared_start_time_menu(settings);
        create_option(settings, "Round: ^3" + get_cfg_int("kills_round"), ::cfg_increment_int, "kills_round", array(16, 17));
        shared_add_stg_choice(settings);
        self shared_boomhilda_menu(settings);
        add_cfg_toggle(settings, "Trio skip", "trioskip", "^2Yes", "^1No");

    self shared_build_panzer_menu(root);
    self shared_build_templar_menu(root);
    self shared_build_robot_menus(root, ::shared_segment_all_random_cycles, shared_robot_earliest_cycle(), false);
}

hundredkills_default_cfg()
{
    settings_ar = [];

    settings_ar["kills_round"] = 16;
    settings_ar["stg_start"] = STG_PAPPED; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar["trioskip"] = 0;
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    // Every disc and Maxis part collected, and the drone crafted and in hand. This
    // mode has no setting for the drone: step 8 needs it.
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["headshot_reward"] = 0;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, true);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_RANDOM);
    return settings_ar;
}
