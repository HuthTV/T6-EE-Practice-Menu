#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\mob_menu\mob;
#include scripts\zm\mob_menu\planeutil;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Warden's Nade
##############################################################################*/
// The player starts outside the closed Warden's Office gate with the route done
// up to the first plane (user, 2026-11-06). Plane I's setup opens every afterlife
// door, so the gate is closed again at the end of it. The gate opens from its
// shock box in afterlife, as vanilla. Reset Gate (menu, chat "gate") closes it and
// resets the box, refills afterlives and grenades and puts the player back, so
// the trick can be repeated. No timer.

#define WARDENSNADE_ROUND  3
#define WARDENSNADE_SPOT   (-324, 9288, 1366)   // cellblock_west_warden_player_spawn
#define WARDENSNADE_ANGLES (0, 180, 0)          // Facing the gate.
#define WARDENSNADE_FLAG   "activate_warden_office"

wardensnade_initialize()
{
    flag_init("plane_released");
    level.mob_gate_reset = ::wardensnade_reset;
    level.practice_map.say_help = "^7, ^3gate";
    mode_cfg_load("wardensnade", wardensnade_default_cfg());
}

wardensnade_run()
{
    wardensnade_find_gate();
    segment = mob_plane_segment();
    segment.split = undefined;
    segment.prebuilt = true;
    segment.start_round = get_cfg_int("start_round");
    segment.start_zombies = get_cfg_int("start_zombies");
    segment.spot = WARDENSNADE_SPOT;
    segment.on_setup = ::wardensnade_setup;
    level mob_run_plane_segment(segment);
}

wardensnade_default_cfg()
{
    settings_ar = [];
    settings_ar["start_round"] = WARDENSNADE_ROUND;
    settings_ar["start_zombies"] = START_ZOMBIES_RANDOM;
    return settings_ar;
}

wardensnade_build_menu(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        create_option(settings, "Reset Gate", ::wardensnade_reset);
        create_option(settings, "Round: ^3" + get_cfg_int("start_round"), ::cfg_increment_int, "start_round", array(WARDENSNADE_ROUND, 6));
        create_option(settings, "Zombies Left: ^3" + mob_start_zombies_text(), ::cfg_increment_int, "start_zombies", array(START_ZOMBIES_RANDOM, START_ZOMBIES_MAX));
}

// The gate's trigger and shock box, and the box's unshocked model, while it still
// has it.
wardensnade_find_gate()
{
    foreach(door in getentarray("zombie_door", "targetname"))
        if(isdefined(door.script_flag) && door.script_flag == WARDENSNADE_FLAG)
            level.wardensnade_door = door;

    s_struct = getstruct(level.wardensnade_door.target, "targetname");
    level.wardensnade_box = getent(s_struct.target, "targetname");
    level.wardensnade_box_model = level.wardensnade_box.model;
}

// End of the setup, the player already at the gate.
wardensnade_setup()
{
    wardensnade_close_gate();
    self wardensnade_restock();
    self setplayerangles(WARDENSNADE_ANGLES);
}

// What vanilla door_opened and alcatraz_afterlife_doors did, undone: the gate and
// its clip move back, the trigger returns and door_think runs again, which waits
// for the box as at map start.
wardensnade_close_gate()
{
    door = level.wardensnade_door;
    if(!is_true(door._door_open)) return;

    while(is_true(door.door_is_moving)) wait 0.05;
    door._door_open = 0;
    flag_clear(WARDENSNADE_FLAG);
    foreach(part in door.doors)
        part thread maps\mp\zombies\_zm_blockers::door_activate(undefined, false);
    door trigger_on();

    level.wardensnade_box setmodel(level.wardensnade_box_model);
    level.wardensnade_box setanim(level.shockbox_anim["off"]);
    door thread maps\mp\zombies\_zm_blockers::door_think();
}

wardensnade_restock()
{
    self mob_refill_afterlives();
    lethal = self get_player_lethal_grenade();
    if(isdefined(lethal)) self givemaxammo(lethal);
}

// Menu action and chat "gate". A ghost stays where it is: moving it would leave
// the body behind.
wardensnade_reset()
{
    wardensnade_close_gate();
    self wardensnade_restock();
    if(!is_true(self.afterlife))
    {
        self setorigin(WARDENSNADE_SPOT);
        self setplayerangles(WARDENSNADE_ANGLES);
    }
    self iprintln("Gate reset");
}
