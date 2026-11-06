#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\splits;
#inline scripts\zm\dierise_menu\dierise;

/*##############################################################################
                              Die Rise Fullgame
##############################################################################*/
// A normal game from round 1 with the run's RNG set: the spawn building's perk,
// the blue building's perk elevators, where each Trample Steam part spawns, and
// the final tower code (the order the tower's sides are punched).

#define SPAWN_PERK_RANDOM       0
#define SPAWN_PERK_SPEED_COLA   1
#define SPAWN_PERK_WHOS_WHO     2

#define ELEVATOR_UP_RANDOM  0

#define PART_RANDOM     0
#define PART_SPAWN      1
#define PART_OUTSIDE    2

#define START_ORIGIN    (1464, 1377, 3397)  // Where a game starts, to tell the part spots apart.

#define TOWER_SIDES     4

dierisefullgame_initialize()
{
    replacefunc(maps\mp\zm_highrise_elevators::init_elevator_perks, ::dierisefullgame_init_elevator_perks);
    replacefunc(maps\mp\zm_highrise_elevators::init_elevator, ::dierisefullgame_init_elevator);
    replacefunc(maps\mp\zombies\_zm_buildables::generate_zombie_buildable_piece, ::dierisefullgame_generate_zombie_buildable_piece);
    replacefunc(maps\mp\zm_highrise_sq::mahjong_tiles_setup, ::dierisefullgame_mahjong_tiles_setup);
    mode_cfg_load("dierisefullgame", dierisefullgame_default_cfg());
}

dierisefullgame_run()
{
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
    level thread dierisefullgame_splits();
}

// The B2EE timer's Die Rise splits (wait_for_split).
dierisefullgame_splits()
{
    level endon("end_game");
    practice_splits_start(array("^3Symbols ^7", "^3High Maintenance ^7"), 0);
    flag_wait("sq_atd_drg_puzzle_complete");
    practice_split(0);
    level waittill("sq_fireball_hit_player");
    practice_split(1);
}

dierisefullgame_default_cfg()
{
    settings_ar = [];
    settings_ar["spawn_perk"] = SPAWN_PERK_RANDOM;
    settings_ar["elevator_up"] = ELEVATOR_UP_RANDOM;
    foreach(elevator in dierisefullgame_perk_elevators())
        settings_ar[elevator.key] = 0;
    foreach(part in dierisefullgame_springpad_parts())
        settings_ar[part.key] = PART_RANDOM;
    for(i = 1; i <= TOWER_SIDES; i++)
        settings_ar["tower_leg_" + i] = 0;
    return settings_ar;
}

dierisefullgame_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_choice(settings, "Spawn Building Perk", "spawn_perk", array("random", "Speed Cola", "Who's Who"));

        elevators = add_submenu(settings, "elevators", "Elevators", "Elevators");
            add_cfg_choice(elevators, "Sweatshop Elevator Up", "elevator_up", array("random", "left", "right"));
            perks = array("random");
            foreach(perk in dierisefullgame_elevator_perks())
                perks[perks.size] = perk.label;
            foreach(elevator in dierisefullgame_perk_elevators())
                add_cfg_choice(elevators, elevator.label, elevator.key, perks);

        parts = add_submenu(settings, "springpad", "Trample Parts", "Trample Parts");
            foreach(part in dierisefullgame_springpad_parts())
                add_cfg_choice(parts, part.label, part.key, array("random", "spawn", "outside"));

        tower = add_submenu(settings, "tower", "Tower Code", "Tower Code");
            winds = array("random", "north", "south", "east", "west");
            for(i = 1; i <= TOWER_SIDES; i++)
                add_cfg_choice(tower, "Side " + i, "tower_leg_" + i, winds);
}

/*##############################################################################
                              Spawn building perk
##############################################################################*/
// Slot 1 of level.elevator_perks is the spawn building's elevator after Quick
// Revive: vanilla flips a coin between Who's Who (a = 1) and Speed Cola (a = 2),
// the other perk joins the blue building's shuffle.

