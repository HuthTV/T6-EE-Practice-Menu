#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\staffutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Ending prac
##############################################################################*/
// All four staffs completed and upgraded, every generator captured, the Maxis
// drone crafted, the Fire staff in hand. The player starts on round 15 or 16 with
// the chosen number of zombies left, either at Gen 5 before the fire link (the
// robots walk a three robot round with the hatch on the Rain fire robot), or in
// Odin's head with the hole already open (the Rain fire eject). Ported from the
// ending practice of various_origins_practice.gsc; the setup uses the same native
// steps as the other segment starts (shared_complete_staff and friends).

// Where the player waits, frozen, while the setup runs: the excavation floor.
#define ENDING_HOLD_ORIGIN  (50.0612, 199.082, -751.875)
#define ENDING_HOLD_ANGLES  (11.5839, 79.2444, 0)
// Gen 5 start, facing the generator.
#define ENDING_GEN5_ORIGIN  (-2618.15, 547.033, 213.615)
#define ENDING_GEN5_ANGLES  (0, 180, 0)
// Where the head start drops the player when the head ejects them: the Rain fire
// hatch foot, left or right.
#define ENDING_FOOT_LEFT_ORIGIN   (-1621.96, 655.648, 273.856)
#define ENDING_FOOT_RIGHT_ORIGIN  (-2494, -358.133, 303.68)
// Crazy Place exits for the Exit start (ending_exit: 0 Lightning, 1 Wind).
#define ENDING_LIGHTNING_EXIT_ORIGIN  (9633.01, -6973.31, -345.875)
#define ENDING_LIGHTNING_EXIT_ANGLES  (359.462, 139.132, 0)
#define ENDING_WIND_EXIT_ORIGIN       (11234, -8687.25, -407.875)
#define ENDING_WIND_EXIT_ANGLES       (0.0976524, 302.888, 0)
#define ENDING_SPAWN_GEN5  0
#define ENDING_SPAWN_HEAD  1
#define ENDING_SPAWN_EXIT  2
#define ENDING_SCORE       100000
// Zombie blood drops until the drone is retrieved: the plane step needs it.
#define ENDING_DROP_INCREMENT  7414.44
// Templars I..III before this round are not scheduled (the old ending practice).
#define ENDING_FIRST_TEMPLAR_ROUND  19

endingprac_initialize()
{
    // Start time presets: 28:00 to 30:30, every 5 seconds, 29:00 by default. A
    // guess at the round 15 and 16 fire link time of a run: set it to the real one.
    // Custom time: 26 to 34 minutes.
    shared_craft_time_setup("28:00", "30:30", 5, "29:00", 26, 34);
    mode_cfg_load("endingprac", endingprac_default_cfg());
    shared_segment_install(endingprac_segment());
    // The old ending practice kept Templars away until round 19.
    shared_schedules_init(ENDING_FIRST_TEMPLAR_ROUND);
    shared_held_start_install();
    replacefunc( maps\mp\zombies\_zm_powerups::get_next_powerup, ::endingprac_get_next_powerup );
}

endingprac_run()
{
    level shared_run_segment(level.segment);
}

endingprac_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_FREEDOM;
    segment.round = get_cfg_int("ending_round");
    segment.round_zombies = endingprac_zombies();
    segment.staffs = array(ICE, WIND, FIRE, LIGHTNING);
    segment.gems = array(ICE, FIRE, WIND, LIGHTNING);
    exit_origin = ENDING_LIGHTNING_EXIT_ORIGIN;
    exit_angles = ENDING_LIGHTNING_EXIT_ANGLES;
    if(get_cfg_int("ending_exit") == 1)
    {
        exit_origin = ENDING_WIND_EXIT_ORIGIN;
        exit_angles = ENDING_WIND_EXIT_ANGLES;
    }
    segment.spots = shared_start_spots(ENDING_HOLD_ORIGIN, ENDING_HOLD_ANGLES, exit_origin, exit_angles);
    segment.use_exit = get_cfg_int("ending_spawn") == ENDING_SPAWN_EXIT;
    // Every relay is solved by this point of the route.
    segment.solved_relays = array("relay_start", "relay_tank", "relay_air", "relay_elec", "relay_ruins", "relay_ice", "relay_village");
    segment.score = ENDING_SCORE;
    segment.setup = ::endingprac_setup;
    segment.place_player = ::endingprac_place_player;
    segment.clock_start = ::endingprac_clock_start;
    return segment;
}

