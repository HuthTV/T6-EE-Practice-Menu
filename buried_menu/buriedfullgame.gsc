#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Buried Fullgame
##############################################################################*/
// A normal game from round 1 with the run's RNG set: the first three box hits,
// 3% drops, the first ghost round's perk, the Infinity round (Richtofen time
// bomb round of zm_buried_sq_tpo: body spots, which search finds the switch, the
// drop after it) and the maze switches of zm_buried_sq_ip (maze layout, side of
// each switch, solution order). The fridge and the solo time bomb fix are map
// settings (Victis Settings, buried.gsc).

#define BOX_HITS          3
#define CORPSES           4     // Vanilla get_randomized_corpse_list has four bodies.
#define MAZE_SWITCHES     4     // Rows shown. Extra rows do nothing if the map has fewer levers.

#define SIDE_RANDOM       0
#define SIDE_NORTH_WEST   1
#define SIDE_SOUTH_EAST   2

buriedfullgame_initialize()
{
    replacefunc(maps\mp\zombies\_zm_powerups::powerup_drop, ::buriedfullgame_powerup_drop);
    replacefunc(maps\mp\zombies\_zm_powerups::free_perk_powerup, ::buriedfullgame_free_perk_powerup);
    replacefunc(maps\mp\zm_buried_sq_tpo::setup_random_corpse_positions, ::buriedfullgame_setup_random_corpse_positions);
    replacefunc(maps\mp\zm_buried_sq_tpo::item_is_on_corpse, ::buriedfullgame_item_is_on_corpse);
    replacefunc(maps\mp\zm_buried_sq_ip::sq_ml_spawn_lever, ::buriedfullgame_sq_ml_spawn_lever);
    replacefunc(maps\mp\zm_buried_sq_ip::sq_ml_puzzle_logic, ::buriedfullgame_sq_ml_puzzle_logic);
    level.buriedfullgame_ghost_perks = 0;
    mode_cfg_load("buriedfullgame", buriedfullgame_default_cfg());
}

buriedfullgame_run()
{
    // zm_buried main sets its own (pass-through) weights, so this goes after it.
    level.buriedfullgame_box_hits = 0;
    level.customrandomweaponweights = ::buriedfullgame_box_hit_weights;
    level thread buriedfullgame_special_round_drop();

    flag_wait("initial_blackscreen_passed");
    buriedfullgame_lock_maze();
    flag_set("menu_active");
}

buriedfullgame_default_cfg()
{
    settings_ar = [];
    settings_ar["percent_drops"] = 1;
    settings_ar["box_hit_1"] = 1;          // Paralyzer, Time Bomb, Ballistic Knife: the route's
    settings_ar["box_hit_2"] = 2;          // first three hits (user, 2026-11-03).
    settings_ar["box_hit_3"] = 3;
    settings_ar["ghost_perk"] = 0;
    for(i = 1; i <= CORPSES; i++)
        settings_ar["body_spot_" + i] = 0;
    settings_ar["switch_search"] = 0;
    settings_ar["special_round_drop"] = 0;
    settings_ar["maze_layout"] = 0;
    for(i = 1; i <= MAZE_SWITCHES; i++)
    {
        settings_ar["switch_side_" + i] = SIDE_RANDOM;
        settings_ar["switch_order_" + i] = 0;
    }
    return settings_ar;
}

buriedfullgame_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_toggle(settings, "3% Drops", "percent_drops");
        add_cfg_choice(settings, "Ghost Perk", "ghost_perk", buriedfullgame_perk_options().labels);

        box = add_submenu(settings, "box", "Mystery Box", "Box");
            box_guns = buriedfullgame_box_hit_options();
            for(i = 1; i <= BOX_HITS; i++)
                add_cfg_choice(box, "Hit " + i, "box_hit_" + i, box_guns.labels);

        special = add_submenu(settings, "infinity", "Infinity Round", "Infinity Round");
            spots = buriedfullgame_corpse_spot_labels();
            for(i = 1; i <= CORPSES; i++)
                buriedfullgame_add_choice(special, "Body " + i + " Spot", "body_spot_" + i, spots);
            add_cfg_choice(special, "Switch Search", "switch_search", array("random", "1st", "2nd", "3rd", "4th"));
            add_cfg_choice(special, "Drop After Round", "special_round_drop", buriedfullgame_drop_options().labels);

        maze = add_submenu(settings, "maze", "Maze Switches", "Maze");
            add_cfg_choice(maze, "Layout", "maze_layout", array("random", "1", "2", "3", "4", "5", "6"));
            for(i = 1; i <= MAZE_SWITCHES; i++)
                add_cfg_choice(maze, "Switch " + i + " Side", "switch_side_" + i, array("random", "N / W", "S / E"));
            for(i = 1; i <= MAZE_SWITCHES; i++)
                add_cfg_choice(maze, "Switch " + i + " Order", "switch_order_" + i, array("random", "1st", "2nd", "3rd", "4th"));
}

