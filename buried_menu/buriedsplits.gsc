#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\splits;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Buried split timer
##############################################################################*/
// The B2EE timer's solo Buried splits (wait_for_split), the same on either side,
// drawn by the core split timer. Splits run from first to Sharpshooter, each case
// falls through to the next.
buried_split_timer(first)
{
    level endon("end_game");
    labels = array("^3Boxhit ^7", "^3Ghosts ^7", "^3Cipher ^7", "^3Time Travel ^7", "^3Sharpshooter ^7");
    practice_splits_start(labels, first);

    switch(first)
    {
        case BURIED_SPLIT_BOXHIT:
            flag_wait("chest_has_been_used");
            practice_split(BURIED_SPLIT_BOXHIT);
        case BURIED_SPLIT_GHOSTS:
            flag_wait("spawn_ghosts");
            practice_split(BURIED_SPLIT_GHOSTS);
        case BURIED_SPLIT_CIPHER:
            wait_for_buildable("buried_sq_oillamp");
            practice_split(BURIED_SPLIT_CIPHER);
        case BURIED_SPLIT_TIME_TRAVEL:
            while(!flag("sq_tpo_special_round_active") && !flag("sq_wisp_saved_with_time_bomb")) wait 0.05;
            practice_split(BURIED_SPLIT_TIME_TRAVEL);
        case BURIED_SPLIT_SHARPSHOOTER:
            level waittill_any("sq_richtofen_complete", "sq_maxis_complete");
            practice_split(BURIED_SPLIT_SHARPSHOOTER);
    }
}
