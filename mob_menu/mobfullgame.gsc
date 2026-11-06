#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\mob_menu\mobsplits;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Mob Fullgame
##############################################################################*/
// A normal game from round 1 with the RNG and Box settings of the old
// M-Practice: key location, door spawn, second drop nuke, 3% drops and the box.

#define KEY_RANDOM   0
#define KEY_EAST     1      // Old M-Practice "cafe_key" on (vanilla "east" pulley).
#define KEY_WEST     2

#define BOX_RANDOM   0
#define BOX_CAFE     1      // Chest "cafe_chest"
#define BOX_WARDEN   2      // Chest "start_chest" (the old tool's "warden")

mobfullgame_initialize()
{
    mode_cfg_load("mobfullgame", mobfullgame_default_cfg());
    replacefunc(maps\mp\zm_alcatraz_sq::setup_master_key, ::mobfullgame_setup_master_key);
    replacefunc(maps\mp\zombies\_zm_powerups::powerup_drop, ::mobfullgame_powerup_drop);
    replacefunc(maps\mp\zombies\_zm::getfreespawnpoint, ::mobfullgame_getfreespawnpoint);
    level thread mob_split_clock_watch();
}

mobfullgame_run()
{
    flag_wait("initial_blackscreen_passed");
    level thread mobfullgame_start_box_location();
    if(get_cfg_int("box_mk2_only")) mobfullgame_mk2_box();
    if(get_cfg_int("second_drop_nuke")) level thread mobfullgame_second_drop_nuke();
    level thread mob_split_timer(MOB_SPLIT_DRYER);
    flag_set("menu_active");
}

mobfullgame_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_choice(settings, "Key Location", "key_location", array("random", "east (cafe)", "west"));
        add_cfg_choice(settings, "Door Spawn", "door_spawn_spot", array("random", "1", "2", "3", "4"));
        add_cfg_toggle(settings, "Second Drop Nuke", "second_drop_nuke");
        add_cfg_toggle(settings, "3% Drops Round 1", "round1_percent_drops");
        add_cfg_toggle(settings, "3% Drops", "percent_drops");
    box = add_submenu(settings, "box", "Box");
        add_cfg_choice(box, "Location", "box_start", array("random", "cafe", "warden"));
        add_cfg_toggle(box, "MK2 Only", "box_mk2_only");
}

// Defaults are the old M-Practice dvar defaults, but for the box (user, 2026-11-05:
// new keys, so these reach saved cfgs).
mobfullgame_default_cfg()
{
    settings_ar = [];
    settings_ar["key_location"] = KEY_EAST;
    settings_ar["door_spawn_spot"] = 0;
    settings_ar["second_drop_nuke"] = 1;
    settings_ar["round1_percent_drops"] = 0;
    settings_ar["percent_drops"] = 1;
    settings_ar["box_start"] = BOX_CAFE;
    settings_ar["box_mk2_only"] = 1;
    return settings_ar;
}

// The second drop of the cycle is a nuke; the rest stay random.
mobfullgame_second_drop_nuke()
{
    level waittill("start_of_round");
    drops = array_randomize(array("full_ammo", "insta_kill", "double_points", "fire_sale"));
    level.zombie_powerup_array[0] = drops[0];
    level.zombie_powerup_array[1] = "nuke";
    level.zombie_powerup_array[2] = drops[1];
    level.zombie_powerup_array[3] = drops[2];
    level.zombie_powerup_array[4] = drops[3];
}

// The box only gives the Ray Gun Mark II.
mobfullgame_mk2_box()
{
    foreach(weapon in level.zombie_weapons)
        weapon.is_in_box = 0;
    level.special_weapon_magicbox_check = undefined;
    level.zombie_weapons["raygun_mark2_zm"].is_in_box = 1;
}

// Moves the starting box to the chosen chest.
mobfullgame_start_box_location()
{
    switch(get_cfg_int("box_start"))
    {
        case BOX_CAFE:   start_chest = "cafe_chest";  break;
        case BOX_WARDEN: start_chest = "start_chest"; break;
        default:         return;
    }

    desired_chest_index = undefined;
    shown_chest_index = undefined;
    for(i = 0; i < level.chests.size; i++)
    {
        if(level.chests[i].script_noteworthy == start_chest)
            desired_chest_index = i;
        else if(!level.chests[i].hidden)
            shown_chest_index = i;
    }
    if(!isdefined(desired_chest_index) || !isdefined(shown_chest_index)) return;

    level.chests[shown_chest_index] maps\mp\zombies\_zm_magicbox::hide_chest();
    level.chests[shown_chest_index].hidden = 1;
    level.chests[desired_chest_index].hidden = 0;
    level.chests[desired_chest_index] maps\mp\zombies\_zm_magicbox::show_chest();
    level.chest_index = desired_chest_index;
}

