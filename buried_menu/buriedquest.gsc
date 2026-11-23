#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Buried quest settings
##############################################################################*/
// Rows every mode with the quest uses: the signs each side punches (yes or random,
// user 2026-11-10), Richtofen's wisp forks and Maxis's lantern teleports.

buried_quest_install()
{
    replacefunc(maps\mp\zm_buried_sq::sq_assign_signs, ::buried_sq_assign_signs);
    replacefunc(maps\mp\zm_buried_sq_ctw::ctw_ric_get_next_wisp_struct, ::buried_ctw_ric_get_next_wisp_struct);
    replacefunc(maps\mp\zm_buried_sq_gl::gl_lantern_move, ::buried_gl_lantern_move);
}

buried_quest_defaults(settings_ar)
{
    foreach(sign in buried_sign_names())
    {
        settings_ar["sign_max_" + sign] = 0;
        settings_ar["sign_ric_" + sign] = 0;
    }
    settings_ar["lantern_teleports"] = 1;
    settings_ar["wisp_fork_start"] = 0;
    settings_ar["wisp_fork_end"] = 0;
    return settings_ar;
}

// One side's sign rows, side "max" or "ric": yes (the side punches it) or random.
buried_sign_menu(menu, side)
{
    signs = buried_sign_names();
    labels = array("[L]unger", "[C]onsumption", "[B]one", "[G]round", "[D]ry"); // Runners remember the first letter.
    for(i = 0; i < signs.size; i++)
    {
        text = "^3random";
        if(get_cfg_int("sign_" + side + "_" + signs[i])) text = "^2yes";
        create_option(menu, labels[i] + ": " + text, ::buried_sign_toggle, side, signs[i]);
    }
}

buried_fork_menu(menu)
{
    add_cfg_choice(menu, "Fork 1", "wisp_fork_start", array("random", "west", "east"));
    add_cfg_choice(menu, "Fork 2", "wisp_fork_end", array("random", "long", "short"));
}

// Menu action. A side punches three signs, so a fourth yes is refused, and so is a
// yes the other side's rows leave no room for (the two sides share only one sign).
buried_sign_toggle(side, sign)
{
    key = "sign_" + side + "_" + sign;
    if(get_cfg_int(key))
    {
        self cfg_set_int(key, 0);
        return;
    }

    max_yes = buried_sign_yes("max");
    ric_yes = buried_sign_yes("ric");
    if(side == "max") max_yes[sign] = true;
    else ric_yes[sign] = true;

    if(getarraykeys(max_yes).size > 3 || getarraykeys(ric_yes).size > 3)
    {
        self iprintln("3 signs per side at most");
        return;
    }
    if(!buried_sign_both_candidates(max_yes, ric_yes).size)
    {
        self iprintln("The other side's signs leave no room for this one");
        return;
    }
    self cfg_set_int(key, 1);
}

// The signs a side's rows set to yes, as keys.
buried_sign_yes(side)
{
    yes = [];
    foreach(sign in buried_sign_names())
        if(get_cfg_int("sign_" + side + "_" + sign)) yes[sign] = true;
    return yes;
}

// The signs that can be the shared one: every other yes fits in the side's own two,
// and no sign but this one is a yes on both sides.
buried_sign_both_candidates(max_yes, ric_yes)
{
    candidates = [];
    foreach(both in buried_sign_names())
    {
        n_max = 0;
        n_ric = 0;
        clash = false;
        foreach(sign in buried_sign_names())
        {
            if(sign == both) continue;
            if(isdefined(max_yes[sign])) n_max++;
            if(isdefined(ric_yes[sign])) n_ric++;
            if(isdefined(max_yes[sign]) && isdefined(ric_yes[sign])) clash = true;
        }
        if(!clash && n_max <= 2 && n_ric <= 2) candidates[candidates.size] = both;
    }
    return candidates;
}

