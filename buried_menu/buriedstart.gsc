#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\utility_core\splits;
#include scripts\zm\buried_menu\buriedquest;
#include scripts\zm\buried_menu\buriedsplits;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Buried quest starts
##############################################################################*/
// Richtofen Wisp, Maxis Wisp, Maze Prac and Bell Start start part way through the quest. The
// quest runs as vanilla: the side's tower is built, which ends bt, then each stage
// is given what ends it. Each mode passes a struct from buried_start():
//   side          BURIED_SIDE_RICHTOFEN or BURIED_SIDE_MAXIS
//   round         the round the player starts on
//   zombies       zombies left in it, undefined for a full round
//   spot          where the player starts, undefined for the oil lamp marker
//   angles        the view the player starts with (log one with z_tools/position_hud.gsc, chat !pos)
//   past_lamp     the lamp is built and the stages go on up to ip (maze or bells)
//   fountain_bomb a time bomb set on the fountain that starts Sharpshooter
//   first_split   the next split (BURIED_SPLIT_*)
//   springpad     a built Trample Steam placed here (origin), with springpad_angles,
//                 or with springpad_hand true and no origin, held instead of placed
// Setup runs frozen and invulnerable at timescale 10, with a deadline. Open with the
// user: the loadout (Paralyzer, MP5, Time Bomb, Galvaknuckles, Vulture Aid for Richtofen) is partly a guess.

#define BURIED_START_DEADLINE_MS  300000    // Game time.
#define BURIED_LAMP_MARKER        (-275, -1160, 201) // generator_use_trigger
#define BURIED_START_TIMESCALE    10
#define BURIED_START_WATCHDOG_MS  5000      // Past the deadline, game time.

buried_start()
{
    start = spawnstruct();
    start.side = BURIED_SIDE_RICHTOFEN;
    start.round = 2;
    start.past_lamp = false;
    start.first_split = BURIED_SPLIT_TIME_TRAVEL;
    return start;
}

// The mode's initialize, before its cfg loads.
buried_start_install()
{
    flag_init("buried_start_round");
    buried_quest_install();
}

// The mode's run.
buried_start_run(start)
{
    setdvar("timescale", BURIED_START_TIMESCALE);
    level.zombie_round_start_delay = 0; // Vanilla round_start waits 2 s.
    level thread buried_start_round(start);
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
    get_players()[0] buried_start_setup(start);
}

buried_start_round(start)
{
    practice_set_round(start.round, start.zombies);
    flag_set("buried_start_round");
}

buried_start_setup(start)
{
    self endon("disconnect");
    deadline = gettime() + BURIED_START_DEADLINE_MS;
    self freezecontrols(1);
    was_demigod = is_true(self.demigod);
    if(!was_demigod) self toggle_demigod();
    self thread buried_start_watchdog(deadline, was_demigod);

    // A side finished last game has its tower pieces removed (zm_buried_sq).
    if(is_true(level.richcompleted) || is_true(level.maxcompleted))
        iprintln("^1Last game's side blocks the quest: set EE Progress to incomplete");

    self buried_start_loadout(start);
    self thread open_all_doors();

    buried_start_stage("tower");
    self buried_start_build_tower(start.side);
    buried_start_wait_stage("mta", deadline);

    buried_start_stage("amplifiers");
    buried_start_amplifiers(start.side);
    buried_start_wait_stage("gl", deadline);

    buried_start_stage("lantern");
    while(!isdefined(level.vh_lantern) && gettime() < deadline) wait 0.05;
    self buried_start_take_lantern();
    buried_start_wait_stage("ftl", deadline);
    level.sq_ftl_lantern_fuel = 10;
    flag_set("ftl_lantern_charged");

    if(start.past_lamp) self buried_start_past_lamp(start.side, deadline);

    if(isdefined(start.springpad) || is_true(start.springpad_hand))
    {
        buried_start_stage("Trample Steam");
        self buried_start_springpad(start.springpad, start.springpad_angles);
    }

    self buried_start_place(start);

    buried_start_stage("round");
    while(!flag("buried_start_round") && gettime() < deadline) wait 0.05;
    while(!get_current_zombie_count() && gettime() < deadline) wait 0.05;

    setdvar("timescale", 1);
    wait 0.5; // Normal speed for 500 ms before the player can move.
    if(is_true(start.fountain_bomb)) self buried_start_fountain_bomb();
    level notify("buried_start_released");
    self freezecontrols(0);
    if(!was_demigod) self toggle_demigod();
    practice_custom_time_start_clock();
    level thread buried_split_timer(start.first_split);
}

