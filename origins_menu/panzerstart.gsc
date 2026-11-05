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
//   Start box    the first box of the run, always full (generally Gen 5 or Mound)
//   Box souls    every other box: 0 to 29 souls, or full
//   Spawn box    where the player is released, facing that box
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
#define PANZERSTART_SCORE      10000  // Panzer Practice's points

panzerstart_initialize()
{
    // Start time presets: 9:00 to 11:00, every 5 seconds, 10:00 by default. A
    // guess at the run clock at the start of round 8.
    // Custom start time: 8 to 14 minutes.
    shared_start_time_add("release", "release", "Release", "9:00", "11:00", 5, "10:00", 8, 14);
    puzzle_rng_install(PUZZLE_RNG_ICE);
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
    segment.gems = [];
    segment.excluded_doors = undefined; // Every door open, as Panzer Practice.
    segment.generators = undefined;     // None captured.
    segment.tablet = undefined;         // Left where the map puts it.
    segment.leave_gramophone = !get_cfg_int("early_gram");
    segment.box_rewards = false;        // panzerstart_soul_boxes fills the boxes natively instead.
    segment.tank_trips = 0;
    segment.kill_plane = false;
    segment.claymore = get_cfg_int("clay");
    segment.perks = panzerstart_perks();
    segment.score = PANZERSTART_SCORE;
    // The spawn box spot is set by panzerstart_setup: the church box is only
    // known at run time.
    segment.use_exit = false;
    segment.setup = ::panzerstart_setup;
    return segment;
}

panzerstart_setup()
{
    spawn = panzerstart_boxes()[panzerstart_box_index("spawn_box")];
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
// Gen 5, both at the Mound. The church box (new) gets both too.
panzerstart_perks()
{
    switch(get_cfg_int("spawn_box"))
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

// A box setting's index, within the boxes found.
panzerstart_box_index(key)
{
    index = get_cfg_int(key);
    size = panzerstart_boxes().size;
    if(index >= size) index = size - 1;
    return index;
}

// The nearest path node at least 64 units from the box, else a spot above it.
panzerstart_box_node(origin)
{
    nodes = getnodesinradiussorted(origin, 256, 64, 128, "pathnodes");
    if(!nodes.size) nodes = getnodesinradiussorted(origin, 512, 64, 128, "pathnodes");
    if(nodes.size) return nodes[0].origin;
    return origin + (0, 0, 40);
}

// The start box is filled first, so vanilla counts it as the first box done.
// Every other box gets its souls setting: full, some souls, or untouched.
panzerstart_soul_boxes()
{
    boxes = panzerstart_boxes();
    start = panzerstart_box_index("start_box");
    if(isdefined(boxes[start].ent)) boxes[start].ent panzerstart_fill_box(self);
    wait 0.05;

    for(i = 0; i < boxes.size; i++)
    {
        if(i == start || !isdefined(boxes[i].ent)) continue;
        souls = get_cfg_int(boxes[i].key);
        if(souls >= PANZERSTART_BOX_SOULS) boxes[i].ent panzerstart_fill_box(self);
        else if(souls > 0) boxes[i].ent thread panzerstart_prefill_box(self, souls);
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

panzerstart_souls_text(key)
{
    souls = get_cfg_int(key);
    if(souls >= PANZERSTART_BOX_SOULS) return "^2full";
    return "^3" + souls;
}

/*##############################################################################
                              Hud Info (from Panzer Practice)
##############################################################################*/
panzerstart_slowed_hud()
{
    level.slew = self createFontString("default", 1.3);
    level.slew setpoint("LEFT", "LEFT", "LEFT", -105);
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
    level.comp setpoint("LEFT", "LEFT", "LEFT", -120);
    level.comp.label = &"Complex behaviors: ^6";
    level.comp.alpha = 1;

    level.p_hp = createServerFontString("default", 1.3);
    level.p_hp setpoint("LEFT", "LEFT", "LEFT", -15);
    level.p_hp.label = &"HP: ^6";
    level.p_hp.alpha = 1;

    level.p_mask = createServerFontString("default", 1.3);
    level.p_mask setpoint("LEFT", "LEFT", "LEFT", 0);
    level.p_mask.label = &"MASK: ^6";
    level.p_mask.alpha = 1;

    level.p_power = createServerFontString("default", 1.3);
    level.p_power setpoint("LEFT", "LEFT", "LEFT", 15);
    level.p_power.label = &"POWERPLANT COVER: ^6";
    level.p_power.alpha = 1;

    level.p_power_d = createServerFontString("default", 1.3);
    level.p_power_d setpoint("LEFT", "LEFT", "LEFT", 30);
    level.p_power_d.label = &"POWERPLANT: ^6";
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
    start = panzerstart_box_index("start_box");
    spawn = panzerstart_box_index("spawn_box");
    last = boxes.size - 1;

    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        self shared_start_time_menu(settings);
        create_option(settings, "Start box: ^3" + boxes[start].label, ::cfg_increment_int, "start_box", array(0, last));
        create_option(settings, "Spawn box: ^3" + boxes[spawn].label, ::cfg_increment_int, "spawn_box", array(0, last));
        // The start box is always full, so it has no souls row.
        for(i = 0; i < boxes.size; i++)
            if(i != start) create_option(settings, boxes[i].label + " box: " + panzerstart_souls_text(boxes[i].key), ::cfg_increment_int, boxes[i].key, array(0, PANZERSTART_BOX_SOULS));
        add_cfg_toggle(settings, "Early Gram", "early_gram", "^2yes", "^1no");
        add_cfg_toggle(settings, "Claymore", "clay");
        add_cfg_toggle(settings, "Hud Info", "hud");

    self shared_build_segment_menus(root);
}

panzerstart_default_cfg()
{
    settings_ar = [];

    // Boxes: 0 Gen 4, 1 Gen 5, 2 Mound, 3 Church. Souls: 0 to 29, or
    // PANZERSTART_BOX_SOULS for full. Defaults are Panzer Practice's setup
    // (filling Gen 4 with 10 souls, Gen 5 and Mound full, the church box empty).
    settings_ar["start_box"] = 1;   // First box of the run, always full.
    settings_ar["spawn_box"] = 0;
    settings_ar["souls_gen4"] = 10;
    settings_ar["souls_gen5"] = PANZERSTART_BOX_SOULS;
    settings_ar["souls_mound"] = PANZERSTART_BOX_SOULS;
    settings_ar["souls_church"] = 0;
    settings_ar["early_gram"] = 1;  // 1: gramophone in hand, 0: left at the mound (as Pre-Ice).
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