// Sign name to role (SIGN_*), from the rows, at map load.
buried_sign_roles()
{
    max_yes = buried_sign_yes("max");
    ric_yes = buried_sign_yes("ric");
    candidates = buried_sign_both_candidates(max_yes, ric_yes);
    if(!candidates.size)
    {
        println("B-Prac: sign rows clash, all signs random");
        max_yes = [];
        ric_yes = [];
        candidates = buried_sign_names();
    }

    // A sign both sides set is the shared one, else any that fits.
    both = array_randomize(candidates)[0];
    foreach(sign in candidates)
        if(isdefined(max_yes[sign]) && isdefined(ric_yes[sign])) both = sign;

    roles = [];
    roles[both] = SIGN_BOTH;
    n_max = 0;
    foreach(sign in buried_sign_names())
    {
        if(sign == both) continue;
        if(isdefined(max_yes[sign]))
        {
            roles[sign] = SIGN_MAXIS;
            n_max++;
        }
        else if(isdefined(ric_yes[sign]))
            roles[sign] = SIGN_RICHTOFEN;
    }

    rest = [];
    foreach(sign in buried_sign_names())
        if(!isdefined(roles[sign])) rest[rest.size] = sign;
    rest = array_randomize(rest);
    foreach(sign in rest)
    {
        if(n_max < 2)
        {
            roles[sign] = SIGN_MAXIS;
            n_max++;
        }
        else
            roles[sign] = SIGN_RICHTOFEN;
    }
    return roles;
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

// The sign's name, from its model.
buried_sign_name(m_sign)
{
    prefix = "p6_zm_bu_sign_tunnel_";
    return getsubstr(m_sign.model, prefix.size, m_sign.model.size);
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

    //MODIFIED: roles from the sign rows instead of array_randomize.
    a_signs = getentarray( "sq_tunnel_sign", "targetname" );
    roles = buried_sign_roles();

    foreach ( m_sign in a_signs )
        buried_sign_set_role( m_sign, roles[buried_sign_name( m_sign )] );
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

/*##############################################################################
                              Maze switches
##############################################################################*/
// Richtofen's maze lever step (zm_buried_sq_ip). Lever n sits on the wall of
// the n-th blocker of the maze's active layout (a lever with no wall in the
// layout stays at its own struct). Each maze change re-places the levers and
// rolls their side, a wrong attempt resets them, the solution order is rolled
// once when the step starts. Settings go by colour, the lever's model (struct
// order is blue, green, red, yellow, logged live 2026-11-05).

// In menu order.
buried_switch_colors()
{
    return array("red", "green", "blue", "yellow");
}

// The colour of a lever model ("p6_zm_bu_maze_switch_red").
buried_switch_color(model)
{
    foreach(color in buried_switch_colors())
        if(issubstr(model, color)) return color;
    return "red";
}

// Vanilla init_maze_permutations layouts, in its order (layout 1 is the first).
buried_maze_layouts()
{
    return array( array( "blocker_1", "blocker_2", "blocker_3", "blocker_4" ), array( "blocker_5", "blocker_6", "blocker_7", "blocker_8", "blocker_9" ), array( "blocker_1", "blocker_10", "blocker_6", "blocker_4", "blocker_11" ), array( "blocker_1", "blocker_3", "blocker_4", "blocker_12" ), array( "blocker_5", "blocker_6", "blocker_12", "blocker_13" ), array( "blocker_4", "blocker_6", "blocker_14" ) );
}

// Maze layout: a one-layout list makes vanilla maze_do_perm_change always pick
// it (it reshuffles the list at its end), so every maze change keeps that
// layout, from the first change on.
buried_lock_maze()
{
    choice = get_cfg_int("maze_layout");
    layouts = buried_maze_layouts();
    if(choice <= 0 || choice > layouts.size || !isdefined(level._maze)) return;

    level._maze._perms = array(layouts[choice - 1]);
    level._maze._cur_perm = 0;
}

// is_flip for the lever of that colour on a wall whose right vector is v_right. Side
// N / W puts the lever on the north face of an east-west wall or the west face
// of a north-south wall (north = +y, east = +x, to confirm in game).
buried_lever_flip(color, v_right)
{
    side = get_cfg_int("switch_side_" + color);
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
buried_sq_ml_spawn_lever( n_index )
{
    m_lever = spawn( "script_model", ( 0, 0, 0 ) );
    m_lever setmodel( self.model );
    m_lever.targetname = "sq_ml_lever";
    //MODIFIED: the lever keeps its colour for the Switches settings.
    m_lever.buried_color = buried_switch_color( self.model );
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
            is_flip = buried_lever_flip( m_lever.buried_color, v_right );
            //MODIFIED END
            v_offset = vectornormalize( v_right ) * 2;

            if ( is_flip )
                v_offset = v_offset * -1;

            v_spot = s_spot.origin + vectorscale( ( 0, 0, 1 ), 48.0 ) + v_offset;
            v_angles = s_spot.angles + vectorscale( ( 0, 1, 0 ), 90.0 );

            if ( is_flip )
                v_angles = s_spot.angles - vectorscale( ( 0, 1, 0 ), 90.0 );

            println( "B-Prac: " + m_lever.buried_color + " switch on " + level._maze._active_perm_list[n_index] + " at " + v_spot + " flip " + is_flip );
        }

        m_lever.origin = v_spot;
        m_lever.angles = v_angles;
        level waittill( "zm_buried_maze_changed" );
    }
}

// Solution order: a lever whose Order setting is k is the k-th to flip. Set values
// are kept unless two switches claim the same place (the later one goes random), the
// rest take the free places at random.
buried_set_lever_order(a_levers)
{
    n = a_levers.size;
    taken = [];
    order = [];
    for(i = 0; i < n; i++)
    {
        c = get_cfg_int("switch_order_" + a_levers[i].buried_color) - 1;
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
        println("B-Prac: " + a_levers[i].buried_color + " switch is flipped " + (order[i] + 1));
    }
}

// OVERRIDE: maps\mp\zm_buried_sq_ip::sq_ml_puzzle_logic
buried_sq_ml_puzzle_logic()
{
    a_levers = getentarray( "sq_ml_lever", "targetname" );
    level.sq_ml_curr_lever = 0;
    //MODIFIED: Order settings instead of array_randomize.
    buried_set_lever_order( a_levers );
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

// Shared by the modes with the maze step (Fullgame, Maze Prac): their initialize calls
// this, their defaults and Settings menu take the rows below.
buried_maze_install()
{
    replacefunc(maps\mp\zm_buried_sq_ip::sq_ml_spawn_lever, ::buried_sq_ml_spawn_lever);
    replacefunc(maps\mp\zm_buried_sq_ip::sq_ml_puzzle_logic, ::buried_sq_ml_puzzle_logic);
}

buried_maze_defaults(settings_ar)
{
    settings_ar["maze_layout"] = 0;
    foreach(color in buried_switch_colors())
    {
        settings_ar["switch_side_" + color] = SIDE_RANDOM;
        settings_ar["switch_order_" + color] = 0;
    }
    return settings_ar;
}

buried_maze_menu(menu)
{
    add_cfg_choice(menu, "Layout", "maze_layout", array("random", "1", "2", "3", "4", "5", "6"));
    colors = buried_switch_colors();
    labels = array("Red", "Green", "Blue", "Yellow");
    for(i = 0; i < colors.size; i++)
        add_cfg_choice(menu, labels[i] + " Side", "switch_side_" + colors[i], array("random", "N / W", "S / E"));
    for(i = 0; i < colors.size; i++)
        add_cfg_choice(menu, labels[i] + " Order", "switch_order_" + colors[i], array("random", "1st", "2nd", "3rd", "4th"));
}

// The chosen layout up at once instead of from the next maze change (Maze Prac, set
// while the player is frozen): one vanilla change onto the locked one-layout list.
buried_maze_apply_now()
{
    if(!get_cfg_int("maze_layout") || !isdefined(level._maze)) return;
    maps\mp\zm_buried_maze::maze_do_perm_change();
    level notify("zm_buried_maze_changed");
}
