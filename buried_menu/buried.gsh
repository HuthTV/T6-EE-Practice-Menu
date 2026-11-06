/*##############################################################################
                              Buried shared #defines
##############################################################################*/
// Inlined by every buried_menu file: #inline scripts\zm\buried_menu\buried;
// Skeleton: add the map's constants here as features need them.

// Who punches a tunnel sign. Vanilla: 2 signs each and 1 for both, so 3 per side.
#define SIGN_RANDOM       0
#define SIGN_BOTH         1
#define SIGN_MAXIS        2
#define SIGN_RICHTOFEN    3

// The two forks of Richtofen's wisp, as struct targets of the map (see
// buried_ctw_ric_get_next_wisp_struct).
#define WISP_FORK_START   "pf729_auto72"
#define WISP_FORK_END     "pf729_auto71"

#define BURIED_SIDE_RICHTOFEN  0
#define BURIED_SIDE_MAXIS      1

// Splits (the B2EE timer's solo Buried list).
#define BURIED_SPLIT_BOXHIT        0
#define BURIED_SPLIT_GHOSTS        1
#define BURIED_SPLIT_CIPHER        2
#define BURIED_SPLIT_TIME_TRAVEL   3
#define BURIED_SPLIT_SHARPSHOOTER  4