// A script error ends the setup thread with the player still frozen. This one
// releases the player soon after the deadline and names the step it stopped at.
buried_start_watchdog(deadline, was_demigod)
{
    self endon("disconnect");
    level endon("buried_start_released");
    while(gettime() < deadline + BURIED_START_WATCHDOG_MS) wait 0.05;
    stage = "start";
    if(isdefined(level.buried_start_stage)) stage = level.buried_start_stage;
    iprintln("^1Quest setup stuck at " + stage + ": released anyway");
    println("B-Prac: setup stuck at " + stage + ", quest stage " + level._cur_stage_name);
    setdvar("timescale", 1);
    self freezecontrols(0);
    if(!was_demigod && is_true(self.demigod)) self toggle_demigod();
}

// The setup message, also kept for the watchdog.
buried_start_stage(name)
{
    if(!isdefined(level.buried_start_t0)) level.buried_start_t0 = gettime();
    level.buried_start_stage = name;
    seconds = (gettime() - level.buried_start_t0) / 1000;
    iprintln("Quest setup: " + name + " (" + seconds + " s)");
    println("B-Prac: setup " + name + " at " + seconds + " s game time");
}

// The Trample Steam built on its table, then placed as vanilla
// equipment_drop_to_planted does, but at the spot instead of the player's feet.
buried_start_springpad(spot, angles)
{
    equipment = "equip_springpad_zm";
    foreach(stub in level.buildable_stubs)
        if(stub.equipname == "springpad_zm" && !is_true(stub.built))
            stub maps\mp\zombies\_zm_buildables::buildablestub_finish_build(self);
    wait 0.05;
    self maps\mp\zombies\_zm_equipment::equipment_buy(equipment);
    wait 0.05;
    if(!isdefined(spot)) return; // Held.
    if(isdefined(self.current_equipment) && self.current_equipment == equipment)
        self maps\mp\zombies\_zm_equipment::equipment_to_deployed(equipment);
    item = self [[ level.zombie_equipment[equipment].place_fn ]](spot, angles);
    if(!isdefined(item))
    {
        iprintln("^1Trample Steam could not be placed");
        return;
    }
    item.owner = self;
    item.original_owner = self;
    item.name = equipment;
    if(isdefined(level.equipment_planted)) self [[ level.equipment_planted ]](item, equipment, self);
    self notify("equipment_placed", item, equipment);
    self maps\mp\zombies\_zm_buildables::track_buildables_planted(item);
    print("B-Prac: Trample Steam at " + spot);
}

// As a stage is announced: vanilla sets the name in every init_stage.
buried_start_wait_stage(name, deadline)
{
    while(!(isdefined(level._cur_stage_name) && level._cur_stage_name == name) && gettime() < deadline) wait 0.05;
    if(gettime() >= deadline) iprintln("^1Quest setup timed out at " + name);
}

// Paralyzer and MP5 on both sides (user, 2026-11-10). The starting guns go first:
// vanilla weapon_give takes the current gun when the player already holds the
// weapon limit, which would drop one of the two.
buried_start_loadout(start)
{
    foreach(weapon in self getweaponslistprimaries())
        self takeweapon(weapon);
    self maps\mp\zombies\_zm_weapons::weapon_give("slowgun_zm", undefined, undefined, 0);
    self maps\mp\zombies\_zm_weapons::weapon_give("mp5k_zm", undefined, undefined, 0);
    self giveweapon("tazer_knuckles_zm");
    self maps\mp\zombies\_zm_melee_weapon::change_melee_weapon("tazer_knuckles_zm", self getcurrentweapon());
    if(self hasweapon("knife_zm")) self takeweapon("knife_zm");
    self maps\mp\zombies\_zm_melee_weapon::trigger_hide_all();
    self maps\mp\zombies\_zm_weap_time_bomb::player_give_time_bomb();
    if(start.side == BURIED_SIDE_RICHTOFEN)
        self maps\mp\zombies\_zm_perks::give_perk("specialty_nomotionsensor", 0);
    wait 0.05;
    self switchtoweapon("slowgun_zm");
}

// Each piece as a player would place it: the plant function draws it on the tower,
// and the last build ends the stage (wait_for_richtofen_tower, wait_for_maxis_tower).
buried_start_build_tower(side)
{
    name = "buried_sq_bt_m_tower";
    zone = level.sq_mtower_buildable.buildablezone;
    flag_name = "sq_is_max_tower_built";
    if(side == BURIED_SIDE_RICHTOFEN)
    {
        name = "buried_sq_bt_r_tower";
        zone = level.sq_rtower_buildable.buildablezone;
        flag_name = "sq_is_ric_tower_built";
    }

    foreach(piece in level.zombie_buildables[name].buildablepieces)
    {
        self maps\mp\zombies\_zm_buildables::player_take_piece(piece);
        if(side == BURIED_SIDE_RICHTOFEN) maps\mp\zm_buried_buildables::onuseplantobject_rtower(self);
        else maps\mp\zm_buried_buildables::onuseplantobject_mtower(self);
        self maps\mp\zombies\_zm_buildables::player_build(zone);
    }

    wait 0.05;
    if(!flag(flag_name)) self maps\mp\zombies\_zm_buildables::player_finish_buildable(zone);
}

