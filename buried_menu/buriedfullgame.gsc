#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\victis;
#include scripts\zm\buried_menu\buriedquest;
#include scripts\zm\buried_menu\buriedsplits;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Buried Fullgame
##############################################################################*/
// A normal game from round 1 with the run's RNG set: the hit of each route gun,
// 3% drops, whether the first ghost round's perk is Vulture Aid, the Infinity round
// (Richtofen time bomb round of zm_buried_sq_tpo: body spots, which search finds
// the switch, the 1% bodies, the Max Ammo after it) and the switches of
// zm_buried_sq_ip (maze layout, side and order by colour), which tunnel signs each
// side punches and Richtofen's wisp path, and Maxis's bell order. The fridge and the
// solo time bomb fix are map settings (Victis Settings, buried.gsc).

#define BOX_LAST_HIT      8     // Vanilla's first box always moves on hit 9.
#define CORPSES           4     // Vanilla get_randomized_corpse_list has four bodies.
#define VULTURE_AID       "specialty_nomotionsensor"

#define BELLS             9     // sq_bp_button structs, script_string light_01 to light_09.

buriedfullgame_initialize()
{
    replacefunc(maps\mp\zombies\_zm_powerups::powerup_drop, ::buriedfullgame_powerup_drop);
    replacefunc(maps\mp\zombies\_zm_powerups::free_perk_powerup, ::buriedfullgame_free_perk_powerup);
    replacefunc(maps\mp\zm_buried_sq_tpo::setup_random_corpse_positions, ::buriedfullgame_setup_random_corpse_positions);
    replacefunc(maps\mp\zm_buried_sq_tpo::item_is_on_corpse, ::buriedfullgame_item_is_on_corpse);
    replacefunc(maps\mp\zm_buried_sq_ip::sq_bp_start_puzzle_lights, ::buriedfullgame_sq_bp_start_puzzle_lights);
    buried_quest_install();
    buried_maze_install();
    victis_box_install(::buriedfullgame_box_gun_due);
    victis_max_install("infinity_max");
    level.buriedfullgame_ghost_perks = 0;
    mode_cfg_load("buriedfullgame", buriedfullgame_default_cfg());

    // Read when they happen, so they need no restart. The Max is placed from the
    // start of the game, the layout locked once and the signs set at map load.
    level.practice_map.live_cfg_keys = [];
    foreach(key in getarraykeys(level.mode_cfg_defaults))
        if(key != "infinity_max" && key != "maze_layout" && !issubstr(key, "sign_"))
            level.practice_map.live_cfg_keys[level.practice_map.live_cfg_keys.size] = key;
}

buriedfullgame_run()
{
    // zm_buried main sets its own (pass-through) weights, so this goes after it.
    level.customrandomweaponweights = ::buriedfullgame_box_hit_weights;
    level._zombiemode_chest_joker_chance_override_func = ::buriedfullgame_box_joker_chance;
    victis_max_hold();
    level thread buriedfullgame_infinity_max();

    flag_wait("initial_blackscreen_passed");
    buried_lock_maze();
    flag_set("menu_active");
    level thread buried_split_timer(BURIED_SPLIT_BOXHIT);
}

buriedfullgame_default_cfg()
{
    settings_ar = [];
    settings_ar["percent_drops"] = 1;
    settings_ar["box_paralyzer"] = 1;      // The route's first three hits (user, 2026-11-03).
    settings_ar["box_time_bomb"] = 2;
    settings_ar["box_knife"] = 3;
    settings_ar["ghost_vulture"] = 1;
    for(i = 1; i <= CORPSES; i++)
        settings_ar["body_spot_" + i] = 0;
    settings_ar["switch_found"] = 0;
    settings_ar["percent_bodies"] = 1;
    settings_ar["infinity_max"] = 0;
    settings_ar = buried_maze_defaults(settings_ar);
    settings_ar = buried_quest_defaults(settings_ar);
    for(i = 1; i <= BELLS; i++)
        settings_ar["bell_" + i] = 0;
    return settings_ar;
}

