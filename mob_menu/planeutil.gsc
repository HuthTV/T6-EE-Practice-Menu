#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\utility_core\splits;
#include scripts\zm\mob_menu\mob;
#include scripts\zm\mob_menu\mobsplits;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Plane segments (shared by Plane I, II and III)
##############################################################################*/
// A plane segment starts the player on its start round with the route done up
// to that plane: doors, key, afterlife boxes, generators, nixie code and gondola
// open, the plane built (Plane I, or the parts in hand) or flown and refuelled
// (Plane II and III), so the player only boards it. The setup is automatic:
// it starts in the opening afterlife, revives the player, and runs at timescale
// 10 from map load while the rounds before the start round are skipped; the
// segment starts when the start round begins.
//
// Each mode passes its own data in a struct from mob_plane_segment():
//   cycles         plane trips already done: 0, 1 or 2
//   start_round    round the segment starts on
//   start_zombies  zombies in the start round: 1 to 4, START_ZOMBIES_RANDOM
//                  (1 to 4 at random) or START_ZOMBIES_FULL (the whole round)
//   docks_souls    souls in the docks soul catcher; 0 picks 4 to 6
//   all_wolves     fill every soul catcher instead
//   prebuilt       Plane I: build the plane, so the player only boards it
//   tomahawk       give the tomahawk
//   perks          perk specialties to give
//   split          MOB_SPLIT_PLANE_n: the split boarding this plane records; it
//                  starts the run clock at the mode's start time ("Plane Time")
//   on_start       optional mode function, run with self = player at the start

// Old M-Practice Plane 1 doors (zombie_door trigger origins).
#define DOOR_SPAWN_M14    (2105, 10581, 1374)
#define DOOR_CAFE_TRAP    (2205, 9645, 1378)
#define DOOR_CAFE_STAIRS  (2429, 9793, 1374)
#define DOOR_DRYER        (1227, 9983, 1170)
#define DOOR_CODES        (101, 8124, 311)
#define DOOR_GEN_LEFT     (-275, 6937, 112)
#define DOOR_MP5_CATWALK  (1601, 9223, 1482)
#define DOOR_CITADEL      (416, 9438, 1146)
#define DOOR_DOCKS_WOLF   (136, 6322, 102)

// Where the segment starts: on the roof, by the plane.
#define ROOF_SPOT  (3646.64, 9863.25, 1712.13)

mob_plane_segment()
{
    segment = spawnstruct();
    segment.cycles = 0;
    segment.start_round = 3;
    segment.start_zombies = START_ZOMBIES_RANDOM;
    segment.docks_souls = 0;
    segment.prebuilt = false;
    segment.all_wolves = false;
    segment.tomahawk = false;
    segment.perks = [];
    segment.split = MOB_SPLIT_PLANE_1;
    return segment;
}

mob_plane_default_cfg(settings_ar, start_round, start_zombies)
{
    settings_ar["start_round"] = start_round;
    settings_ar["start_zombies"] = start_zombies;
    settings_ar["perk_jugg"] = 0;
    settings_ar["perk_dt"] = 0;
    settings_ar["perk_speed"] = 0;
    settings_ar["perk_cherry"] = 0;
    settings_ar["perk_deadshot"] = 0;
    settings_ar = practice_start_time_defaults(settings_ar); // Plane Time
    return settings_ar;
}

// Load-time part of every plane segment (the mode's initialize). Out-of-area and
// despawn checks wait for the setup to end (plane_released), then follow a real
// run's timing from the Plane Time clock (core practice_check_phasing).
mob_plane_install()
{
    flag_init("plane_released");
    flag_init("practice_clock_started");
    practice_check_phasing("plane_released", "practice_clock_started");
}

// Perks chosen in the mode's settings (keys from mob_plane_default_cfg).
mob_plane_cfg_perks()
{
    perks = [];
    if(get_cfg_int("perk_jugg"))     perks[perks.size] = "specialty_armorvest";
    if(get_cfg_int("perk_dt"))       perks[perks.size] = "specialty_rof";
    if(get_cfg_int("perk_speed"))    perks[perks.size] = "specialty_fastreload";
    if(get_cfg_int("perk_cherry"))   perks[perks.size] = "specialty_grenadepulldeath";
    if(get_cfg_int("perk_deadshot")) perks[perks.size] = "specialty_deadshot";
    return perks;
}