// Richtofen fills the amplifiers, Maxis breaks them (mta_check_all_amplifier_states).
buried_start_amplifiers(side)
{
    foreach(amp in getentarray("sq_amplifier", "targetname"))
    {
        if(side == BURIED_SIDE_RICHTOFEN)
        {
            amp.amplifier_state = "filled";
            amp thread maps\mp\zm_buried_sq_mta::mta_amplifier_filled_fx();
            continue;
        }
        amp.amplifier_state = "broken";
        amp setmodel("p6_zm_bu_ether_amplifier_dmg");
        amp stoploopsound(0.1);
    }
    if(side == BURIED_SIDE_RICHTOFEN) flag_set("sq_amplifiers_on");
    else flag_set("sq_amplifiers_broken");
}

// Vanilla gl_lantern_pickup_watch, with the lantern still in the air.
buried_start_take_lantern()
{
    level notify("lantern_crashing");
    self maps\mp\zombies\_zm_buildables::player_take_piece(level.zombie_buildables["buried_sq_oillamp"].buildablepieces[0]);
    piece = self maps\mp\zombies\_zm_buildables::player_get_buildable_piece(2);
    if(isdefined(piece))
    {
        piece.sq_is_ghost_lamp = 1;
        piece.start_origin = vectorscale((0, 0, -1), 512.0);
        piece.start_angles = (0, 0, 0);
    }
    if(isdefined(level.vh_lantern.m_lantern)) level.vh_lantern.m_lantern delete();
    level.vh_lantern delete();
    flag_set("sq_gl_lantern_aquired");
}

// The lamp built, then on to ip. sq_wisp_success up first skips ts and ctw (vanilla
// sidequest_logic loops on it). Maxis's tpo then ends itself, Richtofen's has no end
// of its own to wait for here.
buried_start_past_lamp(side, deadline)
{
    buried_start_stage("lamp");
    flag_set("sq_wisp_success");
    wait 0.05;
    self maps\mp\zombies\_zm_buildables::player_build(level.sq_lamp_generator_unitrig.buildablezone);
    wait 0.05;
    if(!is_true(level.sq_lamp_generator_unitrig.built))
        self maps\mp\zombies\_zm_buildables::player_finish_buildable(level.sq_lamp_generator_unitrig.buildablezone);

    if(side == BURIED_SIDE_MAXIS)
    {
        flag_set("sq_wisp_saved_with_time_bomb");
        buried_start_wait_stage("ip", deadline);
        return;
    }

    buried_start_wait_stage("tpo", deadline);
    flag_set("sq_tpo_generator_powered");
    level notify("sq_tpo_generator_powered");
    wait 0.05;
    level notify("sq_tpo_over");
    maps\mp\zombies\_zm_sidequests::stage_completed("sq", "tpo");
    buried_start_wait_stage("ip", deadline);
}

// What throwing one does (vanilla time_bomb_think), at the fountain. The save is made
// here, last thing before the release, so the detonator comes back to this moment.
buried_start_fountain_bomb()
{
    bomb = self magicgrenadetype("time_bomb_zm", groundpos(BURIED_FOUNTAIN_BOMB + (0, 0, 64)) + (0, 0, 8), (0, 0, 0), 0);
    bomb thread maps\mp\zombies\_zm_weap_time_bomb::setup_time_bomb_detonation_model();
    maps\mp\zombies\_zm_weap_time_bomb::time_bomb_saves_data();
    bomb maps\mp\zombies\_zm_weap_time_bomb::time_bomb_model_init();
    self thread maps\mp\zombies\_zm_weap_time_bomb::swap_weapon_to_detonator(bomb);
}

// The start spot, or the path node nearest the oil lamp marker. Printed so a good
// one can be hardcoded later.
buried_start_place(start)
{
    spot = start.spot;
    if(!isdefined(spot))
    {
        spot = BURIED_LAMP_MARKER;
        nodes = getnodesinradiussorted(spot, 256, 0, 192, "pathnodes");
        if(nodes.size) spot = nodes[0].origin;
    }
    print("B-Prac: start at " + spot);
    self setorigin(spot);
    facing = vectortoangles(BURIED_LAMP_MARKER - spot);
    if(isdefined(start.angles)) self setplayerangles(start.angles);
    else if(!isdefined(start.spot)) self setplayerangles((0, facing[1], 0));
}
