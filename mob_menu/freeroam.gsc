#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\mob_menu\mob;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Freeroam
##############################################################################*/
// A sandbox for trying things anywhere on the map (user, 2026-11-05): revived out of
// the opening afterlife, every door open, MP5 and tomahawk in hand, every wolf full,
// respawning skulls on and no zombies. No timer, no presets, no settings. Teleport,
// Afterlife, Tomahawk and Cheats do the rest.

freeroam_initialize()
{
    level.mode.no_slots = true;
    mode_cfg_load("freeroam", freeroam_default_cfg());
}

freeroam_run()
{
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
    player = get_players()[0];
    player endon("disconnect");

    // The game starts in afterlife, doors and the tomahawk need the body.
    player mob_wait_for_afterlife();
    player mob_revive_from_afterlife();
    player mob_give_weapon("mp5k_zm");
    player mob_open_doors();
    player mob_give_tomahawk();
    mob_fill_wolves();

    flag_wait("spawn_zombies");
    player mob_toggle_spawns();
}

// A mode setting wins over basegame.cfg, so the Tomahawk row still switches it here.
freeroam_default_cfg()
{
    settings_ar = [];
    settings_ar["respawning_skull"] = 1;
    return settings_ar;
}