// The plane segments' shared settings rows. "Plane Time" is the run time the
// plane is boarded at: boarding starts the split timer there.
mob_plane_settings_menu(settings, min_round, max_round)
{
    practice_start_time_menu(settings);
    create_option(settings, "Start round: ^3" + get_cfg_int("start_round"), ::cfg_increment_int, "start_round", array(min_round, max_round));
    create_option(settings, "Start round zombies: ^3" + mob_start_zombies_text(), ::cfg_increment_int, "start_zombies", array(START_ZOMBIES_RANDOM, START_ZOMBIES_FULL));
    perks = add_submenu(settings, "perks", "Perks");
        add_cfg_toggle(perks, "Juggernog", "perk_jugg", "^2Yes", "^1No");
        add_cfg_toggle(perks, "Double Tap", "perk_dt", "^2Yes", "^1No");
        add_cfg_toggle(perks, "Speed Cola", "perk_speed", "^2Yes", "^1No");
        add_cfg_toggle(perks, "Electric Cherry", "perk_cherry", "^2Yes", "^1No");
        add_cfg_toggle(perks, "Deadshot", "perk_deadshot", "^2Yes", "^1No");
}

mob_start_zombies_text()
{
    switch(get_cfg_int("start_zombies"))
    {
        case START_ZOMBIES_RANDOM: return "random 1-4";
        case START_ZOMBIES_FULL:   return "full round";
        default:                   return get_cfg_int("start_zombies");
    }
}

// The mode's run(), from init (before round 1 begins): starts the round skip,
// then sets up the segment for the host and opens the menu.
mob_run_plane_segment(segment)
{
    // Timescale 10 from map load (the black screen and the opening afterlife
    // too) until the start round begins (mob_plane_setup).
    setdvar("timescale", SETUP_TIMESCALE);
    level thread mob_plane_round(segment);
    level thread mob_split_timer(segment.split, ::practice_start_time_start_clock);
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
    player = get_players()[0];
    player mob_plane_setup(segment);
}

// Skips straight to the start round (core practice_set_round, as O-Prac's
// segment starts do). In solo, Brutus never spawns before round 9, so the
// plane rounds need no Brutus catch-up.
mob_plane_round(segment)
{
    switch(segment.start_zombies)
    {
        case START_ZOMBIES_RANDOM: zombies = randomintrange(1, 5); break;
        case START_ZOMBIES_FULL:   zombies = undefined; break;
        default:                   zombies = segment.start_zombies; break;
    }
    practice_set_round(segment.start_round, zombies);
}

// Fully automatic: the work only a ghost can do while the game's opening
// afterlife lasts, a scripted revive, then the rest with the body, all at
// timescale 10 until the start round begins.
mob_plane_setup(segment)
{
    self endon("disconnect");
    setdvar("g_speed", 0);

    // Ghost: the afterlife boxes need lightning hands, which a ghost has.
    iprintln("Plane setup: afterlife");
    self mob_wait_for_afterlife();
    self mob_unlock_afterlife_doors();
    mob_activate_generators();
    mob_complete_code();
    level notify("cell_1_powerup_activate");
    level notify("laundry_power_switch_afterlife");
    mob_run_dryer_skipped(); // After laundry power: vanilla sets dryer_stage 1 on it.
    level notify("cable_puzzle_gate_afterlife");
    level notify("gondola_powered_on_roof");
    mob_plane_wolves(segment);
    iprintln("Plane setup: revive");
    self mob_revive_from_afterlife();
    iprintln("Plane setup: doors and parts");

    // Body: buying doors, the key and items need a player who is not a ghost
    // (vanilla is_player_valid_afterlife).
    was_demigod = is_true(self.demigod);
    if(!was_demigod) self toggle_demigod();
    // The loadout as soon as the player is a body again.
    self mob_give_weapon("mp5k_zm");
    foreach(perk in segment.perks)
        if(!self hasperk(perk))
            self maps\mp\zombies\_zm_perks::give_perk(perk, 0);
    mob_open_zombie_doors(array(DOOR_SPAWN_M14, DOOR_CAFE_TRAP, DOOR_CAFE_STAIRS, DOOR_DRYER, DOOR_CODES, DOOR_GEN_LEFT, DOOR_MP5_CATWALK, DOOR_CITADEL, DOOR_DOCKS_WOLF));
    self mob_complete_key_quest();
    self mob_open_key_locks();
    self mob_open_elevator();
    self mob_get_plane_parts();
    if(segment.cycles > 0)
        self mob_complete_plane_cycles(segment.cycles);
    else if(segment.prebuilt)
        self mob_build_plane_ready();
    if(segment.tomahawk)
        self mob_give_tomahawk();
    self setorigin(ROOF_SPOT);

    while(level.round_number < segment.start_round)
        level waittill("start_of_round");

    setdvar("timescale", 1);
    wait 0.5; // Normal speed for 500 ms before the player can move.
    setdvar("g_speed", 190);
    flag_set("plane_released"); // Phased checks start (mob_plane_install).
    if(isdefined(segment.on_start)) self [[ segment.on_start ]]();
    if(!was_demigod) self toggle_demigod();
    iprintlnbold("^3Segment started");
}

