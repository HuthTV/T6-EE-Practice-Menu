#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\victis;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              TranZit mode helpers
##############################################################################*/
// Code more than one TranZit mode uses: the Denizen lights and teleports and the
// drop settings (3% drops, the EMPs Max Ammo).

/*##############################################################################
                              Denizen lights
##############################################################################*/
// The lamp posts (structs "screecher_escape") named by their script_noteworthy,
// the names vanilla set_screecher_zone_origin (zm_transit_sq) knows. A Denizen
// hole opens under a powered one and teleports the player to another.
tranzit_light_names()
{
    return array("busdepot", "diner", "cornfield", "forest", "bridgedepot", "townbridge", "huntershack", "powerstation");
}

// Menu text, in tranzit_light_names order.
tranzit_light_labels()
{
    return array("bus depot", "diner", "cornfield", "shortcut", "depot bridge", "town bridge", "hunter's shack", "power station");
}

// The light with that script_noteworthy, or undefined.
tranzit_light(name)
{
    foreach(light in getstructarray("screecher_escape", "targetname"))
        if(isdefined(light.script_noteworthy) && light.script_noteworthy == name)
            return light;
    return undefined;
}

// A setting holding 1 + an index into tranzit_light_names (0 is random): its
// light, or undefined for random or a name the map does not have.
tranzit_light_setting(value)
{
    names = tranzit_light_names();
    if(value < 1 || value > names.size) return undefined;
    light = tranzit_light(names[value - 1]);
    if(!isdefined(light)) print("T-Prac: no Denizen light named " + names[value - 1]);
    return light;
}

/*##############################################################################
                              Denizen teleports
##############################################################################*/
// Rows that pick the light each of the next teleports goes to, "teleport_<n>" in
// the mode cfg, 0 random. Later teleports are random as vanilla.
tranzit_teleports_install(rows)
{
    level.tranzit_teleport_rows = rows;
    level.tranzit_teleports = 0;
    replacefunc(maps\mp\zm_transit_ai_screecher::teleport_player, ::tranzit_teleport_player);
}

tranzit_teleport_defaults(settings_ar)
{
    for(i = 1; i <= level.tranzit_teleport_rows; i++)
        settings_ar["teleport_" + i] = 0;
    return settings_ar;
}

tranzit_teleport_menu(menu)
{
    lights = combinearrays(array("random"), tranzit_light_labels());
    for(i = 1; i <= level.tranzit_teleport_rows; i++)
        add_cfg_choice(menu, "Teleport " + i, "teleport_" + i, lights);
}

// OVERRIDE: maps\mp\zm_transit_ai_screecher::teleport_player
// self is the light whose hole the player jumped in.
tranzit_teleport_player( player )
{
    lights = getstructarray( "screecher_escape", "targetname" );
    lights = array_randomize( lights );
    dest_light = undefined;

    //MODIFIED: the teleport rows pick this teleport's light. One that is the light
    // the player left, or has another player close, is not valid, and the teleport
    // goes to a random light as vanilla.
    level.tranzit_teleports++;
    n = level.tranzit_teleports;
    if ( n <= level.tranzit_teleport_rows )
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
        //MODIFIED: Ending EMP's landing check reads these.
        player.tranzit_arrival_light = dest_light;
        player.tranzit_arrival_time = gettime();
        //MODIFIED END
        player notify( "used_screecher_hole" );
        player maps\mp\zombies\_zm_stats::increment_client_stat( "screecher_teleporters_used", 0 );
        player maps\mp\zombies\_zm_stats::increment_player_stat( "screecher_teleporters_used" );
    }
}

/*##############################################################################
                              Drops
##############################################################################*/
// "percent_drops" off: only point drops (vanilla also drops on 3% of kills).
// "emps_max": as Buried's Max After Round Infinity, the Max Ammo waits at the end of
// the drop cycle (victis.gsc) and tranzit_release_emps_max makes it the next drop.
tranzit_drops_install()
{
    replacefunc(maps\mp\zombies\_zm_powerups::powerup_drop, ::tranzit_powerup_drop);
    victis_max_install("emps_max");
}

tranzit_drop_defaults(settings_ar)
{
    settings_ar["percent_drops"] = 1;
    settings_ar["emps_max"] = 1;
    return settings_ar;
}

tranzit_drop_menu(menu)
{
    add_cfg_toggle(menu, "3% Drops", "percent_drops");
    add_cfg_toggle(menu, "EMPs Max Ammo", "emps_max");
}

tranzit_release_emps_max()
{
    victis_max_release(true);
}

// OVERRIDE: maps\mp\zombies\_zm_powerups::powerup_drop
tranzit_powerup_drop( drop_point )
{
    if ( level.powerup_drop_count >= level.zombie_vars["zombie_powerup_drop_max_per_round"] )
    {
        return;
    }

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