// OVERRIDE: maps\mp\zm_highrise_elevators::init_elevator_perks
dierisefullgame_init_elevator_perks()
{
    level.elevator_perks = [];
    level.elevator_perks_building = [];
    level.elevator_perks_building["green"] = [];
    level.elevator_perks_building["blue"] = [];
    level.elevator_perks_building["green"][0] = spawnstruct();
    level.elevator_perks_building["green"][0].model = "zombie_vending_revive";
    level.elevator_perks_building["green"][0].script_noteworthy = "specialty_quickrevive";
    level.elevator_perks_building["green"][0].turn_on_notify = "revive_on";
    a = 1;
    b = 2;

    //MODIFIED: the Spawn Building Perk setting replaces the coin flip.
    choice = get_cfg_int( "spawn_perk" );

    if ( choice == SPAWN_PERK_SPEED_COLA || choice == SPAWN_PERK_RANDOM && randomint( 100 ) > 50 )
    {
        a = 2;
        b = 1;
    }
    //MODIFIED END

    level.elevator_perks_building["green"][a] = spawnstruct();
    level.elevator_perks_building["green"][a].model = "p6_zm_vending_chugabud";
    level.elevator_perks_building["green"][a].script_noteworthy = "specialty_finalstand";
    level.elevator_perks_building["green"][a].turn_on_notify = "chugabud_on";
    level.elevator_perks_building["green"][b] = spawnstruct();
    level.elevator_perks_building["green"][b].model = "zombie_vending_sleight";
    level.elevator_perks_building["green"][b].script_noteworthy = "specialty_fastreload";
    level.elevator_perks_building["green"][b].turn_on_notify = "sleight_on";
    level.elevator_perks_building["blue"][0] = spawnstruct();
    level.elevator_perks_building["blue"][0].model = "zombie_vending_three_gun";
    level.elevator_perks_building["blue"][0].script_noteworthy = "specialty_additionalprimaryweapon";
    level.elevator_perks_building["blue"][0].turn_on_notify = "specialty_additionalprimaryweapon_power_on";
    level.elevator_perks_building["blue"][1] = spawnstruct();
    level.elevator_perks_building["blue"][1].model = "zombie_vending_jugg";
    level.elevator_perks_building["blue"][1].script_noteworthy = "specialty_armorvest";
    level.elevator_perks_building["blue"][1].turn_on_notify = "juggernog_on";
    level.elevator_perks_building["blue"][2] = spawnstruct();
    level.elevator_perks_building["blue"][2].model = "zombie_vending_doubletap2";
    level.elevator_perks_building["blue"][2].script_noteworthy = "specialty_rof";
    level.elevator_perks_building["blue"][2].turn_on_notify = "doubletap_on";
    level.elevator_perks_building["blue"][3] = spawnstruct();
    level.elevator_perks_building["blue"][3].model = "p6_anim_zm_buildable_pap";
    level.elevator_perks_building["blue"][3].script_noteworthy = "specialty_weapupgrade";
    level.elevator_perks_building["blue"][3].turn_on_notify = "Pack_A_Punch_on";
    players_expected = getnumexpectedplayers();
    level.override_perk_targetname = "zm_perk_machine_override";
    level.elevator_perks_building["blue"] = array_randomize( level.elevator_perks_building["blue"] );
    level.elevator_perks = arraycombine( level.elevator_perks_building["green"], level.elevator_perks_building["blue"], 0, 0 );
    random_perk_structs = [];
    revive_perk_struct = getstruct( "force_quick_revive", "targetname" );
    revive_perk_struct = getstruct( revive_perk_struct.target, "targetname" );
    perk_structs = getstructarray( "zm_random_machine", "script_noteworthy" );

    for ( i = 0; i < perk_structs.size; i++ )
    {
        random_perk_structs[i] = getstruct( perk_structs[i].target, "targetname" );
        random_perk_structs[i].script_parameters = perk_structs[i].script_parameters;
        random_perk_structs[i].script_linkent = getent( "elevator_" + perk_structs[i].script_parameters + "_body", "targetname" );
    }

    green_structs = [];
    blue_structs = [];

    foreach ( perk_struct in random_perk_structs )
    {
        if ( isdefined( perk_struct.script_parameters ) )
        {
            if ( issubstr( perk_struct.script_parameters, "bldg1" ) )
            {
                green_structs[green_structs.size] = perk_struct;
                continue;
            }

            blue_structs[blue_structs.size] = perk_struct;
        }
    }

    green_structs = array_exclude( green_structs, revive_perk_struct );
    green_structs = array_randomize( green_structs );
    blue_structs = array_randomize( blue_structs );
    level.random_perk_structs = array( revive_perk_struct );
    level.random_perk_structs = arraycombine( level.random_perk_structs, green_structs, 0, 0 );
    level.random_perk_structs = arraycombine( level.random_perk_structs, blue_structs, 0, 0 );

    //MODIFIED: the Elevators settings pin perks after both shuffles.
    dierisefullgame_pin_elevator_perks();
    //MODIFIED END

    for ( i = 0; i < level.elevator_perks.size; i++ )
    {
        if ( !isdefined( level.random_perk_structs[i] ) )
            continue;

        level.random_perk_structs[i].targetname = "zm_perk_machine_override";
        level.random_perk_structs[i].model = level.elevator_perks[i].model;
        level.random_perk_structs[i].script_noteworthy = level.elevator_perks[i].script_noteworthy;
        level.random_perk_structs[i].turn_on_notify = level.elevator_perks[i].turn_on_notify;

        if ( !isdefined( level.struct_class_names["targetname"]["zm_perk_machine_override"] ) )
            level.struct_class_names["targetname"]["zm_perk_machine_override"] = [];

        level.struct_class_names["targetname"]["zm_perk_machine_override"][level.struct_class_names["targetname"]["zm_perk_machine_override"].size] = level.random_perk_structs[i];
    }
}

