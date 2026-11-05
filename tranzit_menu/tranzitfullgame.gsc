#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\tranzit_menu\tranzitutil;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              TranZit Fullgame
##############################################################################*/
// A normal game from round 1 with the run's RNG set: the first two box hits,
// 3% drops, the Max Ammo on the first kill of the ending, where each Denizen
// teleport goes, where the jet gun parts spawn, and the Avogadro's storm and
// return for the Maxis side.

tranzitfullgame_initialize()
{
    replacefunc(maps\mp\zombies\_zm_buildables::generate_zombie_buildable_piece, ::tranzitfullgame_generate_zombie_buildable_piece);
    replacefunc(maps\mp\zm_transit_ai_screecher::teleport_player, ::tranzitfullgame_teleport_player);
    replacefunc(maps\mp\zombies\_zm_ai_avogadro::avogadro_exit, ::tranzitfullgame_avogadro_exit);
    replacefunc(maps\mp\zombies\_zm_ai_avogadro::cloud_update_fx, ::tranzitfullgame_cloud_update_fx);
    tranzit_drops_install();
    level.tranzitfullgame_teleports = 0;
    mode_cfg_load("tranzitfullgame", tranzitfullgame_default_cfg());
}

tranzitfullgame_run()
{
    level.tranzitfullgame_box_hits = 0;
    level.customrandomweaponweights = ::tranzitfullgame_box_hit_weights;
    level thread tranzitfullgame_ending_max();

    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
}

tranzitfullgame_default_cfg()
{
    settings_ar = [];
    settings_ar = tranzit_drop_defaults(settings_ar);
    settings_ar["box_hit_1"] = 0;
    settings_ar["box_hit_2"] = 0;
    for(i = 1; i <= DENIZEN_TELEPORTS; i++)
        settings_ar["teleport_" + i] = 0;
    foreach(part in tranzitfullgame_jetgun_parts())
        settings_ar[part.key] = 0;
    settings_ar["storm_region"] = 0;
    settings_ar["avogadro_return"] = AVO_RETURN_VANILLA;
    return settings_ar;
}

tranzitfullgame_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        tranzit_drop_menu(settings);

        box = add_submenu(settings, "box", "Mystery Box", "Box");
            box_guns = tranzitfullgame_box_hit_options();
            add_cfg_choice(box, "Hit 1", "box_hit_1", box_guns.labels);
            add_cfg_choice(box, "Hit 2", "box_hit_2", box_guns.labels);

        teleports = add_submenu(settings, "teleports", "Denizen Teleports", "Teleports");
            lights = combinearrays(array("random"), tranzit_light_labels());
            for(i = 1; i <= DENIZEN_TELEPORTS; i++)
                add_cfg_choice(teleports, "Teleport " + i, "teleport_" + i, lights);

        parts = add_submenu(settings, "jetgun", "Jetgun Parts", "Jetgun");
            foreach(part in tranzitfullgame_jetgun_parts())
                add_cfg_choice(parts, part.label, part.key, tranzitfullgame_jetgun_labels(part));

        maxis = add_submenu(settings, "maxis", "Maxis Side", "Maxis");
            add_cfg_choice(maxis, "Storm", "storm_region", array("random", "bus depot", "diner", "farm", "cornfield", "power station", "town"));
            add_cfg_choice(maxis, "Avogadro", "avogadro_return", array("vanilla", "next round", "at once"));
}