endingprac_setup()
{
    self shared_staff_setup_start();
    // Exit start: the gramophone is at the exit's portal, which is open. Otherwise
    // in hand (the mound opening gave it back), or at the Wind portal. Opened
    // first, they finish opening while the staffs are completed.
    if(level.segment.use_exit)
    {
        element = LIGHTNING;
        if(get_cfg_int("ending_exit") == 1) element = WIND;
        self shared_portals_begin(element, true, false);
    }
    else if(get_cfg_int("ending_gram"))
        self shared_portals_begin(WIND, false, false);
    else
        flag_set("segment_portals_open");
    self shared_complete_staff(ICE, 20);
    self shared_complete_staff(WIND, 20);
    self shared_complete_staff(FIRE, 20);
    self shared_complete_staff(LIGHTNING, 20);
    self shared_portals_wait();
    self maps\mp\zombies\_zm_weap_beacon::player_give_beacon();
    self endingprac_take_fire_staff();

    // The staffs stay on their Crazy Place plinths; the robot heads count as done.
    flag_set("ee_all_staffs_placed");
    if(get_cfg_int("ending_spawn") == ENDING_SPAWN_HEAD) endingprac_open_hole();
}

// Picks up the upgraded Fire staff through its native pickup trigger. The trigger
// exists once the staff is charged, but it only listens after the staff has moved
// into place, so the notify is repeated until the player has the staff.
endingprac_take_fire_staff()
{
    flag_wait("ee_all_staffs_upgraded");
    wait 1;
    staff = maps\mp\zm_tomb_craftables::get_staff_info_from_element_index(FIRE);
    while(!isDefined(staff.upgrade.trigger)) wait 0.05;
    upgraded = staff.upgrade;
    // The native pickup refuses a player who carries another staff.
    foreach(weapon in self getWeaponsListPrimaries())
    {
        shared_setup_trace("carrying " + weapon);
        if(issubstr(weapon, "staff") && weapon != upgraded.weapname) self takeWeapon(weapon);
    }
    for(attempt = 0; attempt < 40 && !self hasWeapon(upgraded.weapname); attempt++)
    {
        upgraded.trigger notify("trigger", self);
        wait 0.25;
    }
    // The trigger did not answer: give the staff as the native pickup does.
    if(!self hasWeapon(upgraded.weapname))
    {
        shared_setup_trace("fire staff pickup trigger silent, giving it directly");
        upgraded ghost();
        self giveWeapon(upgraded.weapname);
        self switchToWeapon(upgraded.weapname);
        self setWeaponAmmoClip(upgraded.weapname, weaponClipSize(upgraded.weapname));
        upgraded.owner = self;
        upgraded notify("staff_equip");
        upgraded.charger.is_inserted = 0;
        upgraded setClientField("staff_charger", 0);
        upgraded.charger.full = 1;
        maps\mp\zm_tomb_craftables::set_player_staff(upgraded.weapname, self);
    }
    shared_setup_trace("fire staff in hand: " + self hasWeapon(upgraded.weapname));
}

// The fire link step is done: the floor is gone (as vanilla watch_for_triple_attack
// leaves it) and the mech fight can start.
endingprac_open_hole()
{
    flag_set("ee_mech_zombie_hole_opened");
    floor = getent("easter_mechzombie_spawn", "targetname");
    if(isDefined(floor)) floor delete();
    hole = getent("fire_link_damage", "targetname");
    if(isDefined(hole)) hole delete();
}