buriedfullgame_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_toggle(settings, "3% Drops", "percent_drops");
        add_cfg_toggle(settings, "Ghost Vulture", "ghost_vulture", "^2yes", "^3no");

        box = add_submenu(settings, "box", "Mystery Box", "Box");
            guns = buriedfullgame_box_guns();
            for(i = 0; i < guns.keys.size; i++)
                create_option(box, guns.labels[i] + ": ^3hit " + get_cfg_int(guns.keys[i]), ::buriedfullgame_box_hit_next, guns.keys[i]);

        special = add_submenu(settings, "infinity", "Infinity Round", "Infinity Round");
            spots = buriedfullgame_corpse_spot_labels();
            for(i = 1; i <= CORPSES; i++)
                buriedfullgame_add_choice(special, "Body " + i + " Spot", "body_spot_" + i, spots);
            // The 1st search can never find it (see item_is_on_corpse).
            add_cfg_choice(special, "Switch Search", "switch_found", array("random", "2nd", "3rd", "4th"));
            if(!get_cfg_int("switch_found"))
                add_cfg_toggle(special, "1% Bodies", "percent_bodies");
            add_cfg_toggle(special, "Max After Round Infinity", "infinity_max");

        maze = add_submenu(settings, "maze", "Switches");
            buried_maze_menu(maze);

        maxis = add_submenu(settings, "maxiswisp", "Maxis Signs & Wisp", "Maxis Wisp");
            buried_sign_menu(maxis, "max");
            add_cfg_toggle(maxis, "Lantern Teleports", "lantern_teleports");

        richtofen = add_submenu(settings, "ricwisp", "Richtofen Signs & Wisp", "Richtofen Wisp");
            buried_sign_menu(richtofen, "ric");
            buried_fork_menu(richtofen);

        bells = add_submenu(settings, "bells", "Maxis Bells", "Bells");
            lights = buriedfullgame_bell_labels();
            for(i = 1; i <= BELLS; i++)
                buriedfullgame_add_choice(bells, "Bell " + i, "bell_" + i, lights);
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
// The route's guns, in row order: cfg key, box weapon, menu label. The setting is
// the hit (1-8) on the first box that gives the gun.
buriedfullgame_box_guns()
{
    guns = spawnstruct();
    guns.keys = array("box_paralyzer", "box_time_bomb", "box_knife");
    guns.weapons = array("slowgun_zm", "time_bomb_zm", "knife_ballistic_zm");
    guns.labels = array("Paralyzer", "Time Bomb", "Ballistic Knife");
    return guns;
}

// Hit number to gun. A gun set on a hit an earlier row took goes on the next free hit.
buriedfullgame_box_schedule()
{
    guns = buriedfullgame_box_guns();
    schedule = [];
    for(i = 0; i < guns.keys.size; i++)
    {
        hit = get_cfg_int(guns.keys[i]);
        while(isdefined(schedule[hit]))
            hit = hit % BOX_LAST_HIT + 1;
        schedule[hit] = guns.weapons[i];
    }
    return schedule;
}

// Menu action: the next hit no other gun holds, so two rows never show the same hit.
buriedfullgame_box_hit_next(key)
{
    hit = get_cfg_int(key);
    for(i = 0; i < BOX_LAST_HIT; i++)
    {
        hit = hit % BOX_LAST_HIT + 1;
        if(!buriedfullgame_box_hit_taken(key, hit)) break;
    }
    self cfg_set_int(key, hit);
}

buriedfullgame_box_hit_taken(key, hit)
{
    guns = buriedfullgame_box_guns();
    foreach(other in guns.keys)
        if(other != key && get_cfg_int(other) == hit) return true;
    return false;
}

// The gun due on this hit, or undefined.
buriedfullgame_box_gun_due()
{
    schedule = buriedfullgame_box_schedule();
    return schedule[victis_box_hit()];
}

// As O-Prac's Hit 1/Hit 2: vanilla treasure_chest_chooseweightedrandomweapon gives
// the first weapon in this list the player can receive, so the gun due goes to the
// front. If the player cannot receive it (owned, limit reached), the box picks
// randomly as usual.
buriedfullgame_box_hit_weights(keys)
{
    gun = buriedfullgame_box_gun_due();
    if(!isdefined(gun)) return keys;

    forced = [];
    forced[0] = gun;
    foreach(key in keys) forced[forced.size] = key;
    return forced;
}

