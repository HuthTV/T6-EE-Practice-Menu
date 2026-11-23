#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\puzzlerng;
#include scripts\zm\origins_menu\staffutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Panzerstart
##############################################################################*/
// Round 8, Panzer 1. The soul boxes, the mound and the gramophone are set up from
// the settings, not from a fixed route (user, 2026-11-02), and everything after
// the start stays native, so the run can be played on to Freedom (splits Ice to
// Freedom). Was Panzer Practice (panzprac), an open-doors drill.
// Start Location (user, 2026-11-23, start_loc), each with its own saved settings
// (keys end in the location id, panzerstart_key): the run's box fills by then.
//   Gen 4            Mound and Gen 5 full, Gen 4 5-10 souls, church 1-5
//   Gen 5            Mound and Gen 5 full, church 1-5, Gen 4 empty (guess)
//   Mound            Gen 4 and Gen 5 full, church 1-5, Mound 5-10 (guess)
//   Fast 4 Box       Mound and Gen 4 full, church 10-20, Gen 5 empty. Robots
//                    Thor, Thor, Freya, Odin, Freya walked, round 8 starts after
//                    leaving Odin at Gen 5 (release spot a placeholder at the Gen 5
//                    box until the user checks footage)
//   Fast 4 Box v2    as Fast 4 Box with the church and Gen 4 fills swapped
// A ranged box row is a fixed count or random within its range. Every location's
// last walked robot is Freya, so the next single cycle is Odin or Thor.
//   Early Gram   mound open with the gramophone in hand, or left at the mound
// Kept from Panzer Practice: every door open, perks by spawn box, 10000 points,
// claymore, Hud Info. Not set up: generators, staff parts, plane, tank, tablet,
// challenges. After release, native: Panzer 1 on round 8 (it drops the Fire
// staff's lower part), the Templar schedule from round 10, the robots from the
// start time on. Filling the last box gives the One Inch Punch, as in a run.
// Open: Robot Intervals.xlsx has no trio before round 12, but vanilla walks a trio
// on any round divisible by 4, round 8 included, if a cycle starts during it.

// Three of the four soul boxes and Panzer Practice's spots for them. The fourth,
// the church box (nearest Gen 6), is found at run time (panzerstart_boxes).
#define PANZERSTART_BOX_GEN4_ORIGIN   (2752.62, -88.68, 151)
#define PANZERSTART_BOX_GEN5_ORIGIN   (-2138.38, -300.07, 176)
#define PANZERSTART_BOX_MOUND_ORIGIN  (667.01, 640.63, 66)
#define PANZERSTART_SPOT_GEN4         (2895, -246, 166)
#define PANZERSTART_SPOT_GEN5         (-2501, -368, 195)
#define PANZERSTART_SPOT_MOUND        (540, 795, 83)
#define PANZERSTART_BOX_SOULS  30     // vanilla box_footprint_think, also "full" in the box settings
#define PANZERSTART_ROUND      8
#define PANZERSTART_SOULS_RANDOM  -1  // a ranged box row: random within its range

// Start Location (start_loc), the order of panzerstart_loc_ids.
#define PANZERSTART_LOC_GEN4   0
#define PANZERSTART_LOC_GEN5   1
#define PANZERSTART_LOC_MOUND  2
#define PANZERSTART_LOC_FAST4  3
#define PANZERSTART_LOC_FAST4B 4
#define PANZERSTART_SCORE      10000  // Panzer Practice's points

panzerstart_initialize()
{
    // Start time presets: 9:00 to 11:00, every 5 seconds, 10:00 by default. A
    // guess at the run clock at the start of round 8.
    shared_start_time_add("release", "release", "release", "9:00", "11:00", 5, "10:00");
    puzzle_rng_install(PUZZLE_RNG_ICE);
    level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
    mode_cfg_load("panzerstart", panzerstart_default_cfg());
    shared_segment_install(panzerstart_segment());
    // No Gen 6 skip at setup: Templars come on round 10 unless the player does it.
    shared_schedules_init(10);
    shared_held_start_install();
    level.segment.upgrade_mauser = false; // No Pack-a-Punch before every generator is captured.

    // Hud Info: Panzer health rows, a vanilla copy with the HUD added.
    if(get_cfg_int("hud")) replacefunc( maps\mp\zombies\_zm_ai_mechz::mechz_spawn, ::panzerstart_mechz_spawn );
}