// add_cfg_choice for a list that is only known at run time: a saved value past
// its end shows (and acts) as random.
buriedfullgame_add_choice(menu, label, key, names)
{
    if(get_cfg_int(key) >= names.size)
    {
        create_option(menu, label + ": ^3" + names[0], ::cfg_increment_int, key, array(0, names.size - 1));
        return;
    }
    add_cfg_choice(menu, label, key, names);
}

/*##############################################################################
                              Mystery Box
##############################################################################*/
// Guns the Buried box can give (zm_buried include_weapons entries in the box),
// for the Hit settings. The saved value is the index, 0 is random.
buriedfullgame_box_hit_options()
{
    options = spawnstruct();
    options.weapons = [];
    options.labels = [];
    buriedfullgame_add_option(options, "", "random");
    buriedfullgame_add_option(options, "slowgun_zm", "Paralyzer");
    buriedfullgame_add_option(options, "time_bomb_zm", "Time Bomb");
    buriedfullgame_add_option(options, "knife_ballistic_zm", "Ballistic Knife");
    buriedfullgame_add_option(options, "ray_gun_zm", "Ray Gun");
    buriedfullgame_add_option(options, "raygun_mark2_zm", "Ray Gun Mark II");
    buriedfullgame_add_option(options, "cymbal_monkey_zm", "Monkey Bombs");
    buriedfullgame_add_option(options, "m32_zm", "War Machine");
    buriedfullgame_add_option(options, "usrpg_zm", "RPG");
    buriedfullgame_add_option(options, "hamr_zm", "HAMR");
    buriedfullgame_add_option(options, "tar21_zm", "MTAR");
    buriedfullgame_add_option(options, "galil_zm", "Galil");
    buriedfullgame_add_option(options, "saritch_zm", "SMR");
    buriedfullgame_add_option(options, "fnfal_zm", "FAL");
    buriedfullgame_add_option(options, "srm1216_zm", "M1216");
    buriedfullgame_add_option(options, "saiga12_zm", "S12");
    buriedfullgame_add_option(options, "dsr50_zm", "DSR 50");
    buriedfullgame_add_option(options, "barretm82_zm", "Barrett M82A1");
    buriedfullgame_add_option(options, "rnma_zm", "Remington");
    buriedfullgame_add_option(options, "judge_zm", "Executioner");
    buriedfullgame_add_option(options, "kard_zm", "KAP-40");
    buriedfullgame_add_option(options, "fiveseven_zm", "Five-seven");
    buriedfullgame_add_option(options, "fivesevendw_zm", "Five-seven DW");
    return options;
}

buriedfullgame_add_option(options, value, label)
{
    options.weapons[options.weapons.size] = value;
    options.labels[options.labels.size] = label;
}

// As O-Prac's Hit 1/Hit 2: vanilla treasure_chest_chooseweightedrandomweapon
// calls this once per box hit with the shuffled weapon list and gives the first
// weapon in it the player can receive. On the first three hits the chosen gun
// goes to the front. If the player cannot receive it (owned, limit reached), the
// box picks randomly as usual.
buriedfullgame_box_hit_weights(keys)
{
    level.buriedfullgame_box_hits++;
    if(level.buriedfullgame_box_hits > BOX_HITS) return keys;

    choice = get_cfg_int("box_hit_" + level.buriedfullgame_box_hits);
    options = buriedfullgame_box_hit_options();
    if(choice <= 0 || choice >= options.weapons.size) return keys;

    forced = [];
    forced[0] = options.weapons[choice];
    foreach(key in keys) forced[forced.size] = key;
    return forced;
}

