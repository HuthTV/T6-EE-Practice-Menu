#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\victis;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Buried map hooks
##############################################################################*/
// Everything Buried adds to the core menus and HUD (see practice_map in
// utility_core\basegame.gsc): the Victis Settings (utility_core\victis.gsc) with
// Buried's madeup scripts. Add hooks (build_hud, build_cheats, say_command,
// open_doors, run...) as the map gets features. Settings are saved in B_PRAC/.
buried_practice_map()
{
    map = practice_map("Huth's B-Practice", "Huth's Buried Practice Tool", "B_PRAC/", "b_menu_gamemode");
    map.accent_color = (0.76, 0.6, 0.42); // Western tan (user, 2026-11-04)
    // MTAR PaP (MMS): the B2EE timer's solo Buried fridge.
    victis_practice_map(map, "tar21_upgraded_zm+mms", ::buried_madeup_install);
    return map;
}

// The menu runs on classic Buried only (zm_buried also hosts other game modes).
buried_map_active()
{
    return is_classic();
}

/*##############################################################################
                              Madeup scripts
##############################################################################*/
// The B2EE timer's madeup set for Buried (it emulates Hadi77KSA's
// Plutonium-T6-Any-Player-EE-Scripts): the Infinity round's time bomb wants
// every player in the volume (vanilla 4), the wisp keeps its energy and the
// bulb buttons have no time limit under three players, Sharpshooter allows
// misses for the targets of the missing players, and the endgame machine
// counts the lights of the players in the game. Counts come from
// level.starting_player_count (victis_madeup_players). Installed by
// victis_initialize while the Madeup setting is on.
buried_madeup_install()
{
    replacefunc(maps\mp\zm_buried_sq::sq_metagame, ::buried_sq_metagame);
    replacefunc(maps\mp\zm_buried_sq_ctw::ctw_max_wisp_enery_watch, ::buried_ctw_max_wisp_enery_watch);
    replacefunc(maps\mp\zm_buried_sq_tpo::_are_all_players_in_time_bomb_volume, ::buried_are_all_players_in_time_bomb_volume);
    replacefunc(maps\mp\zm_buried_sq_ip::sq_bp_set_current_bulb, ::buried_sq_bp_set_current_bulb);
    replacefunc(maps\mp\zm_buried_sq_ows::ows_target_delete_timer, ::buried_ows_target_delete_timer);
    replacefunc(maps\mp\zm_buried_sq_ows::ows_targets_start, ::buried_ows_targets_start);
}

// OVERRIDE: maps\mp\zm_buried_sq_tpo::_are_all_players_in_time_bomb_volume
buried_are_all_players_in_time_bomb_volume( e_volume )
{
    //MODIFIED: every player in the game, not 4.
    a_players = get_players();
    n_required_players = a_players.size;
    //MODIFIED END
    n_players_in_position = 0;

    foreach ( player in a_players )
    {
        if ( player istouching( e_volume ) )
            n_players_in_position++;
    }

    b_all_in_valid_position = n_players_in_position == n_required_players;
    return b_all_in_valid_position;
}

// OVERRIDE: maps\mp\zm_buried_sq_ctw::ctw_max_wisp_enery_watch
buried_ctw_max_wisp_enery_watch()
{
    self endon( "death" );

    while ( true )
    {
        //MODIFIED: under three players the wisp keeps full energy.
        if ( level.starting_player_count < 3 )
            self.n_sq_energy = self.n_sq_max_energy;
        //MODIFIED END

        if ( self.n_sq_energy <= 0 )
            flag_set( "sq_wisp_failed" );

        wait 1;
    }
}

// OVERRIDE: maps\mp\zm_buried_sq_ip::sq_bp_set_current_bulb
buried_sq_bp_set_current_bulb( str_tag )
{
    level endon( "sq_bp_correct_button" );
    level endon( "sq_bp_wrong_button" );
    level endon( "sq_bp_timeout" );

    if ( isdefined( level.m_sq_bp_active_light ) )
        level.str_sq_bp_active_light = "";

    level.m_sq_bp_active_light = maps\mp\zm_buried_sq_ip::sq_bp_light_on( str_tag, "yellow" );
    level.str_sq_bp_active_light = str_tag;

    //MODIFIED: no time limit for one or two players.
    if ( level.starting_player_count > 2 )
    {
        wait 10;
        level notify( "sq_bp_timeout" );
    }
    //MODIFIED END
}