panzerstart_segment()
{
    segment = shared_segment();
    segment.split = SPLIT_ICE;
    segment.round = PANZERSTART_ROUND;
    segment.panzer_health_hud = true;
    segment.gems = [];
    segment.excluded_doors = undefined; // Every door open, as Panzer Practice.
    segment.generators = undefined;     // None captured.
    segment.tablet = undefined;         // Left where the map puts it.
    segment.leave_gramophone = !get_cfg_int(panzerstart_key("early_gram"));
    segment.robot_last = ROBOT_FREYA;   // the next single cycle is Odin or Thor (user, 2026-11-23)
    segment.box_rewards = false;        // panzerstart_soul_boxes fills the boxes natively instead.
    segment.tank_trips = 0;
    segment.kill_plane = false;
    segment.claymore = get_cfg_int("clay");
    segment.perks = panzerstart_perks();
    segment.score = PANZERSTART_SCORE;
    // The spawn spot is set by panzerstart_setup from the location.
    segment.use_exit = false;
    segment.setup = ::panzerstart_setup;
    return segment;
}

panzerstart_setup()
{
    spawn = panzerstart_boxes()[panzerstart_spawn_box()];
    level.segment.spots = shared_start_spots(spawn.spot, spawn.angles, spawn.spot, spawn.angles);
    self panzerstart_get_parts();
    self panzerstart_soul_boxes();
    if(get_cfg_int("hud")) self thread panzerstart_slowed_hud();
}

// The mound opening needs the gramophone and the master disc in hand, whatever
// their location settings say. Then the discs and Maxis and shield parts whose
// location is "collected".
panzerstart_get_parts()
{
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("gramophone", "vinyl_player");
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("gramophone", "vinyl_master");
    self shared_give_collected_items();
}

// Panzer Practice's perks per box it started at: Stamin-Up at Gen 4, Jugg at
// Gen 5 (Fast 4 Box too, released there), both at the Mound.
panzerstart_perks()
{
    switch(panzerstart_spawn_box())
    {
        case 0:  return array("specialty_longersprint");
        case 1:  return array("specialty_armorvest");
        default: return array("specialty_longersprint", "specialty_armorvest");
    }
}

/*##############################################################################
                              Soul boxes
##############################################################################*/
// The four soul boxes in menu order: Gen 4, Gen 5, Mound, Church. The church box
// (user, 2026-11-02: the one nearest Gen 6) is the foot_box none of the known
// origins matches, the player on a path node next to it (traced, so its origin
// and spot can be hardcoded later). Read once, before setup fills and deletes
// any box. Entries: key (its souls setting), label, ent, origin, spot, angles.
panzerstart_boxes()
{
    if(isdefined(level.panzerstart_boxes)) return level.panzerstart_boxes;

    boxes = [];
    boxes[0] = panzerstart_box_entry("souls_gen4", "Gen 4", PANZERSTART_BOX_GEN4_ORIGIN, PANZERSTART_SPOT_GEN4);
    boxes[1] = panzerstart_box_entry("souls_gen5", "Gen 5", PANZERSTART_BOX_GEN5_ORIGIN, PANZERSTART_SPOT_GEN5);
    boxes[2] = panzerstart_box_entry("souls_mound", "Mound", PANZERSTART_BOX_MOUND_ORIGIN, PANZERSTART_SPOT_MOUND);

    foreach(ent in getentarray("foot_box", "script_noteworthy"))
    {
        known = undefined;
        foreach(box in boxes)
            if(distancesquared(ent.origin, box.origin) < 64 * 64) known = box;
        if(isdefined(known))
        {
            known.ent = ent;
            continue;
        }
        church = panzerstart_box_entry("souls_church", "Church", ent.origin, panzerstart_box_node(ent.origin));
        church.ent = ent;
        boxes[boxes.size] = church;
        shared_setup_trace("church soul box at " + ent.origin + ", spot " + church.spot);
    }

    level.panzerstart_boxes = boxes;
    return boxes;
}

