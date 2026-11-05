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
// Odin's head with the hole already open (the Rain fire eject), or a little
// earlier in the Crazy Place (user, 2026-11-04): Staff kills, Fire and Lightning
// upgraded staffs in their chargers with no souls yet, or Crazy Place leave,
// every staff charged and the Fire staff in hand, at the chosen exit. Ported from the
// ending practice of various_origins_practice.gsc; the setup uses the same native
// steps as the other segment starts (shared_complete_staff and friends).

// The player waits, frozen, on the Lightning Craft spot while the setup runs.
// Gen 5 start, facing the generator.
#define ENDING_GEN5_ORIGIN  (-2618.15, 547.033, 213.615)
#define ENDING_GEN5_ANGLES  (0, 180, 0)
// Where the head start drops the player when the head ejects them: the Rain fire
// hatch foot, left or right.
#define ENDING_FOOT_LEFT_ORIGIN   (-1621.96, 655.648, 273.856)
#define ENDING_FOOT_RIGHT_ORIGIN  (-2494, -358.133, 303.68)
#define ENDING_SPAWN_GEN5  0
#define ENDING_SPAWN_HEAD  1
#define ENDING_SPAWN_EXIT  2
#define ENDING_SPAWN_STAFF_KILLS  3
#define ENDING_SPAWN_LEAVE        4
#define ENDING_SCORE       100000
// Zombie blood drops until the drone is retrieved: the plane step needs it.
#define ENDING_DROP_INCREMENT  7414.44
// Templars I..III before this round are not scheduled (the old ending practice).
#define ENDING_FIRST_TEMPLAR_ROUND  19

endingprac_initialize()
{
    // Start Time, 28:00 to 30:30 every 5 seconds, Custom 26 to 34 minutes. The
    // clock starts at release (as before), on the fire link button in Odin's
    // head, or on entering Odin's fastest or second fastest hatch foot. Every
    // default is a guess (29:00 was the release's): set them to a run's times.
    shared_start_time_add("release", "release", "Release", "28:00", "30:30", 5, "29:00", 26, 34);
    shared_start_time_add("button", "button", "Button press", "28:00", "30:30", 5, "29:00", 26, 34);
    shared_start_time_add("foot1", "foot", "Odin foot 1st", "28:00", "30:30", 5, "29:00", 26, 34);
    shared_start_time_add("foot2", "foot", "Odin foot 2nd", "28:00", "30:30", 5, "29:00", 26, 34);
    // The Crazy Place locations have their own: Staff kills at release, Crazy
    // Place leave on leaving through the exit. Guesses as well.
    shared_start_time_add("staff_kills", "release", "Release", "26:30", "28:30", 5, "27:30", 24, 34);
    shared_start_time_add("chamber_leave", "exit", "Exit", "27:15", "29:15", 5, "28:15", 24, 34);
    level.start_time_forced = ::endingprac_forced_start_time;
    level.start_time_choices = ::endingprac_start_time_choices;
    mode_cfg_load("endingprac", endingprac_default_cfg());
    // No Trio skip setting (user, 2026-11-04): an old cfg's value is ignored.
    level.mode_cfg["trioskip"] = 0;
    shared_segment_install(endingprac_segment());
    // The old ending practice kept Templars away until round 19.
    shared_schedules_init(ENDING_FIRST_TEMPLAR_ROUND);
    shared_held_start_install();
    replacefunc( maps\mp\zombies\_zm_powerups::get_next_powerup, ::endingprac_get_next_powerup );
}

