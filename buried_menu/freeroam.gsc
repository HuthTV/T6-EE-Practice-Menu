#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\buried_menu\buried;

/*##############################################################################
                              Freeroam
##############################################################################*/
// The skeleton's only mode: a normal game with the core menu (HUD, Cheats,
// General Settings). Mode settings and a "<mode> Settings" menu come later.

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