panzerstart_box_entry(key, label, origin, spot)
{
    box = spawnstruct();
    box.key = key;
    box.label = label;
    box.origin = origin;
    box.spot = spot;
    box.angles = (0, vectortoangles(origin - spot)[1], 0);
    return box;
}

/*##############################################################################
                              Start Location
##############################################################################*/
panzerstart_loc_ids()
{
    return array("gen4", "gen5", "mound", "fast4", "fast4b");
}

panzerstart_loc_labels()
{
    return array("Gen 4", "Gen 5", "Mound", "fast 4 box", "fast 4 box v2");
}

panzerstart_loc()
{
    loc = get_cfg_int("start_loc");
    if(loc < 0 || loc >= panzerstart_loc_ids().size) loc = PANZERSTART_LOC_GEN4;
    return loc;
}

// A per-location setting's key: name plus the location id.
panzerstart_key(name, loc)
{
    if(!isdefined(loc)) loc = panzerstart_loc();
    return name + "_" + panzerstart_loc_ids()[loc];
}

// The box (index into panzerstart_boxes) the player is released at, facing it.
panzerstart_spawn_box(loc)
{
    if(!isdefined(loc)) loc = panzerstart_loc();
    if(loc == PANZERSTART_LOC_GEN4) return 0;
    if(loc == PANZERSTART_LOC_MOUND) return 2;
    return 1; // Gen 5, and Fast 4 Box's placeholder at the Gen 5 box
}

// (lo, hi) souls of box i (0 Gen 4, 1 Gen 5, 2 Mound, 3 Church) at a location.
// lo == hi is a fixed fill (PANZERSTART_BOX_SOULS full, 0 untouched), else a row.
panzerstart_box_range(loc, i)
{
    full = PANZERSTART_BOX_SOULS;
    if(loc == PANZERSTART_LOC_GEN4) ranges = array(array(5, 10), array(full, full), array(full, full), array(1, 5));
    else if(loc == PANZERSTART_LOC_GEN5) ranges = array(array(0, 0), array(full, full), array(full, full), array(1, 5));
    else if(loc == PANZERSTART_LOC_MOUND) ranges = array(array(full, full), array(full, full), array(5, 10), array(1, 5));
    else if(loc == PANZERSTART_LOC_FAST4) ranges = array(array(full, full), array(0, 0), array(full, full), array(10, 20));
    else ranges = array(array(10, 20), array(0, 0), array(full, full), array(full, full));
    return ranges[i];
}

// Souls box i gets at setup: the fixed fill, the row's count, or a roll within its range.
panzerstart_box_souls(i)
{
    range = panzerstart_box_range(panzerstart_loc(), i);
    if(range[0] == range[1]) return range[0];
    souls = get_cfg_int(panzerstart_key(panzerstart_boxes()[i].key));
    if(souls < range[0] || souls > range[1]) souls = randomintrange(range[0], range[1] + 1);
    return souls;
}

// A ranged box row steps random, lo, ..., hi, random.
panzerstart_souls_step(key, range)
{
    value = get_cfg_int(key);
    if(value < range[0] || value > range[1]) next = range[0];
    else if(value == range[1]) next = PANZERSTART_SOULS_RANDOM;
    else next = value + 1;
    self cfg_set_int(key, next);
}

panzerstart_full_box_left(boxes, souls)
{
    for(i = 0; i < souls.size; i++)
        if(souls[i] >= PANZERSTART_BOX_SOULS && isdefined(boxes[i].ent)) return true;
    return false;
}

panzerstart_souls_row_text(key, range)
{
    value = get_cfg_int(key);
    if(value < range[0] || value > range[1]) return "^3random ^7(" + range[0] + "-" + range[1] + ")";
    return "^3" + value;
}