/*##############################################################################
                              Mystery Box
##############################################################################*/
// Every gun the TranZit box can give (zm_transit include_weapons, in-box
// entries), for the Hit 1 and Hit 2 settings. The saved value is the index, 0
// is random.
tranzitfullgame_box_hit_options()
{
    options = spawnstruct();
    options.weapons = [];
    options.labels = [];
    tranzitfullgame_add_box_hit_option(options, "", "random");
    tranzitfullgame_add_box_hit_option(options, "ray_gun_zm", "Ray Gun");
    tranzitfullgame_add_box_hit_option(options, "emp_grenade_zm", "EMP Grenade");
    tranzitfullgame_add_box_hit_option(options, "cymbal_monkey_zm", "Monkey Bombs");
    tranzitfullgame_add_box_hit_option(options, "m32_zm", "War Machine");
    tranzitfullgame_add_box_hit_option(options, "usrpg_zm", "RPG");
    tranzitfullgame_add_box_hit_option(options, "rpd_zm", "RPD");
    tranzitfullgame_add_box_hit_option(options, "hamr_zm", "HAMR");
    tranzitfullgame_add_box_hit_option(options, "galil_zm", "Galil");
    tranzitfullgame_add_box_hit_option(options, "type95_zm", "Type 25");
    tranzitfullgame_add_box_hit_option(options, "tar21_zm", "MTAR");
    tranzitfullgame_add_box_hit_option(options, "xm8_zm", "M8A1");
    tranzitfullgame_add_box_hit_option(options, "saritch_zm", "SMR");
    tranzitfullgame_add_box_hit_option(options, "fnfal_zm", "FAL");
    tranzitfullgame_add_box_hit_option(options, "dsr50_zm", "DSR 50");
    tranzitfullgame_add_box_hit_option(options, "barretm82_zm", "Barrett M82A1");
    tranzitfullgame_add_box_hit_option(options, "qcw05_zm", "Chicom CQB");
    tranzitfullgame_add_box_hit_option(options, "saiga12_zm", "S12");
    tranzitfullgame_add_box_hit_option(options, "srm1216_zm", "M1216");
    tranzitfullgame_add_box_hit_option(options, "python_zm", "Python");
    tranzitfullgame_add_box_hit_option(options, "judge_zm", "Executioner");
    tranzitfullgame_add_box_hit_option(options, "kard_zm", "KAP-40");
    tranzitfullgame_add_box_hit_option(options, "fiveseven_zm", "Five-seven");
    tranzitfullgame_add_box_hit_option(options, "fivesevendw_zm", "Five-seven DW");
    tranzitfullgame_add_box_hit_option(options, "knife_ballistic_zm", "Ballistic Knife");
    return options;
}

tranzitfullgame_add_box_hit_option(options, weapon, label)
{
    options.weapons[options.weapons.size] = weapon;
    options.labels[options.labels.size] = label;
}

// As O-Prac's Hit 1/Hit 2: vanilla treasure_chest_chooseweightedrandomweapon
// calls this once per box hit with the shuffled weapon list and gives the first
// weapon in it the player can receive. On the first two hits the chosen gun goes
// to the front. If the player cannot receive it (owned, limit reached), the box
// picks randomly as usual.
tranzitfullgame_box_hit_weights(keys)
{
    level.tranzitfullgame_box_hits++;
    if(level.tranzitfullgame_box_hits > 2) return keys;

    choice = get_cfg_int("box_hit_" + level.tranzitfullgame_box_hits);
    options = tranzitfullgame_box_hit_options();
    if(choice <= 0 || choice >= options.weapons.size) return keys;

    forced = [];
    forced[0] = options.weapons[choice];
    foreach(key in keys) forced[forced.size] = key;
    return forced;
}

/*##############################################################################
                              Ending Max Ammo
##############################################################################*/
// The ending starts when the Richtofen tower kills are done (vanilla notify of
// richtofen_sidequest_b), right before the EMP lights.
tranzitfullgame_ending_max()
{
    level waittill("sq_stage_3complete");
    tranzit_arm_ending_max();
}

/*##############################################################################
                              Denizen teleports
##############################################################################*/
// OVERRIDE: maps\mp\zm_transit_ai_screecher::teleport_player
// self is the light whose hole the player jumped in.
tranzitfullgame_teleport_player( player )
{
    lights = getstructarray( "screecher_escape", "targetname" );
    lights = array_randomize( lights );
    dest_light = undefined;

    //MODIFIED: the Denizen Teleports setting picks this teleport's light. One
    // that is the light the player left, or has another player close, is not
    // valid, and the teleport goes to a random light as vanilla.
    level.tranzitfullgame_teleports++;
    n = level.tranzitfullgame_teleports;
    if ( n <= DENIZEN_TELEPORTS )
    {
        forced = tranzit_light_setting( get_cfg_int( "teleport_" + n ) );

        if ( isdefined( forced ) )
        {
            if ( forced != self && !forced maps\mp\zm_transit_ai_screecher::other_players_close_to_light( player ) )
                dest_light = forced;
            else
                iprintln( "T-Prac: teleport " + n + " to " + forced.script_noteworthy + " not valid, using random" );
        }
    }

    if ( !isdefined( dest_light ) )
    {
    //MODIFIED END
        foreach ( light in lights )
        {
            if ( light == self )
                continue;

            if ( light maps\mp\zm_transit_ai_screecher::other_players_close_to_light( player ) )
                continue;

            dest_light = light;
            break;
        }
    }

    if ( isdefined( dest_light ) )
    {
        playsoundatposition( "zmb_screecher_portal_arrive", dest_light.origin );
        player maps\mp\zombies\_zm_gump::player_teleport_blackscreen_on();
        player setorigin( dest_light.origin );
        player notify( "used_screecher_hole" );
        player maps\mp\zombies\_zm_stats::increment_client_stat( "screecher_teleporters_used", 0 );
        player maps\mp\zombies\_zm_stats::increment_player_stat( "screecher_teleporters_used" );
    }
}