endingprac_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_FREEDOM;
    segment.round = get_cfg_int("ending_round");
    segment.round_zombies_keys = array("ending_round", "ending_zombies"); // Counted once the player is in.
    segment.staffs = array(ICE, WIND, FIRE, LIGHTNING);
    segment.gems = array(ICE, FIRE, WIND, LIGHTNING);
    // Exit start: ending_exit 0 the Lightning exit, 1 the Wind exit.
    exit_origin = EXIT_LIGHTNING_ORIGIN;
    exit_angles = EXIT_LIGHTNING_ANGLES;
    if(get_cfg_int("ending_exit") == 1)
    {
        exit_origin = EXIT_WIND_ORIGIN;
        exit_angles = EXIT_WIND_ANGLES;
    }
    segment.spots = shared_start_spots(CRAFT_LIGHTNING_ORIGIN, CRAFT_LIGHTNING_ANGLES, exit_origin, exit_angles);
    segment.use_exit = get_cfg_int("ending_spawn") == ENDING_SPAWN_EXIT || get_cfg_int("ending_spawn") == ENDING_SPAWN_LEAVE;
    // Every relay is solved by this point of the route.
    segment.solved_relays = shared_relay_keys();
    segment.drone_option = true;
    segment.score = ENDING_SCORE;
    segment.setup = ::endingprac_setup;
    segment.place_player = ::endingprac_place_player;
    return segment;
}

// The Exit setting's element (ending_exit 0 Lightning, 1 Wind).
endingprac_exit_element()
{
    if(get_cfg_int("ending_exit") == 1) return WIND;
    return LIGHTNING;
}

// The locations in the Crazy Place.
endingprac_in_chamber()
{
    spawn = get_cfg_int("ending_spawn");
    return spawn == ENDING_SPAWN_STAFF_KILLS || spawn == ENDING_SPAWN_LEAVE;
}

endingprac_setup()
{
    self shared_staff_setup_start();
    spawn = get_cfg_int("ending_spawn");
    // Exit and Crazy Place leave: the gramophone is at the exit's portal, which
    // is open. Staff kills: at that portal (the way in), the exit closed.
    // Otherwise in hand (the mound opening gave it back), or at the Wind portal.
    // Opened first, they finish opening while the staffs are completed.
    if(level.segment.use_exit || spawn == ENDING_SPAWN_STAFF_KILLS)
        self shared_portals_begin(endingprac_exit_element(), level.segment.use_exit, false);
    else if(get_cfg_int("ending_gram"))
        self shared_portals_begin(WIND, false, false);
    else
        flag_set("segment_portals_open");
    // Staff kills: Ice and Wind were charged earlier in the route, Fire and
    // Lightning sit in their chargers with no souls (as Pre-Lightning's Fire).
    souls = 20;
    if(spawn == ENDING_SPAWN_STAFF_KILLS) souls = 0;
    self shared_complete_staff(ICE, 20);
    self shared_complete_staff(WIND, 20);
    self shared_complete_staff(FIRE, souls);
    self shared_complete_staff(LIGHTNING, souls);
    self shared_portals_wait();
    self maps\mp\zombies\_zm_weap_beacon::player_give_beacon();
    if(spawn == ENDING_SPAWN_STAFF_KILLS)
        level.segment.spots = shared_chamber_center_spots(endingprac_exit_element());
    else
        self endingprac_take_fire_staff();
    if(spawn == ENDING_SPAWN_LEAVE)
        level.segment.spots = shared_chamber_exit_spots(endingprac_exit_element());

    // The staffs stay on their Crazy Place plinths; the robot heads count as done.
    // Staff kills: once the player has charged them all.
    if(spawn == ENDING_SPAWN_STAFF_KILLS)
        level thread endingprac_staffs_placed_when_upgraded();
    else
        flag_set("ee_all_staffs_placed");
    if(spawn == ENDING_SPAWN_HEAD) shared_open_ee_hole();
}