panzerstart_fill_text(souls)
{
    if(souls >= PANZERSTART_BOX_SOULS) return "full";
    if(souls <= 0) return "empty";
    return "" + souls;
}

// The fixed fills line only lists the location's boxes.
panzerstart_no_action()
{
}

// The nearest path node at least 64 units from the box, else a spot above it.
panzerstart_box_node(origin)
{
    nodes = getnodesinradiussorted(origin, 256, 64, 128, "pathnodes");
    if(!nodes.size) nodes = getnodesinradiussorted(origin, 512, 64, 128, "pathnodes");
    if(nodes.size) return nodes[0].origin;
    return origin + (0, 0, 40);
}

// The full boxes first, one frame apart (vanilla counts them in that order, no
// box's place in it is observable), then the partly filled ones.
panzerstart_soul_boxes()
{
    boxes = panzerstart_boxes();
    souls = [];
    for(i = 0; i < boxes.size && i < 4; i++) souls[i] = panzerstart_box_souls(i);

    for(i = 0; i < souls.size; i++)
    {
        if(!isdefined(boxes[i].ent) || souls[i] < PANZERSTART_BOX_SOULS) continue;
        boxes[i].ent panzerstart_fill_box(self);
        wait 0.05;
    }
    // A full box finishes natively (rise, stat, Richtofen's line, deleted) about 5 s later: before the release
    for(t = 0; t < 200 && panzerstart_full_box_left(boxes, souls); t++) wait 0.05;
    for(i = 0; i < souls.size; i++)
    {
        if(!isdefined(boxes[i].ent) || souls[i] <= 0 || souls[i] >= PANZERSTART_BOX_SOULS) continue;
        boxes[i].ent thread panzerstart_prefill_box(self, souls[i]);
        shared_setup_trace(boxes[i].label + " box prefilled with " + souls[i] + " souls");
    }
}

// Vanilla box_footprint_think counts one soul per notify and finishes at
// PANZERSTART_BOX_SOULS, so one notify after one short of it runs the box's own
// completion (removal, challenge stat, VO).
panzerstart_fill_box(player)
{
    self.n_souls_absorbed = PANZERSTART_BOX_SOULS - 1;
    self notify("soul_absorbed", player);
}

// The first soul opens the box (vanilla), then the count jumps to souls.
panzerstart_prefill_box(player, souls)
{
    self notify("soul_absorbed", player);
    wait 0.05;
    self.n_souls_absorbed = souls;
}

/*##############################################################################
                              Hud Info (from Panzer Practice)
##############################################################################*/
panzerstart_slowed_hud()
{
    level.slew = self createFontString("default", 1.3);
    level.slew setpoint("LEFT", "LEFT", 0, -105);
    level.slew.label = &"Slowed: ^6";
    level.slew.alpha = 1;

    while(true)
    {
        level.slew setvalue(self.is_player_slowed);
        wait 0.05;
    }
}

// self is the Panzer.
panzerstart_mechz_hud()
{
    level.comp = createServerFontString("default", 1.3);
    level.comp setpoint("LEFT", "LEFT", 0, -120);
    level.comp.label = &"Complex AI: ^6";
    level.comp.alpha = 1;

    level.p_hp = createServerFontString("default", 1.3);
    level.p_hp setpoint("LEFT", "LEFT", 0, -15);
    level.p_hp.label = &"HP: ^6";
    level.p_hp.alpha = 1;

    level.p_mask = createServerFontString("default", 1.3);
    level.p_mask setpoint("LEFT", "LEFT", 0, 0);
    level.p_mask.label = &"Mask: ^6";
    level.p_mask.alpha = 1;

    level.p_power = createServerFontString("default", 1.3);
    level.p_power setpoint("LEFT", "LEFT", 0, 15);
    level.p_power.label = &"Power Cover: ^6";
    level.p_power.alpha = 1;

    level.p_power_d = createServerFontString("default", 1.3);
    level.p_power_d setpoint("LEFT", "LEFT", 0, 30);
    level.p_power_d.label = &"Power: ^6";
    level.p_power_d.alpha = 1;

    while(self.health > 0)
    {
        level.comp setvalue(1 - self.disable_complex_behaviors);
        level.p_hp setvalue(max(self.health, 0));
        level.p_mask setvalue(max(self.helmet_dmg_for_removal - self.helmet_dmg, 0));
        level.p_power setvalue(max(self.powerplant_cover_dmg_for_removal - self.powerplant_cover_dmg, 0));
        level.p_power_d setvalue(max(self.powerplant_dmg_for_destroy - self.powerplant_dmg, 0));
        wait 0.05;
    }

    level.p_hp setvalue(0);
    level.p_mask setvalue(0);
    level.p_power setvalue(0);
    level.p_power_d setvalue(0);
}