/*##############################################################################
                              Jet gun parts
##############################################################################*/
// Each piece's spawn structs ("jetgun_zm_<model>"). The setting is 0 for random,
// else 1 + the struct index. The menu names a spot by the zone it is in (read
// once): the structs' real names are not known yet, the console prints each
// spot as the piece spawns ("T-Prac: Wires spot 1 ...").
tranzitfullgame_jetgun_parts()
{
    parts = [];
    parts[0] = tranzitfullgame_jetgun_part("jetgun_wires", "Wires", "p6_zm_buildable_jetgun_wires");
    parts[1] = tranzitfullgame_jetgun_part("jetgun_engine", "Engine", "p6_zm_buildable_jetgun_engine");
    parts[2] = tranzitfullgame_jetgun_part("jetgun_gauges", "Gauges", "p6_zm_buildable_jetgun_guages");
    parts[3] = tranzitfullgame_jetgun_part("jetgun_handles", "Handles", "p6_zm_buildable_jetgun_handles");
    return parts;
}

tranzitfullgame_jetgun_part(key, label, model)
{
    part = spawnstruct();
    part.key = key;
    part.label = label;
    part.model = model;
    return part;
}

tranzitfullgame_jetgun_labels(part)
{
    if(!isdefined(level.tranzitfullgame_jetgun_labels)) level.tranzitfullgame_jetgun_labels = [];
    if(isdefined(level.tranzitfullgame_jetgun_labels[part.key])) return level.tranzitfullgame_jetgun_labels[part.key];

    labels = array("random");
    spots = getstructarray("jetgun_zm_" + part.model, "targetname");
    for(i = 0; i < spots.size; i++)
        labels[labels.size] = (i + 1) + ". " + tranzitfullgame_spot_name(spots[i].origin);
    level.tranzitfullgame_jetgun_labels[part.key] = labels;
    return labels;
}

tranzitfullgame_spot_name(origin)
{
    zone = maps\mp\zombies\_zm_zonemgr::get_zone_from_position(origin + (0, 0, 32), 1);
    if(!isdefined(zone)) return "no zone";
    return basegame_plain_zone_name(zone);
}

// The spawn structs a piece may use: all of them (random), or only the one its
// setting picks. A spot past the last struct falls back to random.
tranzitfullgame_jetgun_spawns(buildablename, modelname, spawns)
{
    if(buildablename != "jetgun_zm") return spawns;

    foreach(part in tranzitfullgame_jetgun_parts())
    {
        if(part.model != modelname) continue;

        for(i = 0; i < spawns.size; i++)
            print("T-Prac: " + part.label + " spot " + (i + 1) + " at " + spawns[i].origin);

        value = get_cfg_int(part.key);
        if(value < 1) return spawns;
        if(!isdefined(spawns[value - 1]))
        {
            print("T-Prac: " + part.label + " has no spot " + value + " (" + spawns.size + " spots), using random");
            return spawns;
        }
        return array(spawns[value - 1]);
    }
    return spawns;
}

// OVERRIDE: maps\mp\zombies\_zm_buildables::generate_zombie_buildable_piece
tranzitfullgame_generate_zombie_buildable_piece( buildablename, modelname, radius, height, drop_offset, hud_icon, onpickup, ondrop, use_spawn_num, part_name, can_reuse, client_field_state, buildable_slot )
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

    //MODIFIED: a Jet Gun Parts setting leaves only its chosen spawn
    piece.spawns = tranzitfullgame_jetgun_spawns( buildablename, modelname, buildable_pieces );
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
                              Avogadro (Maxis side)
##############################################################################*/
// The Avogadro waits in a storm cloud between its visits. "Storm" keeps the
// cloud over one region (vanilla moves it every 30 s, starting at the power
// station), "Avogadro return" brings it back sooner (vanilla: 2 to 4 rounds, the
// next round when it left because nobody came).