/*##############################################################################
                              Blue building elevators
##############################################################################*/
// The blue building's four perk elevators hold PaP, Jug, Mule and Double Tap in
// any order. Sweatshop Left and Right are the two with the start coin flip.
// Left and right read looking north at both, from the geometry only: swap the
// names of rows 0 and 1 if they are the wrong way round in game.
dierisefullgame_perk_elevators()
{
    elevators = [];
    elevators[0] = dierisefullgame_perk_elevator("elevator_left", "Sweatshop Left", "3");
    elevators[1] = dierisefullgame_perk_elevator("elevator_right", "Sweatshop Right", "3b");
    elevators[2] = dierisefullgame_perk_elevator("elevator_bottom", "Bottom", "3c");
    elevators[3] = dierisefullgame_perk_elevator("elevator_corner", "Corner", "3d");
    return elevators;
}

dierisefullgame_perk_elevator(key, label, name)
{
    elevator = spawnstruct();
    elevator.key = key;
    elevator.label = label;
    elevator.name = name;
    return elevator;
}

dierisefullgame_elevator_perks()
{
    perks = [];
    perks[0] = dierisefullgame_elevator_perk("PaP", "specialty_weapupgrade");
    perks[1] = dierisefullgame_elevator_perk("Jug", "specialty_armorvest");
    perks[2] = dierisefullgame_elevator_perk("Mule", "specialty_additionalprimaryweapon");
    perks[3] = dierisefullgame_elevator_perk("Double Tap", "specialty_rof");
    return perks;
}

dierisefullgame_elevator_perk(label, noteworthy)
{
    perk = spawnstruct();
    perk.label = label;
    perk.noteworthy = noteworthy;
    return perk;
}

// Swaps each set perk into its elevator's slot. A perk an earlier row took stays
// there and the later row counts as random, the rest keep the vanilla shuffle.
dierisefullgame_pin_elevator_perks()
{
    perks = dierisefullgame_elevator_perks();
    used = [];
    foreach(elevator in dierisefullgame_perk_elevators())
    {
        choice = get_cfg_int(elevator.key) - 1;
        if(choice < 0 || choice >= perks.size) continue;

        perk = perks[choice];
        if(isdefined(used[perk.noteworthy])) continue;
        used[perk.noteworthy] = 1;

        slot = undefined;
        for(i = 0; i < level.random_perk_structs.size; i++)
            if(level.random_perk_structs[i].script_parameters == "bldg" + elevator.name) slot = i;

        from = undefined;
        for(i = 0; i < level.elevator_perks.size; i++)
            if(level.elevator_perks[i].script_noteworthy == perk.noteworthy) from = i;

        if(!isdefined(slot) || !isdefined(from)) continue;

        temp = level.elevator_perks[slot];
        level.elevator_perks[slot] = level.elevator_perks[from];
        level.elevator_perks[from] = temp;
        println("D-Prac: " + perk.label + " on elevator " + elevator.name);
    }
}

// zm_highrise_classic main flips a coin for the two Sweatshop elevators: one
// waits up, at stop 1 with offset -1264 (136 above the other), the other at stop 2.

