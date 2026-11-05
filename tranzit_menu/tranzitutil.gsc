#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              TranZit mode helpers
##############################################################################*/
// Code more than one TranZit mode uses: the Denizen lights and the drop
// settings (3% drops, the first kill of the ending drops a Max Ammo).

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
    return array("bus depot", "diner", "cornfield", "forest", "depot bridge", "town bridge", "hunter's shack", "power station");
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
                              Drops
##############################################################################*/
// "percent_drops" off: only point drops (vanilla also drops on 3% of kills).
// "ending_max": once a mode arms it (tranzit_arm_ending_max), the next drop
// comes on the first kill and is a Max Ammo, if one is still ahead in the drop
// cycle. Otherwise the cycle stays as it is and the setting does nothing.
tranzit_drops_install()
{
    replacefunc(maps\mp\zombies\_zm_powerups::powerup_drop, ::tranzit_powerup_drop);
    level.tranzit_ending_max_armed = false;
}

tranzit_drop_defaults(settings_ar)
{
    settings_ar["percent_drops"] = 1;
    settings_ar["ending_max"] = 1;
    return settings_ar;
}

tranzit_drop_menu(menu)
{
    add_cfg_toggle(menu, "3% drops", "percent_drops", "^2Yes", "^1No");
    add_cfg_toggle(menu, "First kill ending Max", "ending_max", "^2Yes", "^1No");
}

tranzit_arm_ending_max()
{
    if(!get_cfg_int("ending_max")) return;

    index = tranzit_powerup_index("full_ammo");
    if(index < level.zombie_powerup_index)
    {
        iprintln("T-Prac: no Max Ammo left in this drop cycle");
        return;
    }
    level.tranzit_ending_max_armed = true;
}

tranzit_powerup_index(powerup)
{
    for(i = 0; i < level.zombie_powerup_array.size; i++)
        if(level.zombie_powerup_array[i] == powerup) return i;
    return -1;
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

    // The ending Max: this kill drops, and the Max Ammo is moved to the front of
    // what is left of the cycle (it was checked to be there when armed).
    ending_max = level.tranzit_ending_max_armed;
    if ( ending_max )
    {
        rand_drop = 0;
        index = tranzit_powerup_index( "full_ammo" );
        if ( index > level.zombie_powerup_index )
        {
            level.zombie_powerup_array[index] = level.zombie_powerup_array[level.zombie_powerup_index];
            level.zombie_powerup_array[level.zombie_powerup_index] = "full_ammo";
        }
    }
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

    //MODIFIED: a drop out of the playable area leaves the Max for the next kill.
    if ( ending_max )
        level.tranzit_ending_max_armed = false;
    //MODIFIED END

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