/*##############################################################################
                              First ghost round perk
##############################################################################*/
// Perks with a machine on Buried (zm_buried perk dialogue list).
buriedfullgame_perk_options()
{
    options = spawnstruct();
    options.weapons = [];
    options.labels = [];
    buriedfullgame_add_option(options, "", "random");
    buriedfullgame_add_option(options, "specialty_armorvest", "Juggernog");
    buriedfullgame_add_option(options, "specialty_quickrevive", "Quick Revive");
    buriedfullgame_add_option(options, "specialty_fastreload", "Speed Cola");
    buriedfullgame_add_option(options, "specialty_rof", "Double Tap");
    buriedfullgame_add_option(options, "specialty_longersprint", "Stamin-Up");
    buriedfullgame_add_option(options, "specialty_additionalprimaryweapon", "Mule Kick");
    buriedfullgame_add_option(options, "specialty_nomotionsensor", "Vulture Aid");
    return options;
}

// The chosen perk for this player, or undefined for vanilla's random pick (no
// choice, owned, paused or no machine on the map).
buriedfullgame_ghost_perk()
{
    options = buriedfullgame_perk_options();
    choice = get_cfg_int("ghost_perk");
    if(choice <= 0 || choice >= options.weapons.size) return undefined;

    perk = options.weapons[choice];
    if(self hasperk(perk) || self maps\mp\zombies\_zm_perks::has_perk_paused(perk)) return undefined;
    if(isdefined(self.perk_purchased) && self.perk_purchased == perk) return undefined;
    foreach(machine in getentarray("zombie_vending", "targetname"))
        if(machine.script_noteworthy == perk) return perk;
    return undefined;
}

// OVERRIDE: maps\mp\zombies\_zm_powerups::free_perk_powerup
buriedfullgame_free_perk_powerup( item )
{
    //MODIFIED: the first ghost round's perk (vanilla end_ghost_round marks it
    // ghost_powerup) is the 1st ghost round perk setting.
    first_ghost_perk = 0;

    if ( isdefined( item.ghost_powerup ) )
    {
        level.buriedfullgame_ghost_perks++;
        first_ghost_perk = level.buriedfullgame_ghost_perks == 1;
    }
    //MODIFIED END

    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        if ( !players[i] maps\mp\zombies\_zm_laststand::player_is_in_laststand() && !( players[i].sessionstate == "spectator" ) )
        {
            player = players[i];

            if ( isdefined( item.ghost_powerup ) )
            {
                player maps\mp\zombies\_zm_stats::increment_client_stat( "buried_ghost_perk_acquired", 0 );
                player maps\mp\zombies\_zm_stats::increment_player_stat( "buried_ghost_perk_acquired" );
                player notify( "player_received_ghost_round_free_perk" );
            }

            //MODIFIED: chosen perk
            free_perk = undefined;

            if ( first_ghost_perk )
                free_perk = player buriedfullgame_ghost_perk();

            if ( isdefined( free_perk ) )
                player maps\mp\zombies\_zm_perks::give_perk( free_perk );
            else
                free_perk = player maps\mp\zombies\_zm_perks::give_random_perk();
            //MODIFIED END

            if ( isdefined( level.disable_free_perks_before_power ) && level.disable_free_perks_before_power )
                player thread maps\mp\zombies\_zm_powerups::disable_perk_before_power( free_perk );
        }
    }
}

/*##############################################################################
                              Infinity round
##############################################################################*/
// The Richtofen time bomb step (zm_buried_sq_tpo): all players in the volume
// when the time bomb goes off start a round 115 special round, four bodies are
// searched for the switch, the switch goes in the guillotine.

// Menu labels of the body spots (struct order of sq_tpo_corpse_spawn_location,
// the same order setup_random_corpse_positions sees), with the zone they are in.
// Cached: zone lookups spawn an entity per call and the menu rebuilds often.
buriedfullgame_corpse_spot_labels()
{
    if(isdefined(level.buriedfullgame_spot_labels)) return level.buriedfullgame_spot_labels;

    labels = array("random");
    spots = getstructarray("sq_tpo_corpse_spawn_location", "targetname");
    for(i = 0; i < spots.size; i++)
    {
        zone = maps\mp\zombies\_zm_zonemgr::get_zone_from_position(spots[i].origin + (0, 0, 32), 1);
        if(!isdefined(zone)) zone = "no zone";
        else zone = basegame_plain_zone_name(zone);
        labels[labels.size] = (i + 1) + " " + zone;
    }
    if(isdefined(level.zones)) level.buriedfullgame_spot_labels = labels;
    return labels;
}