endingprac_staffs_placed_when_upgraded()
{
    flag_wait("ee_all_staffs_upgraded");
    flag_set("ee_all_staffs_placed");
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

// Called by the held start when the setup is done, before the player is released.
endingprac_place_player()
{
    // Powerup drops for the ending: the mech drops one and zombie blood is first.
    level.mechz_should_drop_powerup = 1;
    level.zombie_vars["zombie_powerup_drop_increment"] = ENDING_DROP_INCREMENT;
    endingprac_start_robots();

    switch(get_cfg_int("ending_spawn"))
    {
        case ENDING_SPAWN_GEN5:
            self setorigin(ENDING_GEN5_ORIGIN);
            self setplayerangles(ENDING_GEN5_ANGLES);
            break;
        case ENDING_SPAWN_HEAD:
            self endingprac_enter_head();
            break;
        default: // Exit: outside the Crazy Place exit. Staff kills, Crazy Place leave: the spots the setup found.
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

// The robots walk from the release, whatever starts the run clock (a foot or
// the button needs them walking): the first cycle starts at once, as the old
// ending practice sent them. Scheduled on the picked start time.
endingprac_start_robots()
{
    shared_robot_schedule(shared_start_time_seconds(), true);
    level.segment_robot_wait = 0;
    flag_set("start_robots");
}

// The Robot head start begins after the eject (the hole is open, no button or
// foot is left): its clock always starts at release.
endingprac_forced_start_time()
{
    switch(get_cfg_int("ending_spawn"))
    {
        case ENDING_SPAWN_HEAD:        return "release";
        case ENDING_SPAWN_STAFF_KILLS: return "staff_kills";
        case ENDING_SPAWN_LEAVE:       return "chamber_leave";
    }
    return undefined;
}

// level.start_time_choices: Gen 5 and Exit pick from the four fire link entries.
endingprac_start_time_choices()
{
    return array("release", "button", "foot1", "foot2");
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
    settings = add_submenu(root, "mapsettings", level.mode.label + " Start", level.mode.label);
        add_cfg_choice(settings, "Start Location", "ending_spawn", array("Gen 5", "Robot head", "Exit", "staff kills", "crazy place leave"));
        self shared_start_time_menu(settings);
        if(level.segment.use_exit || get_cfg_int("ending_spawn") == ENDING_SPAWN_STAFF_KILLS) add_cfg_choice(settings, "Exit Portal", "ending_exit", array("Lightning", "Wind"));
        create_option(settings, "Round: ^3" + get_cfg_int("ending_round"), ::cfg_increment_int, "ending_round", array(15, 16));
        shared_add_round_zombies_option(settings, "ending_round", "ending_zombies");
        // Exit and the Crazy Place locations always have it at that exit's portal (Lightning or Wind).
        if(get_cfg_int("ending_spawn") != ENDING_SPAWN_EXIT && !endingprac_in_chamber()) add_cfg_choice(settings, "Gramophone", "ending_gram", array("in hand", "Wind portal"));

    self shared_build_categories(root);
    shared_add_stg_choice("loadout");
    self shared_boomhilda_menu("loadout");
    add_cfg_toggle("loadout", "Maxis Drone", "maxis_drone_crafted", "^2crafted", "^3not crafted");
    self shared_build_ai_menus(false);
}

endingprac_default_cfg()
{
    settings_ar = [];

    settings_ar["ending_spawn"] = ENDING_SPAWN_HEAD;
    settings_ar["ending_exit"] = 0;     // Exit start: 0 Lightning exit, 1 Wind exit.
    settings_ar["ending_round"] = 16;
    settings_ar["ending_zombies"] = 30; // Zombies left in the round (1 to the round's maximum).
    settings_ar["ending_gram"] = 1;     // 0 in hand, 1 placed at the Wind portal.
    settings_ar["stg_start"] = STG_PAPPED; // STG acquired: STG_NO, STG_YES or STG_PAPPED.
    settings_ar = shared_boomhilda_defaults(settings_ar);
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);
    settings_ar = shared_segment_item_defaults(settings_ar);
    settings_ar["maxis_drone_crafted"] = 1;
    settings_ar["headshot_reward"] = 0;

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, true);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_RANDOM);
    return settings_ar;
}