panzerstart_mechz_spawn() // OVERRIDE: maps\mp\zombies\_zm_ai_mechz::mechz_spawn (Hud Info only)
{
    self maps\mp\zombies\_zm_ai_mechz_ffotd::spawn_start();
    self endon( "death" );
    level endon( "intermission" );
    self maps\mp\zombies\_zm_ai_mechz::mechz_attach_objects();
    self maps\mp\zombies\_zm_ai_mechz::mechz_set_starting_health();
    self maps\mp\zombies\_zm_ai_mechz::mechz_setup_fx();
    self maps\mp\zombies\_zm_ai_mechz::mechz_setup_snd();
    level notify( "sam_clue_mechz", self );
    self.closest_player_override = maps\mp\zombies\_zm_ai_mechz::get_favorite_enemy;
    self.animname = "mechz_zombie";
    self.has_legs = 1;
    self.no_gib = 1;
    self.ignore_all_poi = 1;
    self.is_mechz = 1;
    self.ignore_enemy_count = 1;
    self.no_damage_points = 1;
    self.melee_anim_func = maps\mp\zombies\_zm_ai_mechz::melee_anim_func;
    self.meleedamage = 75;
    self.custom_item_dmg = 2000;
    recalc_zombie_array();
    self setphysparams( 20, 0, 80 );
    self setcandamage( 0 );
    self.zombie_init_done = 1;
    self notify( "zombie_init_done" );
    self.allowpain = 0;
    self animmode( "normal" );
    self orientmode( "face enemy" );
    self maps\mp\zombies\_zm_spawner::zombie_setup_attack_properties();
    self.completed_emerging_into_playable_area = 1;
    self notify( "completed_emerging_into_playable_area" );
    self.no_powerups = 0;
    self setfreecameralockonallowed( 0 );
    self notsolid();
    self thread maps\mp\zombies\_zm_spawner::zombie_eye_glow();
    level thread maps\mp\zombies\_zm_spawner::zombie_death_event( self );
    self thread maps\mp\zombies\_zm_spawner::enemy_death_detection();

    if ( level.zombie_mechz_locations.size )
        spawn_pos = self maps\mp\zombies\_zm_ai_mechz::get_best_mechz_spawn_pos();

    if ( !isdefined( spawn_pos ) )
    {
        self delete();
        return;
    }

    if ( isdefined( level.mechz_force_spawn_pos ) )
    {
        spawn_pos = level.mechz_force_spawn_pos;
        level.mechz_force_spawn_pos = undefined;
    }

    if ( !isdefined( spawn_pos.angles ) )
        spawn_pos.angles = ( 0, 0, 0 );

    self thread maps\mp\zombies\_zm_ai_mechz::mechz_death();
    self forceteleport( spawn_pos.origin, spawn_pos.angles );
    self playsound( "zmb_ai_mechz_incoming_alarm" );

    if ( !isdefined( spawn_pos.angles ) )
        spawn_pos.angles = ( 0, 0, 0 );

    self animscripted( spawn_pos.origin, spawn_pos.angles, "zm_spawn" );
    self maps\mp\animscripts\zm_shared::donotetracks( "jump_anim" );
    self setfreecameralockonallowed( 1 );
    self solid();
    self set_zombie_run_cycle( "walk" );

    if ( isdefined( level.mechz_find_flesh_override_func ) )
        level thread [[ level.mechz_find_flesh_override_func ]]();
    else
        self thread maps\mp\zombies\_zm_ai_mechz::mechz_find_flesh();

    self thread maps\mp\zombies\_zm_ai_mechz_booster::mechz_jump_think( spawn_pos );
    self setcandamage( 1 );
    self maps\mp\zombies\_zm_ai_mechz::init_anim_rate();
    self maps\mp\zombies\_zm_ai_mechz_ffotd::spawn_end();

    //MODIFIED: Hud Info
    self thread panzerstart_mechz_hud();
}