// OVERRIDE: maps\mp\zm_buried_sq_ows::ows_target_delete_timer
buried_ows_target_delete_timer()
{
    self endon( "death" );
    wait 4;
    self notify( "ows_target_timeout" );

    //MODIFIED: the step fails once the allowed misses are used up.
    level.buried_ows_misses_left--;

    if ( level.buried_ows_misses_left < 0 )
        flag_set( "sq_ows_target_missed" );
    //MODIFIED END
}

// OVERRIDE: maps\mp\zm_buried_sq_ows::ows_targets_start
buried_ows_targets_start()
{
    n_cur_second = 0;
    flag_clear( "sq_ows_target_missed" );
    //MODIFIED: misses allowed for this run of the targets.
    level.buried_ows_misses_left = buried_ows_allowed_misses();
    //MODIFIED END
    level thread maps\mp\zm_buried_sq_ows::sndsidequestowsmusic();
    a_sign_spots = getstructarray( "otw_target_spot", "script_noteworthy" );

    while ( n_cur_second < 40 )
    {
        a_spawn_spots = maps\mp\zm_buried_sq_ows::ows_targets_get_cur_spots( n_cur_second );

        if ( isdefined( a_spawn_spots ) && a_spawn_spots.size > 0 )
            maps\mp\zm_buried_sq_ows::ows_targets_spawn( a_spawn_spots );

        wait 1;
        n_cur_second++;
    }

    if ( !flag( "sq_ows_target_missed" ) )
    {
        flag_set( "sq_ows_success" );
        playsoundatposition( "zmb_sq_target_success", ( 0, 0, 0 ) );
    }
    else
        playsoundatposition( "zmb_sq_target_fail", ( 0, 0, 0 ) );

    level notify( "sndEndOWSMusic" );
}

// Sharpshooter has 84 targets. Solo the 20 of the candy shop count, two
// players also the 19 of the saloon, more players every target.
buried_ows_allowed_misses()
{
    switch ( level.starting_player_count )
    {
        case 1: return 84 - 20;
        case 2: return 84 - 20 - 19;
    }
    return 0;
}

