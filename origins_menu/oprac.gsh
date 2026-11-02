//     #inline scripts\zm\origins_menu\oprac;

/*#############################################################################
                              Door names
##############################################################################*/
#define SPAWN_GEN3     "door_bunker_1"
#define GEN3           "door_bunker_3a"
#define WORKSHOP_GEN3  "door_bunker_3b"
#define WORKSHOP_GEN2  "door_bunker_4b"
#define GEN2           "door_bunker_4a"
#define SPAWN_GEN2     "door_bunker_2"
#define WORKSHOP_TOP   "door_bunker_5"
#define GEN5           "junk_nml_farm"
#define MOUND          "junk_nml_ruins"
#define CHURCH_BOX     "junk_village_0"
#define CHURCH_STAIRS  "junk_village_7"

/*##############################################################################
                              Staff indexes
##############################################################################*/
#define FIRE       1
#define WIND       2
#define LIGHTNING  3
#define ICE        4

/*##############################################################################
                              Start spots used by several modes
##############################################################################*/
// Origin and view angles. Craft: the excavation floor, facing that staff.
// Exit: just outside that element's Crazy Place exit.
#define CRAFT_WIND_ORIGIN       (-118.34, 157.932, -751.875)
#define CRAFT_WIND_ANGLES       (13.902, 129.183, 0)
#define CRAFT_LIGHTNING_ORIGIN  (50.0612, 199.082, -751.875)
#define CRAFT_LIGHTNING_ANGLES  (11.5839, 79.2444, 0)
#define EXIT_WIND_ORIGIN        (11234, -8687.25, -407.875)
#define EXIT_WIND_ANGLES        (0.0976524, 302.888, 0)
#define EXIT_LIGHTNING_ORIGIN   (9633.01, -6973.31, -345.875)
#define EXIT_LIGHTNING_ANGLES   (359.462, 139.132, 0)
// STG: the STG start of every staff start (user, 2026-11-02), facing as that
// mode's Craft spot until real angles are given.
#define STG_START_ORIGIN        (-24, 195, -207)

/*##############################################################################
                              Robot cycle and foot values
##############################################################################*/
#define ROBOT_RANDOM -1
#define ROBOT_ODIN    0
#define ROBOT_THOR    1
#define ROBOT_FREYA   2
#define ROBOT_CYCLE_COUNT 17    // Robot cycles to offer rng setting for.
#define ROUND12_TRIO_CYCLE 10   // Route default round 12 on cycle 10
#define FOOT_RANDOM  -1
#define FOOT_LEFT     0
#define FOOT_RIGHT    1

/*##############################################################################
                              Staff puzzle order (puzzle_rng_install)
##############################################################################*/
#define PUZZLE_RNG_ICE      1
#define PUZZLE_RNG_WIND     2
#define PUZZLE_RNG_FIRE     3
#define PUZZLE_RNG_CHAMBER  4

/*##############################################################################
                              Craftable part locations
##############################################################################*/
#define PART_RANDOM  -1

//spawn struct index (getstructarray order)
#define MAXIS_BODY_ICE_TUNNEL       0
#define MAXIS_BODY_GEN5_PATH        1
#define MAXIS_BODY_GEN4_PATH        2
#define MAXIS_ENGINE_PAP            0
#define MAXIS_ENGINE_GRAM           1
#define MAXIS_ENGINE_SCAFFOLDING    2
#define SHIELD_GEN2_CLAYMORE        0
#define SHIELD_GEN2_WHEELBARROW     1
#define SHIELD_GEN2_FOOTPRINT       2
#define SHIELD_GEN3_FIRE_TUNNEL     0
#define SHIELD_GEN3_WHEELBARROW     1
#define SHIELD_GEN3_AK74U           2
#define SHIELD_NML_GEN4_BOX         0
#define SHIELD_NML_GEN4_SIDE        1
#define SHIELD_NML_GEN5_SIDE        2

//vinyl struct index
#define VINYL_PLAYER_FAR            0
#define VINYL_PLAYER_CLOSE          1
#define VINYL_MASTER_WHEELBARROW    0
#define VINYL_MASTER_STAIRS         1
#define VINYL_MASTER_BACKSIDE       2
#define VINYL_ICE_RELAY             0
#define VINYL_ICE_MYSTERY_BOX       1
#define VINYL_ICE_TABLE             2
#define VINYL_AIR_LIGHTNING_TUNNEL  0
#define VINYL_AIR_BOXES             1
#define VINYL_AIR_STAMINA_UP        2
#define VINYL_ELEC_FIZZ             0
#define VINYL_ELEC_WIND_TUNNEL      1
#define VINYL_ELEC_CHARIOT          2
#define VINYL_FIRE_CHURCH           0
#define VINYL_FIRE_GENERATOR        1
#define VINYL_FIRE_TANK             2

/*##############################################################################
                              Run splits (shared_segment_timer)
##############################################################################*/
#define SPLIT_NML        0
#define SPLIT_ICE        1
#define SPLIT_WIND       2
#define SPLIT_FIRE       3
#define SPLIT_LIGHTNING  4
#define SPLIT_FREEDOM    5

/*##############################################################################
                              STG acquired (segment starts, "stg_start")
##############################################################################*/
#define STG_NO      0   // MP40
#define STG_YES     1   // STG-44 instead of the MP40
#define STG_PAPPED  2   // Upgraded STG-44 instead of the MP40

/*##############################################################################
                              Boomhilda ammo (held starts, "boomhilda_ammo", "boomhilda_clip")
##############################################################################*/
#define BOOMHILDA_AMMO_STEP    10  // The setting steps the total ammo by this much.
#define BOOMHILDA_AMMO_RANDOM  16  // Setting index past 150: a random total.
#define BOOMHILDA_CLIP_FULL    0   // As much of the total in the clip as fits.
#define BOOMHILDA_CLIP_RANDOM  1   // Any split of the total the clip and stock can hold.
