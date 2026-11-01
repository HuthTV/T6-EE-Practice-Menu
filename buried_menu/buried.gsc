#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Buried map hooks
##############################################################################*/
// Everything Buried adds to the core menus and HUD (see practice_map in
// utility_core\basegame.gsc). Skeleton: only the descriptor; add hooks
// (build_hud, build_cheats, base_cfg_defaults, say_command, open_doors, run...)
// as the map gets features. Settings are saved in B_PRAC/.
buried_practice_map()
{
    map = practice_map("Huth's B-Practice", "Huth's Buried Practice Tool", "B_PRAC/", "b_menu_gamemode");
    map.accent_color = (0.35, 0.8, 0.35);
    return map;
}

// The menu runs on classic Buried only (zm_buried also hosts other game modes).
buried_map_active()
{
    return is_classic();
}