// OVERRIDE: maps\mp\zm_buried_sq_tpo::setup_random_corpse_positions
buriedfullgame_setup_random_corpse_positions()
{
    a_corpse_models = maps\mp\zm_buried_sq_tpo::get_randomized_corpse_list();
    //MODIFIED: Body spot settings, the rest random as vanilla.
    a_corpse_structs = buriedfullgame_corpse_spots( a_corpse_models.size );
    //MODIFIED END

    for ( i = 0; i < a_corpse_models.size; i++ )
        a_corpse_structs[i] maps\mp\zm_buried_sq_tpo::promote_to_corpse_model( a_corpse_models[i] );
}

// count spots: each set Body spot (unless taken by an earlier body), the rest
// random from the unused spots.
buriedfullgame_corpse_spots(count)
{
    all = getstructarray("sq_tpo_corpse_spawn_location", "targetname");
    chosen = [];
    used = [];
    for(i = 0; i < count; i++)
    {
        c = get_cfg_int("body_spot_" + (i + 1)) - 1;
        if(c >= 0 && c < all.size && !isdefined(used[c]))
        {
            chosen[i] = all[c];
            used[c] = 1;
        }
    }

    free = [];
    for(c = 0; c < all.size; c++)
        if(!isdefined(used[c])) free[free.size] = all[c];
    free = array_randomize(free);

    next = 0;
    for(i = 0; i < count; i++)
    {
        if(isdefined(chosen[i])) continue;
        chosen[i] = free[next];
        next++;
    }
    return chosen;
}

// OVERRIDE: maps\mp\zm_buried_sq_tpo::item_is_on_corpse
// Vanilla chances by search: 1st 1% (randomint(100) > 99 never passes, so 0%),
// 2nd 15%, 3rd 33%, 4th 100% (> 0, so 99%).
buriedfullgame_item_is_on_corpse()
{
    if ( !isdefined( level.sq_tpo.times_searched ) )
        level.sq_tpo.times_searched = 0;

    //MODIFIED: the switch is on the chosen search.
    choice = get_cfg_int( "switch_search" );

    if ( choice > 0 )
    {
        b_found_item = level.sq_tpo.times_searched + 1 == choice && !flag( "sq_tpo_found_item" );
        level.sq_tpo.times_searched++;
        return b_found_item;
    }
    //MODIFIED END

    switch ( level.sq_tpo.times_searched )
    {
        case 0:
            n_chance = 1;
            break;
        case 1:
            n_chance = 15;
            break;
        case 2:
            n_chance = 33;
            break;
        case 3:
            n_chance = 100;
            break;
    }

    b_found_item = randomint( 100 ) > 100 - n_chance && !flag( "sq_tpo_found_item" );
    level.sq_tpo.times_searched++;
    return b_found_item;
}

// Powerups Buried drops from zombies (zm_buried include_powerups).
buriedfullgame_drop_options()
{
    options = spawnstruct();
    options.weapons = [];
    options.labels = [];
    buriedfullgame_add_option(options, "", "random");
    buriedfullgame_add_option(options, "full_ammo", "Max Ammo");
    buriedfullgame_add_option(options, "insta_kill", "Insta-Kill");
    buriedfullgame_add_option(options, "double_points", "Double Points");
    buriedfullgame_add_option(options, "nuke", "Nuke");
    buriedfullgame_add_option(options, "fire_sale", "Fire Sale");
    buriedfullgame_add_option(options, "carpenter", "Carpenter");
    return options;
}

// After each Infinity round (special_round_end has restored the time bomb's
// saved data by then), the next drop of the powerup cycle is the chosen one: it
// swaps places with whatever was next, as O-Prac's nuke swap.
buriedfullgame_special_round_drop()
{
    while(true)
    {
        level waittill("sq_tpo_special_round_ended");
        options = buriedfullgame_drop_options();
        choice = get_cfg_int("special_round_drop");
        if(choice <= 0 || choice >= options.weapons.size) continue;

        powerup = options.weapons[choice];
        next = level.zombie_powerup_index;
        if(next >= level.zombie_powerup_array.size) next = 0;
        for(i = 0; i < level.zombie_powerup_array.size; i++)
        {
            if(level.zombie_powerup_array[i] != powerup) continue;
            level.zombie_powerup_array[i] = level.zombie_powerup_array[next];
            level.zombie_powerup_array[next] = powerup;
            println("B-Prac: next drop " + powerup);
            break;
        }
    }
}