/*##############################################################################
                              Overrides
##############################################################################*/
// OVERRIDE: maps\mp\zm_alcatraz_sq::setup_master_key
mobfullgame_setup_master_key()
{
    //MODIFIED: Key location setting.
    switch ( get_cfg_int( "key_location" ) )
    {
        case KEY_EAST: level.is_master_key_west = 0; break;
        case KEY_WEST: level.is_master_key_west = 1; break;
        default:       level.is_master_key_west = randomintrange( 0, 2 ); break;
    }
    //MODIFIED END
    setclientfield( "fake_master_key", level.is_master_key_west + 1 );

    if ( level.is_master_key_west )
    {
        level thread maps\mp\zm_alcatraz_sq::key_pulley( "west" );
        exploder( 101 );
        array_delete( getentarray( "wires_pulley_east", "script_noteworthy" ) );
    }
    else
    {
        level thread maps\mp\zm_alcatraz_sq::key_pulley( "east" );
        exploder( 100 );
        array_delete( getentarray( "wires_pulley_west", "script_noteworthy" ) );
    }
}

// OVERRIDE: maps\mp\zombies\_zm_powerups::powerup_drop
mobfullgame_powerup_drop( drop_point )
{
    if ( level.powerup_drop_count >= level.zombie_vars["zombie_powerup_drop_max_per_round"] )
    {
        return;
    }

    if ( !isdefined( level.zombie_include_powerups ) || level.zombie_include_powerups.size == 0 )
        return;

    rand_drop = randomint( 100 );

    //MODIFIED: 3% drops can be turned off, always or on round 1 only.
    if ( !get_cfg_int( "percent_drops" ) || level.round_number == 1 && !get_cfg_int( "round1_percent_drops" ) )
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

// OVERRIDE: maps\mp\zombies\_zm::getfreespawnpoint
mobfullgame_getfreespawnpoint( spawnpoints, player )
{
    if ( !isdefined( spawnpoints ) )
    {
        return undefined;
    }

    //MODIFIED: Door spawn: solo always starts at a spawn point by the cell doors
    // (indexes from the old M-Practice), the chosen one or a random one.
    if ( is_true( level.is_forever_solo_game ) )
    {
        door_spawns = array( 3, 4, 6, 7 );
        door = get_cfg_int( "door_spawn_spot" ) - 1;

        if ( door < 0 || door >= door_spawns.size )
            door = randomint( door_spawns.size );

        index = door_spawns[door];

        if ( index < spawnpoints.size )
        {
            println( "M-Prac: door spawn " + ( door + 1 ) + " at " + spawnpoints[index].origin );
            return spawnpoints[index];
        }
    }
    //MODIFIED END

    if ( !isdefined( game["spawns_randomized"] ) )
    {
        game["spawns_randomized"] = 1;
        spawnpoints = array_randomize( spawnpoints );
        random_chance = randomint( 100 );

        if ( random_chance > 50 )
            set_game_var( "side_selection", 1 );
        else
            set_game_var( "side_selection", 2 );
    }

    side_selection = get_game_var( "side_selection" );

    if ( get_game_var( "switchedsides" ) )
    {
        if ( side_selection == 2 )
            side_selection = 1;
        else if ( side_selection == 1 )
            side_selection = 2;
    }

    if ( isdefined( player ) && isdefined( player.team ) )
    {
        i = 0;

        while ( isdefined( spawnpoints ) && i < spawnpoints.size )
        {
            if ( side_selection == 1 )
            {
                if ( player.team != "allies" && ( isdefined( spawnpoints[i].script_int ) && spawnpoints[i].script_int == 1 ) )
                {
                    arrayremovevalue( spawnpoints, spawnpoints[i] );
                    i = 0;
                }
                else if ( player.team == "allies" && ( isdefined( spawnpoints[i].script_int ) && spawnpoints[i].script_int == 2 ) )
                {
                    arrayremovevalue( spawnpoints, spawnpoints[i] );
                    i = 0;
                }
                else
                    i++;
            }
            else if ( player.team == "allies" && ( isdefined( spawnpoints[i].script_int ) && spawnpoints[i].script_int == 1 ) )
            {
                arrayremovevalue( spawnpoints, spawnpoints[i] );
                i = 0;
            }
            else if ( player.team != "allies" && ( isdefined( spawnpoints[i].script_int ) && spawnpoints[i].script_int == 2 ) )
            {
                arrayremovevalue( spawnpoints, spawnpoints[i] );
                i = 0;
            }
            else
                i++;
        }
    }

    if ( !isdefined( self.playernum ) )
    {
        if ( self.team == "allies" )
        {
            self.playernum = get_game_var( "_team1_num" );
            set_game_var( "_team1_num", self.playernum + 1 );
        }
        else
        {
            self.playernum = get_game_var( "_team2_num" );
            set_game_var( "_team2_num", self.playernum + 1 );
        }
    }

    for ( j = 0; j < spawnpoints.size; j++ )
    {
        if ( !isdefined( spawnpoints[j].en_num ) )
        {
            for ( m = 0; m < spawnpoints.size; m++ )
                spawnpoints[m].en_num = m;
        }

        if ( spawnpoints[j].en_num == self.playernum )
            return spawnpoints[j];
    }

    return spawnpoints[0];
}
