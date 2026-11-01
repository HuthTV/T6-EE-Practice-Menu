#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\dierise_menu\dierise;

/*##############################################################################
                              Die Rise map hooks
##############################################################################*/
// Everything Die Rise adds to the core menus and HUD (see practice_map in
// utility_core\basegame.gsc). Skeleton: only the descriptor; add hooks
// (build_hud, build_cheats, base_cfg_defaults, say_command, open_doors, run...)
// as the map gets features. Settings are saved in D_PRAC/.
dierise_practice_map()
{
    map = practice_map("Huth's D-Practice", "Huth's Die Rise Practice Tool", "D_PRAC/", "d_menu_gamemode");
    map.accent_color = (0.9, 0.75, 0.2);
    return map;
}

// The menu runs on classic Die Rise only (zm_highrise also hosts other game modes).
dierise_map_active()
{
    return is_classic();
}