// Vanilla's box never moves in the first 4 hits. The first box stays until the last
// gun's hit is over, however late that is.
buriedfullgame_box_joker_chance(chance_of_joker)
{
    last = 0;
    foreach(hit in getarraykeys(buriedfullgame_box_schedule()))
        if(hit > last) last = hit;
    if(level.chest_moves == 0 && level.chest_accessed < last) return -1;
    return chance_of_joker;
}

/*##############################################################################
                              First ghost round perk
##############################################################################*/
// Ghost Vulture yes: Vulture Aid. No: a random perk that is never Vulture Aid, the
// way to practice the TROFA perk. Returns the perk, as give_random_perk does.
buriedfullgame_ghost_perk()
{
    if(get_cfg_int("ghost_vulture"))
    {
        if(!self buriedfullgame_can_get_perk(VULTURE_AID)) return self maps\mp\zombies\_zm_perks::give_random_perk();
        self maps\mp\zombies\_zm_perks::give_perk(VULTURE_AID);
        return VULTURE_AID;
    }

    perks = [];
    foreach(machine in getentarray("zombie_vending", "targetname"))
    {
        perk = machine.script_noteworthy;
        if(perk != "specialty_weapupgrade" && perk != VULTURE_AID && self buriedfullgame_can_get_perk(perk))
            perks[perks.size] = perk;
    }
    if(!perks.size)
    {
        self playsoundtoplayer(level.zmb_laugh_alias, self);
        return undefined;
    }

    perks = array_randomize(perks);
    self maps\mp\zombies\_zm_perks::give_perk(perks[0]);
    return perks[0];
}

// Vanilla give_random_perk's rule.
buriedfullgame_can_get_perk(perk)
{
    if(isdefined(self.perk_purchased) && self.perk_purchased == perk) return false;
    return !self hasperk(perk) && !self maps\mp\zombies\_zm_perks::has_perk_paused(perk);
}