// OVERRIDE: maps\mp\zm_highrise_elevators::init_elevator
dierisefullgame_init_elevator( elevatorname, force_starting_floor, force_starting_origin )
{
    //MODIFIED: Sweatshop Elevator Up replaces the coin flip.
    up = get_cfg_int( "elevator_up" );

    if ( up != ELEVATOR_UP_RANDOM && ( elevatorname == "3" || elevatorname == "3b" ) )
    {
        if ( elevatorname == dierisefullgame_perk_elevators()[up - 1].name )
        {
            force_starting_floor = 1;
            force_starting_origin = -1264;
        }
        else
        {
            force_starting_floor = 2;
            force_starting_origin = undefined;
        }

        println( "D-Prac: elevator " + elevatorname + " starts at stop " + force_starting_floor );
    }
    //MODIFIED END

    if ( !isdefined( level.elevators ) )
        level.elevators = [];

    elevator = spawnstruct();
    elevator.name = elevatorname;
    elevator.body = undefined;
    level.elevators["bldg" + elevatorname] = elevator;
    piece = getent( "elevator_bldg" + elevatorname + "_body", "targetname" );
    piece setmovingplatformenabled( 1 );
    piece.is_moving = 0;

    if ( !isdefined( piece ) )
        return;

    trig = getent( "elevator_bldg" + elevatorname + "_trigger", "targetname" );

    if ( isdefined( trig ) )
    {
        trig enablelinkto();
        trig linkto( piece );
        trig setmovingplatformenabled( 1 );
        piece.trig = trig;
        piece thread maps\mp\zm_highrise_elevators::elevator_roof_watcher();
    }

    elevator.body = piece;
    piece.is_elevator = 1;
    elevator.body maps\mp\zm_highrise_elevators::perkelevatoruseanimtree();
    elevator.body.current_level = piece.script_location;
    elevator.body.starting_floor = piece.script_location;
    elevator.roof_paths = maps\mp\zm_highrise_elevators::elevator_path_nodes( "bldg" + elevatorname, "moving" );
    elevator.floors = [];
    elevator.floors[piece.script_location] = piece;
    elevator.floors[piece.script_location].starting_position = piece.origin;
    elevator.floors[piece.script_location].paths = maps\mp\zm_highrise_elevators::elevator_path_nodes( "bldg" + elevatorname, "floor" + piece.script_location );

    while ( isdefined( piece.target ) )
    {
        piece = getstruct( piece.target, "targetname" );
        piece.is_elevator = 1;

        if ( !isdefined( elevator.floors[piece.script_location] ) )
        {
            elevator.floors[piece.script_location] = piece;
            elevator.floors[piece.script_location].paths = maps\mp\zm_highrise_elevators::elevator_path_nodes( "bldg" + elevatorname, "floor" + piece.script_location );
        }
    }

    if ( elevatorname != "3c" )
        elevator.floors["" + elevator.floors.size] = elevator.floors["1"];

    if ( isdefined( force_starting_floor ) )
        elevator.body.force_starting_floor = force_starting_floor;

    if ( isdefined( force_starting_origin ) )
        elevator.body.force_starting_origin_offset = force_starting_origin;

    level thread maps\mp\zm_highrise_elevators::elevator_think( elevator );
    level thread maps\mp\zm_highrise_elevators::elevator_depart_early( elevator );
    level thread maps\mp\zm_highrise_elevators::elevator_sparks_fx( elevator );
}

/*##############################################################################
                              Trample Steam parts
##############################################################################*/
// Each piece has two spawn structs ("springpad_zm_<model>", zm_highrise_buildables,
// logged live). Spawn is the one nearer the start of the game, Outside the other:
// near spots are 180-320 units from it, far ones 575-990. The console prints each
// spot as the piece spawns ("D-Prac: Door spot 1 ...").
dierisefullgame_springpad_parts()
{
    parts = [];
    parts[0] = dierisefullgame_springpad_part("part_door", "Door", "p6_zm_buildable_tramplesteam_door");
    parts[1] = dierisefullgame_springpad_part("part_bellows", "Bellows", "p6_zm_buildable_tramplesteam_bellows");
    parts[2] = dierisefullgame_springpad_part("part_compressor", "Compressor", "p6_zm_buildable_tramplesteam_compressor");
    parts[3] = dierisefullgame_springpad_part("part_flag", "Flag", "p6_zm_buildable_tramplesteam_flag");
    return parts;
}

dierisefullgame_springpad_part(key, label, model)
{
    part = spawnstruct();
    part.key = key;
    part.label = label;
    part.model = model;
    return part;
}

// The spawn structs a piece may use: both (random), or the one its setting picks.
dierisefullgame_springpad_spawns(buildablename, modelname, spawns)
{
    if(buildablename != "springpad_zm") return spawns;

    foreach(part in dierisefullgame_springpad_parts())
    {
        if(part.model != modelname) continue;

        nearest = 0;
        for(i = 0; i < spawns.size; i++)
        {
            println("D-Prac: " + part.label + " spot " + (i + 1) + " at " + spawns[i].origin);
            if(distancesquared(spawns[i].origin, START_ORIGIN) < distancesquared(spawns[nearest].origin, START_ORIGIN)) nearest = i;
        }

        value = get_cfg_int(part.key);
        if(value == PART_SPAWN) return array(spawns[nearest]);
        if(value != PART_OUTSIDE) return spawns;

        outside = [];
        for(i = 0; i < spawns.size; i++)
            if(i != nearest) outside[outside.size] = spawns[i];
        return outside;
    }
    return spawns;
}