// Plane 1's route: the roof catcher full and the docks one part way; later
// planes have every catcher full.
mob_plane_wolves(segment)
{
    if(segment.all_wolves)
    {
        mob_fill_wolves();
        return;
    }
    mob_fill_wolf(WOLF_ROOF, WOLF_SOULS);
    souls = segment.docks_souls;
    if(souls < 1) souls = randomintrange(4, 7);
    mob_fill_wolf(WOLF_DOCKS, souls);
}

/*##############################################################################
                              Plane cycles already done (Plane 2 and 3)
##############################################################################*/
// Builds the plane, then leaves the game as vanilla does after a completed
// trip to the bridge: quest count raised, perks unlocked and the plane reset
// for fuel, then refuels it (vanilla zm_alcatraz_sq track_quest_status_thread,
// bestow_quest_rewards and prep_for_new_quest). The trip itself is not flown.
mob_complete_plane_cycles(cycles)
{
    self mob_build_plane();
    wait 0.05;

    level.n_quest_iteration_count = 1 + cycles;
    level.someone_has_visited_nml = 1;
    level notify("unlock_all_perk_machines");
    level notify("intro_powerup_restored");
    level.n_plane_fuel_count = 0;
    flag_clear("plane_built");
    level thread mob_plane_refuel(self);
}

// Crafts the plane from its five parts, as using the build table does.
mob_build_plane()
{
    self mob_craft_pieces("plane", array("cloth", "fueltanks", "engine", "steering", "rigging"));
}

// Builds the plane and finishes it as the build table does: vanilla
// onfullycrafted_plane sets plane_built, plays the escape VO and stops the roof
// nag. "plane_crafted" from player_craft lets plane_fly_trigger_thread turn the
// take-off trigger on (fuel is already 5 for the first flight).
mob_build_plane_ready()
{
    self mob_build_plane();
    maps\mp\zm_alcatraz_craftables::onfullycrafted_plane(self);
}

// The tail of vanilla track_quest_status_thread's loop, which only runs after a
// real trip, with the five fuel tanks taken and poured in for the player: the
// plane only needs boarding. If the refuel cannot be done (no fuel craftable
// yet), it waits for the player to refuel, as vanilla does.
mob_plane_refuel(player)
{
    maps\mp\zm_alcatraz_sq::prep_for_new_quest();
    wait 0.05;  // planefuelable_think registers the fuel table on spawn_fuel_tanks.
    uts = player mob_craft_pieces("refuelable_plane", array("fuel1", "fuel2", "fuel3", "fuel4", "fuel5"));
    if(isdefined(uts) && is_true(uts.crafted))
        uts maps\mp\zm_alcatraz_craftables::onfullycrafted_refueled(player);
    else
        maps\mp\zombies\_zm_craftables::waittill_crafted("refuelable_plane");
    maps\mp\zombies\_zm_ai_brutus::transfer_plane_trigger("fuel", "fly");
    t_plane_fly = getent("plane_fly_trigger", "targetname");
    t_plane_fly trigger_on();
}

// Takes and crafts each piece in turn, as using the craft table does (vanilla
// player_take_piece, player_craft). Works for shared pieces (solo) and pieces
// carried one at a time (co-op). Returns the craftable's stub, or undefined.
mob_craft_pieces(craftable_name, piece_names)
{
    uts = undefined;
    foreach(uts_craftable in level.a_uts_craftables)
        if(uts_craftable.craftablestub.name == craftable_name)
            uts = uts_craftable;
    if(!isdefined(uts)) return undefined;

    foreach(piece_name in piece_names)
    {
        piece = maps\mp\zombies\_zm_craftables::get_craftable_piece(craftable_name, piece_name);
        if(!isdefined(piece) || is_true(piece.crafted)) continue;
        if(!is_true(piece.in_shared_inventory) && !(isdefined(self.current_craftable_piece) && self.current_craftable_piece == piece))
            self maps\mp\zombies\_zm_craftables::player_take_piece(piece);
        self maps\mp\zombies\_zm_craftables::player_craft(uts.craftablespawn);
    }
    return uts;
}
