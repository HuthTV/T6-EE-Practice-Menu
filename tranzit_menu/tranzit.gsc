#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              TranZit map hooks
##############################################################################*/
// Everything TranZit adds to the core menus and HUD (see practice_map in
// utility_core\basegame.gsc). Skeleton: only the descriptor; add hooks
// (build_hud, build_cheats, base_cfg_defaults, say_command, open_doors, run...)
// as the map gets features. Settings are saved in T_PRAC/.
tranzit_practice_map()
{
    map = practice_map("Huth's T-Practice", "Huth's TranZit Practice Tool", "T_PRAC/", "t_menu_gamemode");
    map.accent_color = (0.3, 0.6, 1);
    return map;
}

// The menu runs on classic TranZit only: zm_transit also hosts Bus Depot, Town,
// Farm and Grief (vanilla zm_transit tells them apart the same way).
tranzit_map_active()
{
    return is_classic() && getdvar("ui_zm_mapstartlocation") == "transit";
}