// Called by the held start when the setup is done, before the player is released.
endingprac_place_player()
{
    // Powerup drops for the ending: the mech drops one and zombie blood is first.
    level.mechz_should_drop_powerup = 1;
    level.zombie_vars["zombie_powerup_drop_increment"] = ENDING_DROP_INCREMENT;

    switch(get_cfg_int("ending_spawn"))
    {
        case ENDING_SPAWN_GEN5:
            self setorigin(ENDING_GEN5_ORIGIN);
            self setplayerangles(ENDING_GEN5_ANGLES);
            break;
        case ENDING_SPAWN_HEAD:
            self endingprac_enter_head();
            break;
        default: // Exit: the Crazy Place exit's spot.
            self shared_teleport_to_start(level.segment.spots, true);
            break;
    }
}

// Takes the player into Odin's head, as walking into it would: the rest of the
// native head logic (eject, fall to the foot) carries on from here.
endingprac_enter_head()
{
    foot = ENDING_FOOT_LEFT_ORIGIN;
    setting = get_cfg_int("rain_foot");
    if(setting == FOOT_RIGHT || (setting != FOOT_LEFT && cointoss()))
        foot = ENDING_FOOT_RIGHT_ORIGIN;

    self.teleport_initial_origin = foot;
    maps\mp\zm_tomb_teleporter::stargate_teleport_player("head_0_teleport_player", self, 4.0, 0);
    robot = getent("giant_robot_walker_0", "targetname");
    robot ent_flag_set("robot_head_entered");
    self maps\mp\zombies\_zm_stats::increment_client_stat("tomb_giant_robot_accessed", 0);
    self maps\mp\zombies\_zm_stats::increment_player_stat("tomb_giant_robot_accessed");
    self playsoundtoplayer("zmb_bot_elevator_ride_up", self);

    start_wait = 0.0;
    black_screen_wait = 4.0;
    fade_in_time = 0.01;
    fade_out_time = 0.2;
    self thread maps\mp\gametypes_zm\_hud::fadetoblackforxsec(start_wait, black_screen_wait, fade_in_time, fade_out_time, "white");
    transition_time = start_wait + black_screen_wait + fade_in_time + fade_out_time;
    self thread maps\mp\zm_tomb_giant_robot::player_transition_into_robot_head_start(start_wait + fade_in_time);
    self thread maps\mp\zm_tomb_giant_robot::player_transition_into_robot_head_finish(transition_time);
    self thread maps\mp\zm_tomb_giant_robot::player_death_watch_on_giant_robot();
    self thread endingprac_head_ignoreme();
}

// The held start makes the player targetable on release; in the head they stay
// ignored until the eject (native code sets it back).
endingprac_head_ignoreme()
{
    self endon("disconnect");
    flag_wait("segment_ready");
    wait 0.1;
    if(isDefined(self.teleport_initial_origin)) self.ignoreme = 1;
}

// Run clock: the picked start time, with the first robot cycle starting at once
// (the old ending practice sent the robots straight away).
endingprac_clock_start()
{
    shared_craft_time_start_clock();
    level.segment_robot_wait = 0;
}

// Vanilla get_next_powerup; until the drone is retrieved every drop is zombie
// blood (the biplane step needs it).
endingprac_get_next_powerup() // OVERRIDE: maps\mp\zombies\_zm_powerups::get_next_powerup
{
    if(flag("ee_maxis_drone_retrieved"))
    {
        powerup = level.zombie_powerup_array[level.zombie_powerup_index];
        level.zombie_powerup_index++;

        if(level.zombie_powerup_index >= level.zombie_powerup_array.size)
        {
            level.zombie_powerup_index = 0;
            maps\mp\zombies\_zm_powerups::randomize_powerups();
        }

        return powerup;
    }
    return "zombie_blood";
}

