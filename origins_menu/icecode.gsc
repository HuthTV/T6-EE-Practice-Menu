#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\origins_menu\oprac;

icecode_initialize()
{
    // Initialize icecode-specific cfg system
    mode_cfg_load("icecode", icecode_default_cfg());
}

icecode_run()
{
    flag_wait("initial_players_connected");
    setDvar("timescale", 10);
    gaming = get_players()[0];
    level thread icecode_open_map();
    level thread icecode_portals();
    level thread icecode_round_increment();
    gaming thread icecode_perks_weapons();
    gaming thread icecode_start_teleport();
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
    gaming freezecontrols( 1 );
    gaming setorigin((3048, 4408, -605));
    wait 12.5;
    setDvar("timescale", 1);
    wait 0.5; // Normal speed for 500 ms before the player is released.
    gaming freezecontrols( 0 );
}

icecode_build_menu(root)
{
	settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
		create_option(settings, "RLACE: ^3 s", ::menu_not_implemented);
}

icecode_perks_weapons()
{
    self maps\mp\zombies\_zm_perks::give_perk("specialty_longersprint");
    wait 0.05;
    self maps\mp\zombies\_zm_perks::give_perk("specialty_armorvest");
    wait 0.05;
    self maps\mp\zombies\_zm_perks::give_perk("specialty_additionalprimaryweapon");
    wait 0.05;
    self giveWeapon("mp40_zm");
    wait 0.05;
    self giveWeapon("staff_water_zm");
    wait 0.05;
    self switchToWeapon("c96_zm");
    wait 0.05;
    self upgrade_weapon();
    //self takeweapon("c96_zm");
    //self giveWeapon("c96_upgraded_zm");
    wait 0.05;
    self thread maps\mp\zombies\_zm_weap_one_inch_punch::one_inch_punch_melee_attack();
    wait 0.05;
    self switchToWeapon("staff_water_zm");
    flag_wait("initial_blackscreen_passed");
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_water", "gem");
}

icecode_start_teleport()
{
        flag("initial_blackscreen_passed");
        self setorigin((3048, 4408, -605));
}

icecode_portals()
{
	flag("initial_blackscreen_passed");

    a_stargate_gramophones = getstructarray( "stargate_gramophone_pos", "targetname" );
    stargate_index = 0; //0 fire | 1 ice | 2 wind | 3 blixt
    script_num = a_stargate_gramophones[stargate_index].script_int;

    a_stargate_gramophones[stargate_index].gramophone_model = spawn( "script_model", a_stargate_gramophones[stargate_index].origin );
    a_stargate_gramophones[stargate_index].gramophone_model.angles = a_stargate_gramophones[stargate_index].angles;
    a_stargate_gramophones[stargate_index].gramophone_model setmodel( "p6_zm_tm_gramophone" );
    level setclientfield( "piece_record_zm_player", 0 );
    flag_set( "gramophone_placed" );
    maps\mp\zm_tomb_teleporter::stargate_teleport_enable( script_num );

    flag_wait( "teleporter_building_" + script_num );
    flag_waitopen( "teleporter_building_" + script_num );

    if ( isdefined( a_stargate_gramophones[stargate_index].script_flag ) )
        flag_set( a_stargate_gramophones[stargate_index].script_flag );

    level notify( "player_teleported", get_players()[0], 0 );
    level notify( "player_teleported", get_players()[0], 1 );
    level notify( "player_teleported", get_players()[0], 2 );
    level notify( "player_teleported", get_players()[0], 3 );
}

icecode_open_map( path )
{
    setdvar( "zombie_unlock_all", 1 );
    players = get_players();

    doors = array((-732, 2240, -64), (-864, 3168, -208), (-224, 2792, -200), (2416, 4336, -264), (384, 3472, -248), (1216, 2880, -168));
    zombie_doors = getentarray( "zombie_door", "targetname" );
    for( i = 0; i < zombie_doors.size; i++ )
    {
        foreach( unlock_door in doors)
        {
            if( zombie_doors[i].origin == unlock_door)
                zombie_doors[i] notify( "trigger", players[0] );
        }
        wait 0.05;
    }

    zombie_debris = getentarray( "zombie_debris", "targetname" );
    foreach( debris in zombie_debris)
    {
        debris notify( "trigger", players[0] );
        wait 0.05;
    }

    setdvar( "zombie_unlock_all", 0 );
}

icecode_round_increment()
{
    level waittill("start_of_round");
    set_round = 11;
    level.zombie_total = 0;
    maps\mp\zombies\_zm::ai_calculate_health(set_round - 1);
    level.round_number = (set_round - 1);
    zombies = get_round_enemy_array();
    if (isDefined(zombies))
    {
        for (i = 0; i < zombies.size + 1; i++)
            zombies[i] dodamage(zombies[i].health + 666, zombies[i].origin);
    }
    level waittill("start_of_round");
    delay = 2;
    for (i = 1; i <= level.round_number; i++) delay *= 0.95;
    level.zombie_vars["zombie_spawn_delay"] = delay;
}

icecode_default_cfg()
{
	settings_ar = [];

	// Basic icecode settings - can be expanded as needed
	// Currently no icecode-specific dvars to convert

	return settings_ar;
}
