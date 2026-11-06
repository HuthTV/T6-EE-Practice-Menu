#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\victis;
#inline scripts\zm\dierise_menu\dierise;

/*##############################################################################
                              Die Rise map hooks
##############################################################################*/
// Everything Die Rise adds to the core menus and HUD (see practice_map in
// utility_core\basegame.gsc): the Victis Settings (utility_core\victis.gsc) with
// Die Rise's madeup scripts. Add hooks (build_hud, build_cheats, say_command,
// open_doors, run...) as the map gets features. Settings are saved in D_PRAC/.
dierise_practice_map()
{
    map = practice_map("Huth's D-Prac", "Huth's Die Rise Practice Tool", "D_PRAC/", "d_menu_gamemode");
    map.accent_color = (0.62, 0.18, 0.24); // Dark velvet red (user, 2026-11-04)
    // The B2EE timer's Die Rise splits, on or off as a whole.
    map.split_names = array("symbols", "high_maintenance");
    map.split_labels = array("Symbols", "High Maintenance");
    map.fixed_splits = true;
    map.cursor_color = (1, 0.47, 0.52);
    map.menu_icon = "faction_highrise";
    map.no_slots = true; // No Presets menu (user, 2026-11-05).
    // SVU: the B2EE timer's Die Rise fridge.
    victis_practice_map(map, "svu_zm", ::dierise_madeup_install);
    return map;
}

// The menu runs on classic Die Rise only (zm_highrise also hosts other game modes).
dierise_map_active()
{
    return is_classic();
}

/*##############################################################################
                              Madeup scripts
##############################################################################*/
// The B2EE timer's madeup set for Die Rise (it emulates Hadi77KSA's
// Plutonium-T6-Any-Player-EE-Scripts): the elevator and floor symbol steps want
// one symbol per player, Richtofen's springpads one per player, and Maxis's
// ball step works with fewer than four springpads. Counts come from
// level.starting_player_count (victis_madeup_players). Installed by
// victis_initialize while the Madeup setting is on.
dierise_madeup_install()
{
    replacefunc(maps\mp\zm_highrise_sq_atd::sq_atd_elevators, ::dierise_sq_atd_elevators);
    replacefunc(maps\mp\zm_highrise_sq_atd::sq_atd_drg_puzzle, ::dierise_sq_atd_drg_puzzle);
    replacefunc(maps\mp\zm_highrise_sq_pts::wait_for_all_springpads_placed, ::dierise_wait_for_all_springpads_placed);
    replacefunc(maps\mp\zm_highrise_sq_pts::pts_should_player_create_trigs, ::dierise_pts_should_player_create_trigs);
    replacefunc(maps\mp\zm_highrise_sq_pts::pts_should_springpad_create_trigs, ::dierise_pts_should_springpad_create_trigs);
    replacefunc(maps\mp\zm_highrise_sq_pts::pts_putdown_trigs_create_for_spot, ::dierise_pts_putdown_trigs_create_for_spot);
    replacefunc(maps\mp\zm_highrise_sq_pts::place_ball_think, ::dierise_place_ball_think);
}

// OVERRIDE: maps\mp\zm_highrise_sq_atd::sq_atd_elevators
dierise_sq_atd_elevators()
{
    a_elevators = array( "elevator_bldg1b_trigger", "elevator_bldg1d_trigger", "elevator_bldg3b_trigger", "elevator_bldg3c_trigger" );
    a_elevator_flags = array( "sq_atd_elevator0", "sq_atd_elevator1", "sq_atd_elevator2", "sq_atd_elevator3" );

    for ( i = 0; i < a_elevators.size; i++ )
    {
        trig_elevator = getent( a_elevators[i], "targetname" );
        trig_elevator thread maps\mp\zm_highrise_sq_atd::sq_atd_watch_elevator( a_elevator_flags[i] );
    }

    //MODIFIED: one elevator per player, not all four.
    while ( int( flag( "sq_atd_elevator0" ) ) + int( flag( "sq_atd_elevator1" ) ) + int( flag( "sq_atd_elevator2" ) ) + int( flag( "sq_atd_elevator3" ) ) < level.starting_player_count )
    {
        flag_wait_any_array( a_elevator_flags );
        wait 0.5;
    }
    //MODIFIED END

    a_dragon_icons = getentarray( "elevator_dragon_icon", "targetname" );

    foreach ( m_icon in a_dragon_icons )
    {
        v_off_pos = m_icon.m_lit_icon.origin;
        m_icon.m_lit_icon unlink();
        m_icon unlink();
        m_icon.m_lit_icon.origin = m_icon.origin;
        m_icon.origin = v_off_pos;
        m_icon.m_lit_icon linkto( m_icon.m_elevator );
        m_icon linkto( m_icon.m_elevator );
        m_icon playsound( "zmb_sq_symbol_light" );
    }

    flag_set( "sq_atd_elevator_activated" );
    maps\mp\zm_highrise_sq_atd::vo_richtofen_atd_elevators();
    level thread maps\mp\zm_highrise_sq_atd::vo_maxis_atd_elevators();
}