// OVERRIDE: maps\mp\zombies\_zm_ai_avogadro::avogadro_exit
tranzitfullgame_avogadro_exit( from )
{
    self.state = "exiting";
    self notify( "stop_find_flesh" );
    self notify( "zombie_acquire_enemy" );
    self setfreecameralockonallowed( 0 );
    self.audio_loop_ent stoploopsound( 0.5 );
    self notify( "stop_health" );

    if ( isdefined( self.health_fx ) )
    {
        self.health_fx unlink();
        self.health_fx delete();
    }

    if ( isdefined( from ) )
    {
        if ( from == "bus" )
        {
            self playsound( "zmb_avogadro_death_short" );
            playfx( level._effect["avogadro_ascend_aerial"], self.origin );
            self animscripted( self.origin, self.angles, "zm_bus_win" );
            maps\mp\animscripts\zm_shared::donotetracks( "bus_win_anim" );
        }
        else if ( from == "chamber" )
        {
            self playsound( "zmb_avogadro_death_short" );
            playfx( level._effect["avogadro_ascend"], self.origin );
            self animscripted( self.origin, self.angles, "zm_chamber_out" );
            wait 0.4;
            self ghost();
            stop_exploder( 500 );
        }
        else
        {
            self playsound( "zmb_avogadro_death" );
            playfx( level._effect["avogadro_ascend"], self.origin );
            self animscripted( self.origin, self.angles, "zm_exit" );
            maps\mp\animscripts\zm_shared::donotetracks( "exit_anim" );
        }
    }
    else
    {
        self playsound( "zmb_avogadro_death" );
        playfx( level._effect["avogadro_ascend"], self.origin );
        self animscripted( self.origin, self.angles, "zm_exit" );
        maps\mp\animscripts\zm_shared::donotetracks( "exit_anim" );
    }

    if ( !isdefined( from ) || from != "chamber" )
        level thread maps\mp\zombies\_zm_ai_avogadro::do_avogadro_flee_vo( self );

    self ghost();
    self.hit_by_melee = 0;
    self.anchor.origin = self.origin;
    self.anchor.angles = self.angles;
    self linkto( self.anchor );

    if ( isdefined( from ) && from == "exit_idle" )
        self.return_round = level.round_number + 1;
    else
        self.return_round = level.round_number + randomintrange( 2, 5 );

    //MODIFIED: Avogadro return setting. cloud_update brings it back once the
    // round number reaches return_round.
    switch ( get_cfg_int( "avogadro_return" ) )
    {
        case AVO_RETURN_NEXT: self.return_round = level.round_number + 1; break;
        case AVO_RETURN_NOW:  self.return_round = level.round_number; break;
    }
    //MODIFIED END

    level.next_avogadro_round = self.return_round;
    self.state = "cloud";
    self thread maps\mp\zombies\_zm_ai_avogadro::cloud_update_fx();
}

// OVERRIDE: maps\mp\zombies\_zm_ai_avogadro::cloud_update_fx
tranzitfullgame_cloud_update_fx()
{
    self endon( "cloud_fx_end" );
    level endon( "end_game" );
    region = [];
    region[0] = "bus";
    region[1] = "diner";
    region[2] = "farm";
    region[3] = "cornfield";
    region[4] = "power";
    region[5] = "town";
    self.current_region = undefined;

    if ( !isdefined( self.sndent ) )
    {
        self.sndent = spawn( "script_origin", ( 0, 0, 0 ) );
        self.sndent playloopsound( "zmb_avogadro_thunder_overhead" );
    }

    cloud_time = gettime();

    for ( vo_counter = 0; 1; vo_counter++ )
    {
        if ( gettime() >= cloud_time )
        {
            if ( isdefined( self.current_region ) )
            {
                exploder_num = level.transit_region[self.current_region].exploder;
                stop_exploder( exploder_num );
            }

            rand_region = array_randomize( region );
            region_str = rand_region[0];

            if ( !isdefined( self.current_region ) )
                region_str = region[4];

            //MODIFIED: Storm setting (1 + region index, 0 is vanilla).
            storm = get_cfg_int( "storm_region" );
            if ( storm >= 1 && storm <= region.size )
                region_str = region[storm - 1];
            //MODIFIED END

            self.current_region = region_str;
            exploder_num = level.transit_region[region_str].exploder;
            exploder( exploder_num );
            self.sndent moveto( level.transit_region[region_str].sndorigin, 3 );
            cloud_time = gettime() + 30000;
        }

        if ( vo_counter > 50 )
        {
            player = self maps\mp\zombies\_zm_ai_avogadro::get_player_in_region();

            if ( isdefined( player ) )
            {
                if ( isdefined( self._in_cloud ) && self._in_cloud )
                    player thread do_player_general_vox( "general", "avogadro_above", 90, 10 );
                else
                    player thread do_player_general_vox( "general", "avogadro_arrive", 60, 40 );
            }
            else
                level thread maps\mp\zombies\_zm_ai_avogadro::avogadro_storm_vox();

            vo_counter = 0;
        }

        wait 0.1;
    }
}
