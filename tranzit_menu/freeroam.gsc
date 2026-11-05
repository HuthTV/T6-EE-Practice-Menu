#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\tranzit_menu\tranzit;

/*##############################################################################
                              Freeroam
##############################################################################*/
// A normal game with the core menu (HUD, Cheats, General Settings) and no mode
// settings.

freeroam_initialize()
{
    mode_cfg_load("freeroam", freeroam_default_cfg());
}

freeroam_run()
{
    flag_wait("initial_blackscreen_passed");
    flag_set("menu_active");
}

freeroam_default_cfg()
{
    settings_ar = [];
    return settings_ar;
}