// OVERRIDE: maps\mp\zm_highrise_sq_atd::sq_atd_drg_puzzle
dierise_sq_atd_drg_puzzle()
{
    level.sq_atd_cur_drg = 0;
    a_puzzle_trigs = getentarray( "trig_atd_drg_puzzle", "targetname" );
    a_puzzle_trigs = array_randomize( a_puzzle_trigs );

    for ( i = 0; i < a_puzzle_trigs.size; i++ )
        a_puzzle_trigs[i] thread maps\mp\zm_highrise_sq_atd::drg_puzzle_trig_think( i );

    //MODIFIED: one floor symbol per player, not four.
    while ( level.sq_atd_cur_drg < level.starting_player_count )
        wait 1;
    //MODIFIED END

    flag_set( "sq_atd_drg_puzzle_complete" );

    //MODIFIED: the symbols nobody stood on are turned off and shown lit.
    foreach ( t_trig in a_puzzle_trigs )
    {
        if ( t_trig.drg_active == 0 )
        {
            t_trig disable_trigger();
            symbol = getent( t_trig.target, "targetname" );
            lit_icon = symbol.lit_icon;
            original_pos = symbol.origin;
            symbol.origin = lit_icon.origin;
            lit_icon.origin = original_pos;
        }
    }
    //MODIFIED END

    level thread maps\mp\zm_highrise_sq_atd::vo_maxis_atd_order_complete();
}

// OVERRIDE: maps\mp\zm_highrise_sq_pts::wait_for_all_springpads_placed
dierise_wait_for_all_springpads_placed( str_type, str_flag )
{
    a_spots = getstructarray( str_type, "targetname" );

    while ( !flag( str_flag ) )
    {
        //MODIFIED: one springpad per player, the other spots may stay empty.
        n_empty = 0;

        foreach ( s_spot in a_spots )
        {
            if ( !isdefined( s_spot.springpad ) )
                n_empty++;
        }

        if ( n_empty <= 4 - level.starting_player_count )
            flag_set( str_flag );
        //MODIFIED END

        wait 1;
    }
}

// OVERRIDE: maps\mp\zm_highrise_sq_pts::pts_should_player_create_trigs
dierise_pts_should_player_create_trigs( player )
{
    a_lion_spots = getstructarray( "pts_lion", "targetname" );

    foreach ( s_lion_spot in a_lion_spots )
    {
        //MODIFIED: solo a ball goes on any springpad, three players once the first ball flies.
        if ( isdefined( s_lion_spot.springpad ) && ( isdefined( s_lion_spot.springpad_buddy.springpad ) || dierise_lone_springpad_allowed() ) )
            dierise_pts_putdown_trigs_create_for_spot( s_lion_spot, player );
        //MODIFIED END
    }
}

// OVERRIDE: maps\mp\zm_highrise_sq_pts::pts_should_springpad_create_trigs
dierise_pts_should_springpad_create_trigs( s_lion_spot )
{
    //MODIFIED: as dierise_pts_should_player_create_trigs (has_partner in the check below).
    has_partner = isdefined( s_lion_spot.springpad_buddy ) && ( isdefined( s_lion_spot.springpad_buddy.springpad ) || dierise_lone_springpad_allowed() );
    //MODIFIED END

    if ( isdefined( s_lion_spot.springpad ) && has_partner )
    {
        a_players = getplayers();

        foreach ( player in a_players )
        {
            if ( isdefined( player.zm_sq_has_ball ) && player.zm_sq_has_ball )
            {
                dierise_pts_putdown_trigs_create_for_spot( s_lion_spot, player );

                //MODIFIED: only a spot that has a springpad.
                if ( isdefined( s_lion_spot.springpad_buddy.springpad ) )
                    dierise_pts_putdown_trigs_create_for_spot( s_lion_spot.springpad_buddy, player );
                //MODIFIED END
            }
        }
    }
}