/*##############################################################################
                              Maze switches
##############################################################################*/
// Richtofen's maze lever step (zm_buried_sq_ip). Lever n sits on the wall of
// the n-th blocker of the maze's active layout (a lever with no wall in the
// layout stays at its own struct). Each maze change re-places the levers and
// rolls their side, a wrong attempt resets them, the solution order is rolled
// once when the step starts.

// Vanilla init_maze_permutations layouts, in its order (layout 1 is the first).
buriedfullgame_maze_layouts()
{
    return array( array( "blocker_1", "blocker_2", "blocker_3", "blocker_4" ), array( "blocker_5", "blocker_6", "blocker_7", "blocker_8", "blocker_9" ), array( "blocker_1", "blocker_10", "blocker_6", "blocker_4", "blocker_11" ), array( "blocker_1", "blocker_3", "blocker_4", "blocker_12" ), array( "blocker_5", "blocker_6", "blocker_12", "blocker_13" ), array( "blocker_4", "blocker_6", "blocker_14" ) );
}

// Maze layout: a one-layout list makes vanilla maze_do_perm_change always pick
// it (it reshuffles the list at its end), so every maze change keeps that
// layout, from the first change on.
buriedfullgame_lock_maze()
{
    choice = get_cfg_int("maze_layout");
    layouts = buriedfullgame_maze_layouts();
    if(choice <= 0 || choice > layouts.size || !isdefined(level._maze)) return;

    level._maze._perms = array(layouts[choice - 1]);
    level._maze._cur_perm = 0;
}

// is_flip for lever n_index on a wall whose right vector is v_right. Side
// N / W puts the lever on the north face of an east-west wall or the west face
// of a north-south wall (north = +y, east = +x, to confirm in game).
buriedfullgame_lever_flip(n_index, v_right)
{
    side = get_cfg_int("switch_side_" + (n_index + 1));
    if(side != SIDE_NORTH_WEST && side != SIDE_SOUTH_EAST) return randomint(2);

    if(v_right[1] * v_right[1] >= v_right[0] * v_right[0])
        right_is_north_west = v_right[1] > 0;
    else
        right_is_north_west = v_right[0] < 0;

    // Unflipped, vanilla offsets the lever along +right.
    want_north_west = side == SIDE_NORTH_WEST;
    return int(right_is_north_west != want_north_west);
}

// OVERRIDE: maps\mp\zm_buried_sq_ip::sq_ml_spawn_lever
buriedfullgame_sq_ml_spawn_lever( n_index )
{
    m_lever = spawn( "script_model", ( 0, 0, 0 ) );
    m_lever setmodel( self.model );
    m_lever.targetname = "sq_ml_lever";
    //MODIFIED: the lever keeps its number for the Switch settings (getentarray
    // order is not the struct order).
    m_lever.buriedfullgame_index = n_index;
    //MODIFIED END

    while ( true )
    {
        v_spot = self.origin;
        v_angles = self.angles;

        if ( isdefined( level._maze._active_perm_list[n_index] ) )
        {
            s_spot = getstruct( level._maze._active_perm_list[n_index], "script_noteworthy" );
            v_right = anglestoright( s_spot.angles );
            //MODIFIED: Switch side setting.
            is_flip = buriedfullgame_lever_flip( n_index, v_right );
            //MODIFIED END
            v_offset = vectornormalize( v_right ) * 2;

            if ( is_flip )
                v_offset = v_offset * -1;

            v_spot = s_spot.origin + vectorscale( ( 0, 0, 1 ), 48.0 ) + v_offset;
            v_angles = s_spot.angles + vectorscale( ( 0, 1, 0 ), 90.0 );

            if ( is_flip )
                v_angles = s_spot.angles - vectorscale( ( 0, 1, 0 ), 90.0 );

            println( "B-Prac: switch " + ( n_index + 1 ) + " on " + level._maze._active_perm_list[n_index] + " at " + v_spot + " flip " + is_flip );
        }

        m_lever.origin = v_spot;
        m_lever.angles = v_angles;
        level waittill( "zm_buried_maze_changed" );
    }
}