/*##############################################################################
                              Menu
##############################################################################*/
panzerstart_build_menu(root)
{
    boxes = panzerstart_boxes();
    loc = panzerstart_loc();
    ids = panzerstart_loc_ids();
    values = [];
    for(i = 0; i < ids.size; i++) values[i] = i;

    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        shared_add_location_choice(settings, "start_loc", values, panzerstart_loc_labels());
        self shared_start_time_menu(settings);
        // Ranged boxes get a row, the fixed ones are listed on one line under them.
        fixed = "";
        for(i = 0; i < boxes.size && i < 4; i++)
        {
            range = panzerstart_box_range(loc, i);
            if(range[0] == range[1])
            {
                if(fixed != "") fixed = fixed + ", ";
                fixed = fixed + boxes[i].label + " " + panzerstart_fill_text(range[0]);
                continue;
            }
            key = panzerstart_key(boxes[i].key);
            create_option(settings, boxes[i].label + " Souls: " + panzerstart_souls_row_text(key, range), ::panzerstart_souls_step, key, range);
        }
        create_option(settings, "Boxes: ^3" + fixed, ::panzerstart_no_action);
        add_cfg_toggle(settings, "Gram", panzerstart_key("early_gram"), "^2in hand", "^3placed");

    self shared_build_categories(root);
    add_cfg_toggle("loadout", "Claymore", "clay");
    self shared_build_segment_menus();
}

panzerstart_default_cfg()
{
    settings_ar = [];

    // Start Location (PANZERSTART_LOC_*), then per location (panzerstart_key):
    // each ranged box's souls (PANZERSTART_SOULS_RANDOM or a count in its range,
    // panzerstart_box_range) and Early Gram. The old start_box, spawn_box and
    // souls_* keys from before the locations are no longer read.
    settings_ar["start_loc"] = PANZERSTART_LOC_GEN4;
    box_keys = array("souls_gen4", "souls_gen5", "souls_mound", "souls_church");
    for(loc = 0; loc < panzerstart_loc_ids().size; loc++)
    {
        for(i = 0; i < box_keys.size; i++)
        {
            range = panzerstart_box_range(loc, i);
            if(range[0] != range[1]) settings_ar[panzerstart_key(box_keys[i], loc)] = PANZERSTART_SOULS_RANDOM;
        }
        settings_ar[panzerstart_key("early_gram", loc)] = 1; // 1: gramophone in hand, 0: left at the mound (as Pre-Ice).
    }
    settings_ar["clay"] = 1;
    settings_ar["hud"] = 0;         // Slowed and Panzer health rows.
    settings_ar["stg_start"] = STG_NO;
    settings_ar["trioskip"] = 0;    // Every start time is before the round 12 trio cycle.
    settings_ar = shared_start_time_defaults(settings_ar);
    settings_ar = shared_part_defaults(settings_ar);

    settings_ar = shared_schedule_defaults(settings_ar);
    settings_ar = shared_relay_defaults(settings_ar, false);
    settings_ar = shared_robot_defaults(settings_ar, FOOT_LEFT);
    settings_ar = shared_disc_defaults(settings_ar, 1);
    settings_ar = puzzle_rng_defaults(settings_ar);
    return settings_ar;
}