/*##############################################################################
                              Menu
##############################################################################*/
endingprac_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_choice(settings, "Start Location", "ending_spawn", array("Gen 5", "Robot head", "Exit"));
        if(get_cfg_int("ending_spawn") == ENDING_SPAWN_EXIT) add_cfg_choice(settings, "Exit", "ending_exit", array("Lightning", "Wind"));
        create_option(settings, "Round: ^3" + get_cfg_int("ending_round"), ::cfg_increment_int, "ending_round", array(15, 16));
        create_option(settings, "Zombies: ^3" + endingprac_zombies() + " ^7(" + endingprac_zombies_max() + ")", ::endingprac_next_zombies);
        add_cfg_choice(settings, "STG acquired", "stg_start", array("no", "yes", "papped"));
        // The Exit start always has it at that exit's portal (Lightning or Wind).
        if(get_cfg_int("ending_spawn") != ENDING_SPAWN_EXIT) add_cfg_choice(settings, "Gramophone", "ending_gram", array("in hand", "Wind portal"));
        add_cfg_toggle(settings, "Maxis Drone", "maxis_drone_crafted", "^2crafted", "^3not crafted");
        create_option(settings, "Rain foot: ^3" + rain_foot_text(), ::cfg_increment_int, "rain_foot", array(FOOT_RANDOM, FOOT_RIGHT));
        self shared_craft_time_menu(settings, "Start Time");
        add_cfg_toggle(settings, "Trio skip", "trioskip", "^2Yes", "^1No");

    self shared_build_panzer_menu(root);
    self shared_build_templar_menu(root);
    self shared_build_robot_menus(root, ::shared_segment_all_random_cycles, shared_robot_earliest_cycle(), false);
}

// Most zombies the chosen round can have.
endingprac_zombies_max()
{
    return practice_round_zombie_count(get_cfg_int("ending_round"));
}

// Zombies remaining, kept within 1 and the round's maximum.
endingprac_zombies()
{
    zombies = get_cfg_int("ending_zombies");
    max = endingprac_zombies_max();
    if(zombies > max) zombies = max;
    if(zombies < 1) zombies = 1;
    return zombies;
}

endingprac_next_zombies()
{
    zombies = endingprac_zombies() + 1;
    if(zombies > endingprac_zombies_max()) zombies = 1;
    self cfg_set_int("ending_zombies", zombies);
}

endingprac_default_cfg()
{
    settings_ar = [];

    settings_ar["ending_spawn"] = ENDING_SPAWN_HEAD;
    settings_ar["ending_exit"] = 0;     // Exit start: 0 Lightning exit, 1 Wind exit.
    settings_ar["ending_round"] = 16;
    settings_ar["ending_zombies"] = 30; // Zombies left in the round; 0 the full round.
    settings_ar["ending_gram"] = 1;     // 0 in hand, 1 placed at the Wind portal.
    settings_ar["stg_start"] = STG_PAPPED; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar["trioskip"] = 0;
    settings_ar = shared_craft_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["maxis_drone_crafted"] = 1;
    settings_ar["headshot_reward"] = 0;

    settings_ar["panzer_2"] = 0;
    settings_ar["panzer_3"] = 0;

    settings_ar["relay_start"] = 1;
    settings_ar["relay_tank"] = 1;
    settings_ar["relay_air"] = 1;
    settings_ar["relay_elec"] = 1;
    settings_ar["relay_ruins"] = 1;
    settings_ar["relay_ice"] = 1;
    settings_ar["relay_village"] = 1;

    settings_ar = shared_templar_defaults(settings_ar);

    // Robot cycles and feet
    for(cycle = 1; cycle <= ROBOT_CYCLE_COUNT; cycle++)
    {
        settings_ar["cycle_" + cycle] = ROBOT_RANDOM;
        settings_ar["foot_" + cycle] = FOOT_RANDOM;
    }

    settings_ar["rain_foot"] = FOOT_RANDOM;
    settings_ar["rain_robot"] = ROBOT_ODIN; // Rain Fire hatch robot (segment default).
    settings_ar["cycle_tracker_ms"] = 0;
    settings_ar["cycle_tracker"] = 1;
    return settings_ar;
}
