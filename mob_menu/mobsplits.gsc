#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\splits;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Mob split timer
##############################################################################*/
// The T6 EE Timer's solo Mob splits (T6-EE-Timer\timer.gsc: split list and
// wait conditions), drawn by the core split timer. Splits run from first to
// Headphones; each case falls through to the next. No top segment timer
// (user, 2026-10-14: it does not make sense for Mob).
mob_split_timer(first, clock_start)
{
    level endon("end_game");
    labels = array("^3Dryer ^7", "^3Gondola I ^7", "^3Plane I ^7", "^3Gondola II ^7", "^3Plane II ^7", "^3Gondola III ^7", "^3Plane III ^7", "^3Codes ^7", "^3Headphones ^7");
    practice_splits_start(labels, first, clock_start);

    switch(first)
    {
        case MOB_SPLIT_DRYER:
            flag_wait("dryer_cycle_active");
            practice_split(MOB_SPLIT_DRYER);
        case MOB_SPLIT_GONDOLA_1:
            mob_split_wait_gondola();
            practice_split(MOB_SPLIT_GONDOLA_1);
        case MOB_SPLIT_PLANE_1:
            mob_split_wait_plane();
            practice_split(MOB_SPLIT_PLANE_1);
        case MOB_SPLIT_GONDOLA_2:
            mob_split_wait_gondola();
            practice_split(MOB_SPLIT_GONDOLA_2);
        case MOB_SPLIT_PLANE_2:
            mob_split_wait_plane();
            practice_split(MOB_SPLIT_PLANE_2);
        case MOB_SPLIT_GONDOLA_3:
            mob_split_wait_gondola();
            practice_split(MOB_SPLIT_GONDOLA_3);
        case MOB_SPLIT_PLANE_3:
            mob_split_wait_plane();
            practice_split(MOB_SPLIT_PLANE_3);
        case MOB_SPLIT_CODES:
            level waittill_multiple("nixie_final_" + 386, "nixie_final_" + 481, "nixie_final_" + 101, "nixie_final_" + 872);
            practice_split(MOB_SPLIT_CODES);
        case MOB_SPLIT_HEADPHONES:
            wait 10;
            while(isdefined(level.m_headphones)) wait 0.05;
            practice_split(MOB_SPLIT_HEADPHONES);
    }
}

// EE timer "gondola_1/2/3": the gondola starts moving.
mob_split_wait_gondola()
{
    flag_wait("gondola_initialized");
    flag_wait("gondola_in_motion");
}

// EE timer "plane_1/2/3": a player boards the plane.
mob_split_wait_plane()
{
    flag_waitopen("plane_boarded");
    flag_wait("plane_boarded");
}

// EE timer mob_start_check: the run clock starts 0.45 s after a player's
// afterlife vision first shows, unless the black screen ended first (the core
// starts the clock there).
mob_split_clock_watch()
{
    flag_wait("initial_players_connected");
    while(!isdefined(level.game_start_time))
    {
        foreach(ghost in getplayers())
        {
            if(isdefined(ghost.afterlife_visionset) && ghost.afterlife_visionset == 1)
            {
                wait 0.45;
                if(!isdefined(level.game_start_time)) level.game_start_time = gettime();
                return;
            }
        }
        wait 0.05;
    }
}