// OVERRIDE: maps\mp\zm_buried_sq::sq_metagame
// The Super EE endgame machine.
buried_sq_metagame()
{
    level endon( "sq_metagame_player_connected" );
    flag_wait( "sq_intro_vo_done" );

    if ( flag( "sq_started" ) )
        level waittill( "buried_sidequest_achieved" );

    level thread maps\mp\zm_buried_sq::sq_metagame_turn_off_watcher();
    is_blue_on = 0;
    is_orange_on = 0;
    m_endgame_machine = getstruct( "sq_endgame_machine", "targetname" );
    a_tags = [];
    a_tags[0][0] = "TAG_LIGHT_1";
    a_tags[0][1] = "TAG_LIGHT_2";
    a_tags[0][2] = "TAG_LIGHT_3";
    a_tags[1][0] = "TAG_LIGHT_4";
    a_tags[1][1] = "TAG_LIGHT_5";
    a_tags[1][2] = "TAG_LIGHT_6";
    a_tags[2][0] = "TAG_LIGHT_7";
    a_tags[2][1] = "TAG_LIGHT_8";
    a_tags[2][2] = "TAG_LIGHT_9";
    a_tags[3][0] = "TAG_LIGHT_10";
    a_tags[3][1] = "TAG_LIGHT_11";
    a_tags[3][2] = "TAG_LIGHT_12";
    a_stat = [];
    a_stat[0] = "sq_transit_last_completed";
    a_stat[1] = "sq_highrise_last_completed";
    a_stat[2] = "sq_buried_last_completed";
    a_stat_nav = [];
    a_stat_nav[0] = "navcard_applied_zm_transit";
    a_stat_nav[1] = "navcard_applied_zm_highrise";
    a_stat_nav[2] = "navcard_applied_zm_buried";
    a_stat_nav_held = [];
    a_stat_nav_held[0] = "navcard_applied_zm_transit";
    a_stat_nav_held[1] = "navcard_applied_zm_highrise";
    a_stat_nav_held[2] = "navcard_applied_zm_buried";
    bulb_on = [];
    bulb_on[0] = 0;
    bulb_on[1] = 0;
    bulb_on[2] = 0;
    level.n_metagame_machine_lights_on = 0;
    flag_wait( "start_zombie_round_logic" );
    maps\mp\zm_buried_sq::sq_metagame_clear_lights();
    players = get_players();
    player_count = players.size;

    for ( n_player = 0; n_player < player_count; n_player++ )
    {
        for ( n_stat = 0; n_stat < a_stat.size; n_stat++ )
        {
            if ( isdefined( players[n_player] ) )
            {
                n_stat_value = players[n_player] maps\mp\zombies\_zm_stats::get_global_stat( a_stat[n_stat] );
                n_stat_nav_value = players[n_player] maps\mp\zombies\_zm_stats::get_global_stat( a_stat_nav[n_stat] );
            }

            if ( n_stat_value == 1 )
            {
                m_endgame_machine maps\mp\zm_buried_sq::sq_metagame_machine_set_light( n_player, n_stat, "sq_bulb_blue" );
                is_blue_on = 1;
            }
            else if ( n_stat_value == 2 )
            {
                m_endgame_machine maps\mp\zm_buried_sq::sq_metagame_machine_set_light( n_player, n_stat, "sq_bulb_orange" );
                is_orange_on = 1;
            }

            if ( n_stat_nav_value )
            {
                level setclientfield( "buried_sq_egm_bulb_" + n_stat, 1 );
                bulb_on[n_stat] = 1;
            }
        }
    }

    //MODIFIED: three lights per player in the game, not 12.
    all_lights = player_count * 3;
    //MODIFIED END

    if ( level.n_metagame_machine_lights_on == all_lights )
    {
        if ( is_blue_on && is_orange_on )
            return;
        else if ( !bulb_on[0] || !bulb_on[1] || !bulb_on[2] )
            return;
    }
    else
        return;

    m_endgame_machine.activate_trig = spawn( "trigger_radius", m_endgame_machine.origin, 0, 128, 72 );
    m_endgame_machine.activate_trig waittill( "trigger" );
    m_endgame_machine.activate_trig delete();
    m_endgame_machine.activate_trig = undefined;
    level setclientfield( "buried_sq_egm_animate", 1 );
    m_endgame_machine.endgame_trig = spawn( "trigger_radius_use", m_endgame_machine.origin, 0, 16, 16 );
    m_endgame_machine.endgame_trig setcursorhint( "HINT_NOICON" );
    m_endgame_machine.endgame_trig sethintstring( &"ZM_BURIED_SQ_EGM_BUT" );
    m_endgame_machine.endgame_trig triggerignoreteam();
    m_endgame_machine.endgame_trig usetriggerrequirelookat();
    m_endgame_machine.endgame_trig waittill( "trigger" );
    m_endgame_machine.endgame_trig delete();
    m_endgame_machine.endgame_trig = undefined;
    level thread maps\mp\zm_buried_sq::sq_metagame_clear_tower_pieces();
    playsoundatposition( "zmb_endgame_mach_button", m_endgame_machine.origin );
    players = get_players();

    foreach ( player in players )
    {
        for ( i = 0; i < a_stat.size; i++ )
        {
            player maps\mp\zombies\_zm_stats::set_global_stat( a_stat[i], 0 );
            player maps\mp\zombies\_zm_stats::set_global_stat( a_stat_nav_held[i], 0 );
            player maps\mp\zombies\_zm_stats::set_global_stat( a_stat_nav[i], 0 );
        }
    }

    maps\mp\zm_buried_sq::sq_metagame_clear_lights();

    if ( is_orange_on )
        level notify( "end_game_reward_starts_maxis" );
    else
        level notify( "end_game_reward_starts_richtofen" );
}
