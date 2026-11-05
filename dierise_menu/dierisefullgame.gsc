#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\dierise_menu\dierise;

/*##############################################################################
                              Die Rise Fullgame
##############################################################################*/
// A normal game from round 1 with the run's RNG set: where the building 3
// elevators start, where each Trample Steam part spawns, and the final tower
// code (the order the tower legs are punched).

#define ELEV3_RANDOM    0
#define ELEV3_A         1       // zm_highrise_classic main, randomint( 100 ) > 50 branch.
#define ELEV3_B         2

#define TOWER_LEGS      4

dierisefullgame_initialize()
{
    replacefunc(maps\mp\zm_highrise_elevators::init_elevator, ::dierisefullgame_init_elevator);
    replacefunc(maps\mp\zombies\_zm_buildables::generate_zombie_buildable_piece, ::dierisefullgame_generate_zombie_buildable_piece);
    replacefunc(maps\mp\zm_highrise_sq::mahjong_tiles_setup, ::dierisefullgame_mahjong_tiles_setup);
    mode_cfg_load("dierisefullgame", dierisefullgame_default_cfg());
}

dierisefullgame_run()
{
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
}

dierisefullgame_default_cfg()
{
    settings_ar = [];
    settings_ar["bldg3_elevators"] = ELEV3_RANDOM;
    foreach(part in dierisefullgame_springpad_parts())
        settings_ar[part.key] = 0;
    for(i = 1; i <= TOWER_LEGS; i++)
        settings_ar["tower_leg_" + i] = 0;
    return settings_ar;
}

dierisefullgame_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_choice(settings, "Building 3 elevators", "bldg3_elevators", array("random", "layout A", "layout B"));

        parts = add_submenu(settings, "springpad", "Trample Steam Parts", "Trample Steam");
            foreach(part in dierisefullgame_springpad_parts())
                dierisefullgame_add_choice(parts, part.label, part.key, dierisefullgame_springpad_labels(part));

        tower = add_submenu(settings, "tower", "Tower Code", "Tower Code");
            winds = array("random", "north", "south", "east", "west");
            for(i = 1; i <= TOWER_LEGS; i++)
                add_cfg_choice(tower, "Leg " + i, "tower_leg_" + i, winds);
}

// add_cfg_choice for a list that is only known at run time: a saved value past
// its end shows (and acts) as random.
dierisefullgame_add_choice(menu, label, key, names)
{
    if(get_cfg_int(key) >= names.size)
    {
        create_option(menu, label + ": ^3" + names[0], ::cfg_increment_int, key, array(0, names.size - 1));
        return;
    }
    add_cfg_choice(menu, label, key, names);
}

/*##############################################################################
                              Building 3 elevators
##############################################################################*/
// zm_highrise_classic main flips a coin for the two building 3 elevators: A is
// "3" at stop 1 (1264 units below it) and "3b" at stop 2, B the other way round.
// Every other elevator always starts at the same stop.

// OVERRIDE: maps\mp\zm_highrise_elevators::init_elevator
dierisefullgame_init_elevator( elevatorname, force_starting_floor, force_starting_origin )
{
    //MODIFIED: Building 3 elevators setting replaces the coin flip.
    layout = get_cfg_int( "bldg3_elevators" );

    if ( layout == ELEV3_A || layout == ELEV3_B )
    {
        low = "3";

        if ( layout == ELEV3_B )
            low = "3b";

        if ( elevatorname == "3" || elevatorname == "3b" )
        {
            if ( elevatorname == low )
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
// Each piece's spawn structs ("springpad_zm_<model>", zm_highrise_buildables).
// The setting is 0 for random, else 1 + the struct index. The menu names a spot
// by the zone it is in (read once), the console prints each spot as the piece
// spawns ("D-Prac: Door spot 1 ..."). Same approach as T-Prac's jet gun parts.
dierisefullgame_springpad_parts()
{
    parts = [];
    parts[0] = dierisefullgame_springpad_part("springpad_door", "Door", "p6_zm_buildable_tramplesteam_door");
    parts[1] = dierisefullgame_springpad_part("springpad_bellows", "Bellows", "p6_zm_buildable_tramplesteam_bellows");
    parts[2] = dierisefullgame_springpad_part("springpad_compressor", "Compressor", "p6_zm_buildable_tramplesteam_compressor");
    parts[3] = dierisefullgame_springpad_part("springpad_flag", "Flag", "p6_zm_buildable_tramplesteam_flag");
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

dierisefullgame_springpad_labels(part)
{
    if(!isdefined(level.dierisefullgame_springpad_labels)) level.dierisefullgame_springpad_labels = [];
    if(isdefined(level.dierisefullgame_springpad_labels[part.key])) return level.dierisefullgame_springpad_labels[part.key];

    labels = array("random");
    spots = getstructarray("springpad_zm_" + part.model, "targetname");
    for(i = 0; i < spots.size; i++)
        labels[labels.size] = (i + 1) + ". " + dierisefullgame_spot_name(spots[i].origin);
    // Zones may not be up when the menu is first built: cache only once they are.
    if(isdefined(level.zones)) level.dierisefullgame_springpad_labels[part.key] = labels;
    return labels;
}

dierisefullgame_spot_name(origin)
{
    zone = maps\mp\zombies\_zm_zonemgr::get_zone_from_position(origin + (0, 0, 32), 1);
    if(!isdefined(zone)) return "no zone";
    return basegame_plain_zone_name(zone);
}

// The spawn structs a piece may use: all of them (random), or only the one its
// setting picks. A spot past the last struct falls back to random.
dierisefullgame_springpad_spawns(buildablename, modelname, spawns)
{
    if(buildablename != "springpad_zm") return spawns;

    foreach(part in dierisefullgame_springpad_parts())
    {
        if(part.model != modelname) continue;

        for(i = 0; i < spawns.size; i++)
            println("D-Prac: " + part.label + " spot " + (i + 1) + " at " + spawns[i].origin);

        value = get_cfg_int(part.key);
        if(value < 1) return spawns;
        if(!isdefined(spawns[value - 1]))
        {
            println("D-Prac: " + part.label + " has no spot " + value + " (" + spawns.size + " spots), using random");
            return spawns;
        }
        return array(spawns[value - 1]);
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

    //MODIFIED: a Trample Steam Parts setting leaves only its chosen spawn
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

// The four winds in Leg order: each set Leg (unless an earlier Leg took that
// wind), the rest random from the winds left.
dierisefullgame_wind_order()
{
    names = array("north", "south", "east", "west");
    order = [];
    used = [];
    for(i = 0; i < TOWER_LEGS; i++)
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
    for(i = 0; i < TOWER_LEGS; i++)
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