// Solution order: lever with Switch n flipped = k is the k-th to flip. Set
// values are kept unless two switches claim the same place (the later one goes
// random), the rest take the free places at random.
buriedfullgame_set_lever_order(a_levers)
{
    n = a_levers.size;
    taken = [];
    order = [];
    for(i = 0; i < n; i++)
    {
        index = i;
        if(isdefined(a_levers[i].buriedfullgame_index)) index = a_levers[i].buriedfullgame_index;
        c = get_cfg_int("switch_order_" + (index + 1)) - 1;
        if(c >= 0 && c < n && !isdefined(taken[c]))
        {
            order[i] = c;
            taken[c] = 1;
        }
    }

    free = [];
    for(c = 0; c < n; c++)
        if(!isdefined(taken[c])) free[free.size] = c;
    free = array_randomize(free);

    next = 0;
    for(i = 0; i < n; i++)
    {
        if(!isdefined(order[i]))
        {
            order[i] = free[next];
            next++;
        }
        a_levers[i].n_lever_order = order[i];
        index = i;
        if(isdefined(a_levers[i].buriedfullgame_index)) index = a_levers[i].buriedfullgame_index;
        println("B-Prac: switch " + (index + 1) + " is flipped " + (order[i] + 1));
    }
}

// OVERRIDE: maps\mp\zm_buried_sq_ip::sq_ml_puzzle_logic
buriedfullgame_sq_ml_puzzle_logic()
{
    a_levers = getentarray( "sq_ml_lever", "targetname" );
    level.sq_ml_curr_lever = 0;
    //MODIFIED: Switch flipped settings instead of array_randomize.
    buriedfullgame_set_lever_order( a_levers );
    //MODIFIED END

    while ( true )
    {
        level.sq_ml_curr_lever = 0;
        maps\mp\zm_buried_sq_ip::sq_ml_puzzle_wait_for_levers();
        n_correct = 0;

        foreach ( m_lever in a_levers )
        {
            if ( m_lever.n_flip_number == m_lever.n_lever_order )
            {
                playfxontag( level._effect["sq_spark"], m_lever, "tag_origin" );
                n_correct++;
                m_lever playsound( "zmb_sq_maze_correct_spark" );
            }
        }

        if ( n_correct == a_levers.size )
            flag_set( "sq_ip_puzzle_complete" );

        level waittill( "zm_buried_maze_changed" );
        level notify( "sq_ml_reset_levers" );
        wait 1;
    }
}

/*##############################################################################
                              3% drops
##############################################################################*/
// OVERRIDE: maps\mp\zombies\_zm_powerups::powerup_drop
buriedfullgame_powerup_drop( drop_point )
{
    if ( level.powerup_drop_count >= level.zombie_vars["zombie_powerup_drop_max_per_round"] )
        return;

    if ( !isdefined( level.zombie_include_powerups ) || level.zombie_include_powerups.size == 0 )
        return;

    rand_drop = randomint( 100 );

    //MODIFIED: 3% drops can be turned off.
    if ( !get_cfg_int( "percent_drops" ) )
        rand_drop = 69;
    //MODIFIED END

    if ( rand_drop > 2 )
    {
        if ( !level.zombie_vars["zombie_drop_item"] )
            return;

        debug = "score";
    }
    else
        debug = "random";

    playable_area = getentarray( "player_volume", "script_noteworthy" );
    level.powerup_drop_count++;
    powerup = maps\mp\zombies\_zm_net::network_safe_spawn( "powerup", 1, "script_model", drop_point + vectorscale( ( 0, 0, 1 ), 40.0 ) );
    valid_drop = 0;

    for ( i = 0; i < playable_area.size; i++ )
    {
        if ( powerup istouching( playable_area[i] ) )
            valid_drop = 1;
    }

    if ( valid_drop && level.rare_powerups_active )
    {
        pos = ( drop_point[0], drop_point[1], drop_point[2] + 42 );

        if ( maps\mp\zombies\_zm_powerups::check_for_rare_drop_override( pos ) )
        {
            level.zombie_vars["zombie_drop_item"] = 0;
            valid_drop = 0;
        }
    }

    if ( !valid_drop )
    {
        level.powerup_drop_count--;
        powerup delete();
        return;
    }

    powerup maps\mp\zombies\_zm_powerups::powerup_setup();
    maps\mp\zombies\_zm_powerups::print_powerup_drop( powerup.powerup_name, debug );
    powerup thread maps\mp\zombies\_zm_powerups::powerup_timeout();
    powerup thread maps\mp\zombies\_zm_powerups::powerup_wobble();
    powerup thread maps\mp\zombies\_zm_powerups::powerup_grab();
    powerup thread maps\mp\zombies\_zm_powerups::powerup_move();
    powerup thread maps\mp\zombies\_zm_powerups::powerup_emp();
    level.zombie_vars["zombie_drop_item"] = 0;
    level notify( "powerup_dropped", powerup );
}
