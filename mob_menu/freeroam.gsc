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
// A sandbox for trying things anywhere on the map: optionally every door open,
// the tomahawk in hand and demigod on from the start. The Cheats menu
// (teleports, afterlife, tomahawk, drops) does the rest.

freeroam_initialize()
{
    mode_cfg_load("freeroam", freeroam_default_cfg());
}

freeroam_run()
{
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
    player = get_players()[0];
    player endon("disconnect");

    // The game starts in afterlife; doors and the tomahawk need the body.
    while(is_true(player.afterlife))
        wait 0.05;
    if(get_cfg_int("start_demigod") && !is_true(player.demigod))
        player toggle_demigod();
    if(get_cfg_int("start_doors"))
        player mob_open_doors();
    if(get_cfg_int("start_tomahawk"))
        player mob_give_tomahawk();
}

freeroam_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        add_cfg_toggle(settings, "Open doors on start", "start_doors");
        add_cfg_toggle(settings, "Tomahawk on start", "start_tomahawk");
        add_cfg_toggle(settings, "Demigod on start", "start_demigod");
}

freeroam_default_cfg()
{
    settings_ar = [];
    settings_ar["start_doors"] = 1;
    settings_ar["start_tomahawk"] = 0;
    settings_ar["start_demigod"] = 0;
    return settings_ar;
}
