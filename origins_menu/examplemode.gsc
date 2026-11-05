#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Example mode
##############################################################################*/
// A hollow mode to copy when adding a practice mode. Its two hook-up lines are
// commented out, so it does not appear in the menu. To add a mode "mymode":
//
//   1. Copy this file to origins_menu\mymode.gsc and rename the examplemode
//      prefix. Keep the #include lines above for every file whose functions it
//      calls, and the #inline line for the shared #defines.
//   2. Register it in register_modes() in zm_tomb\o-prac-menu.gsc, next to the
//      commented-out examplemode line, and add
//          #include scripts\zm\origins_menu\mymode;
//      to zm_tomb\o-prac-menu.gsc:
//          register_mode("mymode", "My Mode", ::mymode_initialize, ::mymode_run, ::mymode_build_menu);
//      The last argument gives it menu options; omit it for none.
//   3. build.py -check checks it (including any missing #include);
//      build.py -deploy -source installs it to try.
// Mob of the Dead modes work the same way, in mob_menu\ and zm_prison\m-prac-menu.gsc.

// Runs while the map loads, before players spawn: load the mode's settings and
// install its replacefuncs here.
examplemode_initialize()
{
    // Saved to O_PRAC/examplemode.cfg; the defaults fill in any missing setting.
    mode_cfg_load("examplemode", examplemode_default_cfg());
}

// Runs once the map has started: set up the game state, then open the menu.
examplemode_run()
{
    flag_wait("initial_blackscreen_passed");
    // The menu can only be opened once this is set.
    flag_set("menu_active");
}

// The mode's own menus; build_menu_tree puts them right after Practice Modes. Start with its
// "<mode> Settings" menu, which holds every option only this mode has.
examplemode_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Start", level.mode.label);
        add_cfg_toggle(settings, "Example Toggle", "example_toggle");
        add_cfg_choice(settings, "Example Choice", "example_choice", array("first", "second", "third"));
}

// Every setting the mode reads, with its default.
examplemode_default_cfg()
{
    settings_ar = [];
    settings_ar["example_toggle"] = 0;
    settings_ar["example_choice"] = 0;
    return settings_ar;
}