// A ball may go on a springpad whose partner spot has none: solo, or three
// players once the first ball flies.
dierise_lone_springpad_allowed()
{
    return level.starting_player_count == 1 || level.starting_player_count == 3 && flag( "pts_2_generator_1_started" );
}

// OVERRIDE: maps\mp\zm_highrise_sq_pts::pts_putdown_trigs_create_for_spot
dierise_pts_putdown_trigs_create_for_spot( s_lion_spot, player )
{
    //MODIFIED: under four players a second ball may go on a springpad pair already flinging one.
    if ( level.starting_player_count >= 4 && ( isdefined( s_lion_spot.which_ball ) || isdefined( s_lion_spot.springpad_buddy ) && isdefined( s_lion_spot.springpad_buddy.which_ball ) ) )
        return;
    //MODIFIED END

    t_place_ball = maps\mp\zm_highrise_sq_pts::sq_pts_create_use_trigger( s_lion_spot.origin, 16, 70, &"ZM_HIGHRISE_SQ_PUTDOWN_BALL" );
    player clientclaimtrigger( t_place_ball );
    t_place_ball.owner = player;
    player thread dierise_place_ball_think( t_place_ball, s_lion_spot );

    if ( !isdefined( s_lion_spot.pts_putdown_trigs ) )
        s_lion_spot.pts_putdown_trigs = [];

    s_lion_spot.pts_putdown_trigs[player.characterindex] = t_place_ball;
    level thread maps\mp\zm_highrise_sq_pts::pts_putdown_trigs_springpad_delete_watcher( player, s_lion_spot );
}

// OVERRIDE: maps\mp\zm_highrise_sq_pts::place_ball_think
dierise_place_ball_think( t_place_ball, s_lion_spot )
{
    t_place_ball endon( "delete" );
    t_place_ball waittill( "trigger" );

    //MODIFIED: under four players the pair keeps its put-down triggers.
    if ( level.starting_player_count > 3 )
    {
        maps\mp\zm_highrise_sq_pts::pts_putdown_trigs_remove_for_spot( s_lion_spot );
        maps\mp\zm_highrise_sq_pts::pts_putdown_trigs_remove_for_spot( s_lion_spot.springpad_buddy );
    }
    //MODIFIED END

    self.zm_sq_has_ball = undefined;
    s_lion_spot.which_ball = self.which_ball;
    self notify( "zm_sq_ball_used" );
    s_lion_spot.zm_pts_animating = 1;
    s_lion_spot.springpad_buddy.zm_pts_animating = 1;
    flag_set( "pts_2_generator_" + level.current_generator + "_started" );
    s_lion_spot.which_generator = level.current_generator;
    level.current_generator++;

    //MODIFIED: a springpad with no partner flings to itself.
    if ( !isdefined( s_lion_spot.springpad_buddy.springpad ) )
        s_lion_spot.springpad_buddy.springpad = s_lion_spot.springpad;
    //MODIFIED END

    s_lion_spot.springpad thread maps\mp\zm_highrise_sq_pts::pts_springpad_fling( s_lion_spot.script_noteworthy, s_lion_spot.springpad_buddy.springpad );
    self.t_putdown_ball delete();

    //MODIFIED: three players: once the first ball flies, a player still holding
    // a ball gets put-down triggers on the springpads of the other trajectory.
    if ( level.starting_player_count == 3 )
    {
        for ( i = 0; i < level.players.size; i++ )
        {
            if ( isdefined( level.players[i].zm_sq_has_ball ) && level.players[i].zm_sq_has_ball )
            {
                foreach ( s_spot in getstructarray( "pts_lion", "targetname" ) )
                {
                    if ( isdefined( s_spot.springpad ) && s_spot != s_lion_spot && s_spot.springpad_buddy != s_lion_spot )
                        dierise_pts_putdown_trigs_create_for_spot( s_spot, level.players[i] );
                }
            }
        }
    }
    //MODIFIED END
}
