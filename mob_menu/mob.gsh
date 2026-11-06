/*##############################################################################
                              Mob of the Dead shared #defines
##############################################################################*/
// Inlined by every mob_menu file: #inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Plane parts
##############################################################################*/
#define PLANE_PART_COUNT  5

/*##############################################################################
                              Soul catchers (level.soul_catchers order)
##############################################################################*/
// Wolf HUD labels follow this order (docks, roof, mid) as in the old M-Practice.
#define WOLF_DOCKS   0
#define WOLF_ROOF    1
#define WOLF_MID     2
#define WOLF_SOULS   6      // Souls that fill a catcher.

/*##############################################################################
                              Roof, by the plane
##############################################################################*/
// Where the plane segments start and what Best Roof Spawn measures from.
#define ROOF_SPOT  (3646.64, 9863.25, 1712.13)

/*##############################################################################
                              Timescale used while a segment sets up
##############################################################################*/
#define SETUP_TIMESCALE  10

/*##############################################################################
                              Splits (the T6 EE Timer's solo Mob list)
##############################################################################*/
#define MOB_SPLIT_DRYER       0
#define MOB_SPLIT_GONDOLA_1   1
#define MOB_SPLIT_PLANE_1     2
#define MOB_SPLIT_GONDOLA_2   3
#define MOB_SPLIT_PLANE_2     4
#define MOB_SPLIT_GONDOLA_3   5
#define MOB_SPLIT_PLANE_3     6
#define MOB_SPLIT_CODES       7
#define MOB_SPLIT_HEADPHONES  8

/*##############################################################################
                              Plane segment start round zombies
##############################################################################*/
// Values of the "start_zombies" setting, 1 to START_ZOMBIES_MAX mean that many.
#define START_ZOMBIES_RANDOM  0     // 1 to START_ZOMBIES_MAX at random
#define START_ZOMBIES_MAX     6