// OVERRIDE: maps\mp\zombies\_zm_buildables::generate_zombie_buildable_piece
dierisefullgame_generate_zombie_buildable_piece( buildablename, modelname, radius, height, drop_offset, hud_icon, onpickup, ondrop, use_spawn_num, part_name, can_reuse, client_field_state, buildable_slot )
{
    precachemodel( modelname );

    if ( isdefined( hud_icon ) )
        precacheshader( hud_icon );

    piece = spawnstruct();
    buildable_pieces = [];
    buildable_pieces_structs = getstructarray( buildablename + "_" + modelname, "targetname" );

    foreach ( index, struct in buildable_pieces_structs )
    {
        buildable_pieces[index] = struct;
        buildable_pieces[index].hasspawned = 0;
    }

    //MODIFIED: a Trample Parts setting leaves only its chosen spawn
    piece.spawns = dierisefullgame_springpad_spawns( buildablename, modelname, buildable_pieces );
    //MODIFIED END
    piece.buildablename = buildablename;
    piece.modelname = modelname;
    piece.hud_icon = hud_icon;
    piece.radius = radius;
    piece.height = height;
    piece.part_name = part_name;
    piece.can_reuse = can_reuse;
    piece.drop_offset = drop_offset;
    piece.max_instances = 256;

    if ( isdefined( buildable_slot ) )
        piece.buildable_slot = buildable_slot;
    else
        piece.buildable_slot = 0;

    piece.onpickup = onpickup;
    piece.ondrop = ondrop;
    piece.use_spawn_num = use_spawn_num;
    piece.client_field_state = client_field_state;
    return piece;
}

/*##############################################################################
                              Tower code
##############################################################################*/
// The final step: the tower legs are punched with Galvaknuckles in
// level.a_wind_order (tower_punch_watcher). The mahjong tiles show the code:
// wind tile i and number tile i + 1 share a color, the north tile always sits
// at sq_tile_loc_north.

// The four winds in Side order: each set Side (unless an earlier Side took that
// wind), the rest random from the winds left.
dierisefullgame_wind_order()
{
    names = array("north", "south", "east", "west");
    order = [];
    used = [];
    for(i = 0; i < TOWER_SIDES; i++)
    {
        c = get_cfg_int("tower_leg_" + (i + 1)) - 1;
        if(c >= 0 && c < names.size && !isdefined(used[names[c]]))
        {
            order[i] = names[c];
            used[names[c]] = 1;
        }
    }

    free = [];
    foreach(name in names)
        if(!isdefined(used[name])) free[free.size] = name;
    free = array_randomize(free);

    next = 0;
    for(i = 0; i < TOWER_SIDES; i++)
    {
        if(isdefined(order[i])) continue;
        order[i] = free[next];
        next++;
    }
    println("D-Prac: tower code " + order[0] + " " + order[1] + " " + order[2] + " " + order[3]);
    return order;
}

// OVERRIDE: maps\mp\zm_highrise_sq::mahjong_tiles_setup
dierisefullgame_mahjong_tiles_setup()
{
    //MODIFIED: Tower Code setting.
    a_winds = dierisefullgame_wind_order();
    //MODIFIED END
    a_colors = array_randomize( array( "blk", "blu", "grn", "red" ) );
    a_locs = array_randomize( getstructarray( "sq_tile_loc_random", "targetname" ) );
    a_wind_order = array( "none" );

    for ( i = 0; i < a_winds.size; i++ )
    {
        a_wind_order[a_wind_order.size] = a_winds[i];
        m_wind_tile = getent( "tile_" + a_winds[i] + "_" + a_colors[i], "targetname" );
        m_wind_tile.script_noteworthy = undefined;
        s_spot = a_locs[i];

        if ( a_winds[i] == "north" )
            s_spot = getstruct( "sq_tile_loc_north", "targetname" );

        m_wind_tile.origin = s_spot.origin;
        m_wind_tile.angles = s_spot.angles;
    }

    for ( i = 0; i < a_colors.size; i++ )
    {
        m_num_tile = getent( "tile_" + ( i + 1 ) + "_" + a_colors[i], "targetname" );
        m_num_tile.script_noteworthy = undefined;
        s_spot = a_locs[i + a_winds.size];
        m_num_tile.origin = s_spot.origin;
        m_num_tile.angles = s_spot.angles;
    }

    a_tiles = getentarray( "mahjong_tile", "script_noteworthy" );
    array_delete( a_tiles );
    level.a_wind_order = a_winds;
}