// OVERRIDE: maps\mp\zombies\_zm_powerups::free_perk_powerup
buriedfullgame_free_perk_powerup( item )
{
    //MODIFIED: the first ghost round's perk (vanilla end_ghost_round marks it
    // ghost_powerup) follows the Ghost Vulture setting.
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

            //MODIFIED: Ghost Vulture
            if ( first_ghost_perk )
                free_perk = player buriedfullgame_ghost_perk();
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

    //MODIFIED: the switch is on the chosen search (1 is the 2nd).
    choice = get_cfg_int( "switch_found" );

    if ( choice > 0 )
    {
        b_found_item = level.sq_tpo.times_searched == choice && !flag( "sq_tpo_found_item" );
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

    //MODIFIED: 1% Bodies off: the last search always finds it.
    if ( level.sq_tpo.times_searched == 3 && !get_cfg_int( "percent_bodies" ) && !flag( "sq_tpo_found_item" ) )
        b_found_item = 1;
    //MODIFIED END

    level.sq_tpo.times_searched++;
    return b_found_item;
}

// Max After Round Infinity: the Max Ammo waits at the end of the drop cycle (victis.gsc)
// and is the next drop once the time bomb has brought the player back, after each
// Infinity round until one finds the switch.
buriedfullgame_infinity_max()
{
    while(true)
    {
        level waittill("sq_tpo_special_round_ended");
        victis_max_release(flag("sq_tpo_found_item"));
    }
}

/*##############################################################################
                              Maxis bells
##############################################################################*/
// Bell n is the n-th button the board asks for. The saved value is the light number
// (the struct's light_0n), 0 random. A light set on an earlier row counts as random.
// Each bell shows one word (user, 2026-11-10): its name in buriedfullgame_bell_names,
// or until the user names it, its zone's word ("2" added while two share a zone).
// Every bell is printed to the console so they can be named.
buriedfullgame_bell_labels()
{
    if(isdefined(level.buriedfullgame_bell_labels)) return level.buriedfullgame_bell_labels;

    names = buriedfullgame_bell_names();
    labels = array("random");
    for(i = 1; i <= BELLS; i++)
        labels[i] = "bell " + i;
    used = [];
    foreach(button in getstructarray("sq_bp_button", "targetname"))
    {
        n = int(getsubstr(button.script_string, 6, button.script_string.size));
        zone = maps\mp\zombies\_zm_zonemgr::get_zone_from_position(button.origin + (0, 0, 32), 1);
        if(names[n] != "")
            labels[n] = names[n];
        else if(isdefined(zone))
        {
            word = buriedfullgame_zone_word(zone);
            if(isdefined(used[word])) word += " 2";
            used[word] = true;
            labels[n] = word;
        }
        if(!isdefined(zone)) zone = "none";
        println("B-Prac: bell " + button.script_string + " " + zone + " " + button.origin + " shows " + labels[n]);
    }
    if(isdefined(level.zones)) level.buriedfullgame_bell_labels = labels;
    return labels;
}

// The user's names by light number (index 1-9, light_01 to light_09), named live with
// t6r_buried_bells.gsc (user, 2026-11-10).
buriedfullgame_bell_names()
{
    return array("", "Candy Chair", "Candy Pot", "Candy Table", "Stables Pitchfork", "Stables Plank", "Stables Wheel", "Court Table", "Court Witness", "Court Bench");
}

// A zone as one word for the bell rows.
buriedfullgame_zone_word(zone)
{
    switch(zone)
    {
        case "zone_candy_store":
        case "zone_candy_store_floor2":
            return "candy";
        case "zone_stables":
            return "stables";
        case "zone_underground_courthouse":
        case "zone_underground_courthouse2":
            return "courthouse";
    }
    return basegame_plain_zone_name(zone);
}

// a_tags in the order of the Bell rows, the rest shuffled into the free places.
buriedfullgame_bell_order(a_tags)
{
    used = [];
    order = [];
    for(i = 1; i <= BELLS; i++)
    {
        light = get_cfg_int("bell_" + i);
        if(!light) continue;
        tag = "light_0" + light;
        if(isdefined(used[tag])) continue;
        used[tag] = true;
        order[i - 1] = tag;
    }

    rest = [];
    foreach(tag in a_tags)
        if(!isdefined(used[tag])) rest[rest.size] = tag;
    rest = array_randomize(rest);

    result = [];
    next = 0;
    for(i = 0; i < a_tags.size; i++)
    {
        if(isdefined(order[i]))
        {
            result[i] = order[i];
            continue;
        }
        result[i] = rest[next];
        next++;
    }
    return result;
}

// OVERRIDE: maps\mp\zm_buried_sq_ip::sq_bp_start_puzzle_lights
buriedfullgame_sq_bp_start_puzzle_lights()
{
    level endon( "sq_bp_wrong_button" );
    level endon( "sq_bp_timeout" );
    a_button_structs = getstructarray( "sq_bp_button", "targetname" );
    a_tags = [];

    foreach ( m_button in a_button_structs )
        a_tags[a_tags.size] = m_button.script_string;

    //MODIFIED: Bell rows instead of array_randomize.
    a_tags = buriedfullgame_bell_order( a_tags );
    //MODIFIED END
    m_lightboard = getent( "sq_bp_board", "targetname" );

    if ( !isdefined( level.t_start ) )
        level.t_start = spawn( "trigger_radius_use", m_lightboard.origin, 0, 16, 16 );

    level.t_start setcursorhint( "HINT_NOICON" );
    level.t_start sethintstring( &"ZM_BURIED_SQ_SWIT_U" );
    level.t_start triggerignoreteam();
    level.t_start usetriggerrequirelookat();
    level.t_start waittill( "trigger" );
    level.t_start delete();

    foreach ( str_tag in a_tags )
    {
        wait_network_frame();
        wait_network_frame();
        level thread maps\mp\zm_buried_sq_ip::sq_bp_set_current_bulb( str_tag );
        level waittill( "sq_bp_correct_button" );
    }

    flag_set( "sq_ip_puzzle_complete" );
    a_button_structs = getstructarray( "sq_bp_button", "targetname" );

    foreach ( s_button in a_button_structs )
    {
        if ( isdefined( s_button.trig ) )
            s_button.trig delete();
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
