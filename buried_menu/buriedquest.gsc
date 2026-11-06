#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Buried quest settings
##############################################################################*/
// Rows every mode with the quest uses: who punches each sign, Richtofen's wisp forks
// and Maxis's lantern teleports.

buried_quest_install()
{
    replacefunc(maps\mp\zm_buried_sq::sq_assign_signs, ::buried_sq_assign_signs);
    replacefunc(maps\mp\zm_buried_sq_ctw::ctw_ric_get_next_wisp_struct, ::buried_ctw_ric_get_next_wisp_struct);
    replacefunc(maps\mp\zm_buried_sq_gl::gl_lantern_move, ::buried_gl_lantern_move);
}

buried_quest_defaults(settings_ar)
{
    foreach(sign in buried_sign_names())
        settings_ar["sign_" + sign] = SIGN_RANDOM;
    settings_ar["lantern_teleports"] = 1;
    settings_ar["wisp_fork_start"] = 0;
    settings_ar["wisp_fork_end"] = 0;
    return settings_ar;
}

buried_sign_menu(menu)
{
    signs = buried_sign_names();
    labels = array("Lunger", "Consumption", "Bone", "Ground", "Dry");
    for(i = 0; i < signs.size; i++)
        add_cfg_choice(menu, labels[i], "sign_" + signs[i], array("random", "both", "Maxis", "Richtofen"));
}

buried_fork_menu(menu)
{
    add_cfg_choice(menu, "Richtofen Fork 1", "wisp_fork_start", array("random", "west", "east"));
    add_cfg_choice(menu, "Richtofen Fork 2", "wisp_fork_end", array("random", "long", "short"));
}

/*##############################################################################
                              Tunnel signs and the wisp
##############################################################################*/
// The side's three signs are punched to start the wisp, and the last one punched
// starts it (vanilla ts_sign_check_all_activated). Maxis's wisp then flies the one
// vehicle path of that sign, so the path is picked by the last punch. Richtofen's
// jumps between structs and rolls two forks on the way: Bone and Ground reach the
// first, every sign the last.

// Tunnel sign models end in these (p6_zm_bu_sign_tunnel_<name>).
buried_sign_names()
{
    return array("lunger", "consumption", "bone", "ground", "dry");
}

// The sign's setting, read at map load.
buried_sign_setting(m_sign)
{
    prefix = "p6_zm_bu_sign_tunnel_";
    return get_cfg_int("sign_" + getsubstr(m_sign.model, prefix.size, m_sign.model.size));
}

buried_sign_set_role(m_sign, role)
{
    if(role != SIGN_RICHTOFEN) m_sign.is_max_sign = 1;
    if(role != SIGN_MAXIS) m_sign.is_ric_sign = 1;
}

// OVERRIDE: maps\mp\zm_buried_sq::sq_assign_signs
buried_sq_assign_signs()
{
    a_signs = getstructarray( "sq_tunnel_sign", "targetname" );

    foreach ( s_sign in a_signs )
    {
        m_sign = spawn( "script_model", s_sign.origin );
        m_sign.angles = s_sign.angles;
        m_sign.target = s_sign.target;
        m_sign.targetname = "sq_tunnel_sign";
        m_sign setmodel( s_sign.model );
    }

    //MODIFIED: the sign rows first. A row past what the role allows counts as random.
    a_signs = getentarray( "sq_tunnel_sign", "targetname" );
    left = [];
    left[SIGN_BOTH] = 1;
    left[SIGN_MAXIS] = 2;
    left[SIGN_RICHTOFEN] = 2;
    a_random = [];

    foreach ( m_sign in a_signs )
    {
        role = buried_sign_setting( m_sign );

        if ( role != SIGN_RANDOM && left[role] > 0 )
        {
            left[role]--;
            buried_sign_set_role( m_sign, role );
        }
        else
            a_random[a_random.size] = m_sign;
    }

    a_roles = [];

    foreach ( role in getarraykeys( left ) )
    {
        for ( i = 0; i < left[role]; i++ )
            a_roles[a_roles.size] = role;
    }

    a_roles = array_randomize( a_roles );

    for ( i = 0; i < a_random.size; i++ )
        buried_sign_set_role( a_random[i], a_roles[i] );
    //MODIFIED END
}

// OVERRIDE: maps\mp\zm_buried_sq_ctw::ctw_ric_get_next_wisp_struct
buried_ctw_ric_get_next_wisp_struct( s_current )
{
    if ( !isdefined( s_current.target ) )
        return undefined;

    a_structs = getstructarray( s_current.target, "targetname" );

    //MODIFIED: a fork's setting picks the struct, 1 the one further west. On the
    // last fork that is the long way, with one more stop.
    forced = 0;

    if ( s_current.target == WISP_FORK_START )
        forced = get_cfg_int( "wisp_fork_start" );
    else if ( s_current.target == WISP_FORK_END )
        forced = get_cfg_int( "wisp_fork_end" );

    if ( forced && a_structs.size == 2 )
    {
        west = 0;

        if ( a_structs[1].origin[0] < a_structs[0].origin[0] )
            west = 1;

        if ( forced == 1 )
            return a_structs[west];

        return a_structs[1 - west];
    }
    //MODIFIED END

    return array_randomize( a_structs )[0];
}

// OVERRIDE: maps\mp\zm_buried_sq_gl::gl_lantern_move
buried_gl_lantern_move( s_current )
{
    level endon( "lantern_crashing" );

    while ( true )
    {
        s_current = maps\mp\zm_buried_sq_gl::gl_lantern_get_next_struct( s_current );

        //MODIFIED: the setting can stop Maxis's 50% teleports. The route stays random.
        if ( flag( "sq_is_max_tower_built" ) && get_cfg_int( "lantern_teleports" ) )
        //MODIFIED END
        {
            if ( randomint( 100 ) < 50 )
                s_current = level.vh_lantern maps\mp\zm_buried_sq_gl::gl_lantern_teleport();
        }

        level.vh_lantern maps\mp\zm_buried_sq_gl::gl_lantern_move_to_struct( s_current );
    }
}
