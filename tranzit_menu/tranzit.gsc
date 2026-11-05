#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\victis;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              TranZit map hooks
##############################################################################*/
// Everything TranZit adds to the core menus and HUD (see practice_map in
// utility_core\basegame.gsc): the Victis Settings (utility_core\victis.gsc) with
// TranZit's madeup scripts. Settings are saved in T_PRAC/. Modes: Fullgame
// (tranzitfullgame.gsc), Ending EMP (endingemp.gsc), Freeroam.
tranzit_practice_map()
{
    map = practice_map("Huth's T-Prac", "Huth's TranZit Practice Tool", "T_PRAC/", "t_menu_gamemode");
    map.cursor_color = (0.62, 0.82, 0.52);
    map.header_text_color = (0, 0, 0);
    map.accent_color = (0.47, 0.6, 0.39); // Washed-out plastic battle green (user, 2026-11-04)
    // RPG PaP: the B2EE timer's TranZit fridge.
    victis_practice_map(map, "usrpg_upgraded_zm", ::tranzit_madeup_install);
    return map;
}

// The menu runs on classic TranZit only: zm_transit also hosts Bus Depot, Town,
// Farm and Grief (vanilla zm_transit tells them apart the same way).
tranzit_map_active()
{
    return is_classic() && getdvar("ui_zm_mapstartlocation") == "transit";
}

/*##############################################################################
                              Madeup scripts
##############################################################################*/
// The B2EE timer's madeup set for TranZit (it emulates Hadi77KSA's
// Plutonium-T6-Any-Player-EE-Scripts): solo, Maxis B needs one powered turbine
// and a side counts as fully progressed when its first step is done. Installed
// by victis_initialize while the Madeup setting is on.
tranzit_madeup_install()
{
    replacefunc(maps\mp\zm_transit_sq::maxis_sidequest_b, ::tranzit_maxis_sidequest_b);
    replacefunc(maps\mp\zm_transit_sq::get_how_many_progressed_from, ::tranzit_get_how_many_progressed_from);
}

// OVERRIDE: maps\mp\zm_transit_sq::maxis_sidequest_b
tranzit_maxis_sidequest_b()
{
    level endon( "power_on" );

    while ( true )
    {
        level waittill( "stun_avogadro", avogadro );

        //MODIFIED: solo needs only the first turbine (second_turbine in the check below).
        second_turbine = get_players().size == 1 || isdefined( level.sq_progress["maxis"]["A_turbine_2"] ) && is_true( level.sq_progress["maxis"]["A_turbine_2"].powered );
        //MODIFIED END

        if ( isdefined( level.sq_progress["maxis"]["A_turbine_1"] ) && is_true( level.sq_progress["maxis"]["A_turbine_1"].powered ) && second_turbine )
        {
            if ( isdefined( avogadro ) && avogadro istouching( level.sq_volume ) )
            {
                level notify( "end_avogadro_turbines" );
                break;
            }
        }
    }

    level notify( "maxis_stage_b" );
    level thread maps\mp\zm_transit_sq::maxissay( "vox_maxi_avogadro_emp_0", ( 7737, -416, -142 ) );
    maps\mp\zm_transit_sq::update_sidequest_stats( "sq_transit_maxis_stage_3" );
    player = get_players();
    player[0] setclientfield( "sq_tower_sparks", 1 );
    player[0] setclientfield( "screecher_maxis_lights", 1 );
    level thread maps\mp\zm_transit_sq::maxis_sidequest_complete_check( "B_complete" );
}

// OVERRIDE: maps\mp\zm_transit_sq::get_how_many_progressed_from
tranzit_get_how_many_progressed_from( story, a, b )
{
    //MODIFIED: solo, a alone counts as both.
    solo = get_players().size == 1;

    if ( !solo && ( isdefined( level.sq_progress[story][a] ) && !isdefined( level.sq_progress[story][b] ) || !isdefined( level.sq_progress[story][a] ) && isdefined( level.sq_progress[story][b] ) ) )
        return 1;
    else if ( isdefined( level.sq_progress[story][a] ) && ( solo || isdefined( level.sq_progress[story][b] ) ) )
        return 2;
    //MODIFIED END

    return 0;
}
