#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#inline scripts\zm\mob_menu\mob;

/*##############################################################################
                              Mob of the Dead map hooks
##############################################################################*/
// Everything Mob adds to the core menus and HUD (see practice_map in
// utility_core\basegame.gsc). Ported from the old M-Practice beta V2.1
// (old-mob-practice), whose settings were dvars that reset on game restart;
// here they are saved in M_PRAC/ (older builds used MPRAC/).
mob_practice_map()
{
    map = practice_map("Huth's M-Prac", "Huth's Mob Practice Tool", "M_PRAC/", "m_menu_gamemode");
    // Run splits in MOB_SPLIT_* order (mob.gsh); Headphones, the last, always shows.
    map.split_names = array("dryer", "gondola_1", "plane_1", "gondola_2", "plane_2", "gondola_3", "plane_3", "codes", "headphones");
    map.split_labels = array("Dryer", "Gondola I", "Plane I", "Gondola II", "Plane II", "Gondola III", "Plane III", "Codes", "Headphones");
    map.accent_color = (1, 0.5, 0.25);
    map.menu_icon = "faction_prison";     // Scoreboard emblem. faction_inmates is only in the Grief zone, not classic.
    map.cursor_color = (1, 0.62, 0.36);
    map.header_text_color = (0, 0, 0);
    map.initialize = ::mob_initialize;
    map.build_hud = ::mob_build_hud;
    map.build_cheats = ::mob_build_cheats;
    map.build_map_menu = ::mob_build_root_menus;
    map.base_cfg_defaults = ::mob_base_cfg_defaults;
    map.character_names = array("Finn", "Sal", "Billy", "Arlington");
    map.character_chosen = ::mob_character_chosen;
    map.say_command = ::mob_say_command;
    map.open_doors = ::mob_open_doors;
    map.run = ::mob_run;
    return map;
}

// The menu runs on classic Mob of the Dead only (zm_prison also hosts Grief on
// Cellblock).
mob_map_active()
{
    return is_classic();
}

// Map-wide replacefuncs, for every mode.
mob_initialize()
{
    replacefunc(maps\mp\zombies\_zm_afterlife::afterlife_remove, ::mob_afterlife_remove);
    replacefunc(maps\mp\zombies\_zm_weap_tomahawk::tomahawk_return_player, ::mob_tomahawk_return_player);
    replacefunc(maps\mp\zm_prison_sq_bg::tomahawk_the_macguffin, ::mob_tomahawk_the_macguffin);
    replacefunc(maps\mp\zm_prison_sq_bg::give_player_macguffin_upon_receipt, ::mob_give_player_macguffin_upon_receipt);
    replacefunc(maps\mp\zm_alcatraz_distance_tracking::zombie_tracking_init, ::mob_zombie_tracking_init);
    replacefunc(maps\mp\zm_alcatraz_distance_tracking::delete_zombie_noone_looking, ::mob_delete_zombie_noone_looking);
    replacefunc(maps\mp\zm_alcatraz_sq::dryer_trigger_thread, ::mob_dryer_trigger_thread);
    mob_teleports_init();
    level thread mob_track_afterlife_spawns();
}

// As vanilla's assign_lowest_unused_character_index.
mob_character_chosen(index)
{
    if(index == 3) level.has_weasel = 1;
}

mob_base_cfg_defaults(settings_ar)
{
    // HUD
    settings_ar["hud_wolves"] = 0;
    settings_ar["hud_mana"] = 0;
    settings_ar["hud_despawns"] = 0;
    settings_ar["hud_autoscroll"] = 0;   // Dryer and bridge countdowns.
    settings_ar["force_mantle_spawn"] = 0; // Claim the mantle hole spawn under the plane.
    settings_ar["mantle_spawn_set"] = 0;   // Mantle spawn position, set in game.
    settings_ar["mantle_spawn_x"] = 0;
    settings_ar["mantle_spawn_y"] = 0;
    settings_ar["mantle_spawn_z"] = 0;
    // Cheats
    settings_ar["infinite_afterlives"] = 0;
    settings_ar["no_tomahawk_cooldown"] = 0;
    settings_ar["respawning_skull"] = 0;
    settings_ar["plane_timescale"] = 1;  // Timescale 10 during the flight.
    settings_ar["tp_return"] = 1;        // [{+actionslot 3}] returns to the last teleport.
    return settings_ar;
}

mob_build_hud(hud)
{
	add_cfg_toggle(hud, "Wolf Souls", "hud_wolves");
	add_cfg_toggle(hud, "Afterlife Mana", "hud_mana");
	add_cfg_toggle(hud, "Despawn Log", "hud_despawns");
	add_cfg_toggle(hud, "Dryer/Bridge Timers", "hud_autoscroll");
}

mob_build_cheats(cheats)
{
	create_option(cheats, "Spawns: " + int_compare(!flag("spawn_zombies"), "^5frozen", "^2running"), ::mob_toggle_spawns);
	create_option(cheats, "Give Plane Parts", ::mob_get_plane_parts);
	create_option(cheats, "Give MP5", ::mob_give_weapon, "mp5k_zm");
	add_cfg_toggle(cheats, "Plane Timescale", "plane_timescale");
}

// Root rows of their own (user, 2026-11-05: the root has the space).
mob_build_root_menus(root)
{
	teleport = add_submenu(root, "teleport", "Teleport");
		add_cfg_toggle(teleport, "Return Key [{+actionslot 3}]", "tp_return");
		foreach(name in level.mob_teleport_names)
			create_option(teleport, name, ::mob_teleport, name);

	afterlife = add_submenu(root, "afterlife", "Afterlife");
		add_cfg_toggle(afterlife, "Infinite Afterlives", "infinite_afterlives");
		create_option(afterlife, "Infinite Mana: " + int_compare(is_true(self.infinite_mana)), ::mob_toggle_infinite_mana);
		create_option(afterlife, "Refill Afterlives", ::mob_refill_afterlives);
		add_cfg_toggle(afterlife, "Best Roof Spawn", "force_mantle_spawn");
		create_option(afterlife, "Save Last Spawn: " + mob_mantle_spawn_text(), ::mob_set_mantle_spawn);

	tomahawk = add_submenu(root, "tomahawk", "Tomahawk");
		create_option(tomahawk, "Give Tomahawk", ::mob_give_tomahawk);
		create_option(tomahawk, "Fill Wolves", ::mob_fill_wolves);
		add_cfg_toggle(tomahawk, "Zero Cooldown", "no_tomahawk_cooldown");
		add_cfg_toggle(tomahawk, "Respawning Skulls", "respawning_skull");
}

// Chat teleports: say a teleport name.
mob_say_command(message)
{
    if(message == "gate" && isdefined(level.mob_gate_reset))
        self [[ level.mob_gate_reset ]]();
    else if(isdefined(level.mob_teleports[message]))
        self mob_teleport(message);
}

// Started by the core with its HUDs, after the start-up message.
mob_run()
{
    level thread mob_wolves_hud();
    level thread mob_mana_hud();
    level thread mob_teleport_return_watcher();
    level thread mob_force_mantle_spawn();
    if(is_true(level.is_forever_solo_game))
    {
        level thread mob_plane_timescale();
        level thread mob_countdown_dryer();
        level thread mob_countdown_bridge();
    }
}

/*##############################################################################
                              Teleports
##############################################################################*/
// Spots from the old M-Practice, in menu order.
mob_teleports_init()
{
    level.mob_teleport_names = array("cafe", "codes", "docks", "dryer", "jugg", "roof", "spawn", "toma", "warden", "wolf1", "wolf2", "wolf3");
    level.mob_teleports = [];
    level.mob_teleports["cafe"] = (2588, 9641, 1336);
    level.mob_teleports["codes"] = (188, 8296, 283);
    level.mob_teleports["docks"] = (-1275, 5489, -71);
    level.mob_teleports["dryer"] = (1951, 10424, 1144);
    level.mob_teleports["jugg"] = (909, 5808, 264);
    level.mob_teleports["roof"] = (3392, 9665, 1713);
    level.mob_teleports["spawn"] = (1396, 10583, 1336);
    level.mob_teleports["toma"] = (621, 10016, 1128);
    level.mob_teleports["warden"] = (-919, 9338, 1336);
    level.mob_teleports["wolf1"] = (144, 6116, 28);
    level.mob_teleports["wolf2"] = (3694, 9663, 1528);
    level.mob_teleports["wolf3"] = (883, 9664, 1545);
}

// Teleports only into an active zone, so the player cannot land out of the map.
mob_teleport(name)
{
    origin = level.mob_teleports[name];
    if(!check_point_in_enabled_zone(origin))
    {
        self iprintln("Zone not active");
        return;
    }
    self setorigin(origin);
    self.mob_last_teleport = origin;
    if(get_cfg_int("tp_return"))
        self iprintln("Press ^3[{+actionslot 3}]^7 to return to " + name);
}

// [{+actionslot 3}] with the menu closed returns to the last teleport. The old
// tool read an unset position before the first teleport; this waits for one.
mob_teleport_return_watcher()
{
    level endon("end_game");
    while(true)
    {
        foreach(player in get_players())
        {
            if(!get_cfg_int("tp_return") || !isdefined(player.mob_last_teleport) || player menu_open()) continue;
            if(!player actionslotthreebuttonpressed()) continue;
            player setorigin(player.mob_last_teleport);
            while(player actionslotthreebuttonpressed())
                wait 0.05;
        }
        wait 0.05;
    }
}

/*##############################################################################
                              Cheats
##############################################################################*/
mob_toggle_spawns()
{
    if(flag("spawn_zombies"))
    {
        flag_clear("spawn_zombies");
        level.zombie_total += get_round_enemy_array().size;
        mob_kill_zombies();
    }
    else
        flag_set("spawn_zombies");
    self refresh_menu();
}

// Kills every zombie and Brutus on the map.
mob_kill_zombies()
{
    zombies = getaispeciesarray("axis", "all");
    for(i = 0; i < zombies.size; i++)
    {
        if(isdefined(zombies[i]) && isalive(zombies[i]))
            zombies[i] dodamage(zombies[i].health + 666, zombies[i].origin);
        wait 0.05;
    }
}

mob_give_weapon(weapon)
{
    self maps\mp\zombies\_zm_weapons::weapon_give(weapon, undefined, undefined, 0);
}

mob_get_plane_parts()
{
    foreach(piece in array("cloth", "fueltanks", "engine", "steering", "rigging"))
        self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("plane", piece);
}

mob_toggle_infinite_mana()
{
    self maps\mp\zombies\_zm_afterlife::afterlife_infinite_mana(!is_true(self.infinite_mana));
    self refresh_menu();
}

mob_refill_afterlives()
{
    self.lives = 2;
    self thread maps\mp\zombies\_zm_afterlife::afterlife_add();
}

// Fills every soul catcher, as if each had its souls.
mob_fill_wolves()
{
    for(i = 0; i < level.soul_catchers.size; i++)
        mob_fill_wolf(i, WOLF_SOULS);
}

// Wakes soul catcher i and gives it souls (WOLF_SOULS fills it).
mob_fill_wolf(i, souls)
{
    level.soul_catchers[i].souls_received = 1;
    level.soul_catchers[i] notify("first_zombie_killed_in_zone");
    level.soul_catchers[i] notify("wolf_intro_anim_complete");
    level.soul_catchers[i].souls_received = souls;
}

// Gives the tomahawk as the soul catcher pickup does (old M-Practice give_tomahawk).
mob_give_tomahawk()
{
    if(!flag("soul_catchers_charged"))
        mob_fill_wolves();

    if(is_true(self.afterlife))
    {
        self iprintln("Not in afterlife");
        return;
    }
    if(self hasweapon("bouncing_tomahawk_zm") || self hasweapon("upgraded_tomahawk_zm"))
    {
        self iprintln("Already have the tomahawk");
        return;
    }
    self play_sound_on_ent("purchase");
    self notify("tomahawk_picked_up");
    level notify("bouncing_tomahawk_zm_aquired");
    self notify("player_obtained_tomahawk");
    self.tomahawk_upgrade_kills = 0;
    self.killed_with_only_tomahawk = 1;
    self.killed_something_thq = 0;
    self set_player_tactical_grenade("bouncing_tomahawk_zm");
    self.current_tomahawk_weapon = "bouncing_tomahawk_zm";
    gun = self getcurrentweapon();
    self disable_player_move_states(1);
    self giveweapon("zombie_tomahawk_flourish");
    self switchtoweapon("zombie_tomahawk_flourish");
    self waittill_any("player_downed", "weapon_change_complete");
    self setclientfieldtoplayer("tomahawk_in_use", 1);
    self switchtoweapon(gun);
    self enable_player_move_states();
    self takeweapon("zombie_tomahawk_flourish");
    self giveweapon("bouncing_tomahawk_zm");
    self givemaxammo("bouncing_tomahawk_zm");
}

/*##############################################################################
                              Open doors (replaces the core Open Doors)
##############################################################################*/
// Opens every door, lock and power the route needs, all from where the player
// stands (no teleporting): bought doors, key, key locks, afterlife boxes,
// generators, nixie code, elevator and the dryer, which runs its cycle without
// anyone there (vanilla dryer_trigger_thread).
mob_open_doors()
{
    if(is_true(self.afterlife))
    {
        self iprintln("Can't open doors in afterlife");
        return;
    }
    if(is_true(level.mob_all_doors_open))
    {
        self iprintln("Doors are already open");
        return;
    }
    level.mob_all_doors_open = true;

    mob_open_zombie_doors(undefined);
    self mob_complete_key_quest();
    level notify("intro_powerup_activate");
    level notify("cell_1_powerup_activate");
    level notify("cell_2_powerup_activate");
    mob_activate_generators();
    level notify("cable_puzzle_gate_afterlife");
    level notify("unlock_all_perk_machines");
    level notify("intro_powerup_restored");
    mob_fill_wolves();
    level notify("laundry_power_switch_afterlife");
    mob_run_dryer_skipped();
    self mob_unlock_afterlife_doors();
    level notify("gondola_powered_on_roof");
    mob_complete_code();
    self mob_open_key_locks();
    self mob_open_elevator();
}

// Buys every closed zombie_door for free, or only those at the given origins.
mob_open_zombie_doors(origins)
{
    player = get_players()[0];
    foreach(trigger in getentarray("zombie_door", "targetname"))
    {
        if(is_true(trigger._door_open)) continue;
        if(isdefined(origins) && !mob_origin_listed(trigger.origin, origins)) continue;
        trigger.zombie_cost = 0;
        trigger notify("trigger", player, 1);
    }
}

mob_origin_listed(origin, origins)
{
    foreach(listed in origins)
        if(distancesquared(origin, listed) < 1)
            return true;
    return false;
}

// Drops the master key and gives it to the player.
mob_complete_key_quest()
{
    if(is_true(level.is_master_key_west))
        level notify("master_key_pulley_west");
    else
        level notify("master_key_pulley_east");

    if(!flag("key_found"))
    {
        maps\mp\zm_alcatraz_craftables::onpickup_key(self);
        self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("quest_key1", "p6_zm_al_key");
    }
}

// Enters the nixie tube code (vanilla nixie_tube_add_code makes it a*100+b*10+c).
mob_complete_code()
{
    // Vanilla rolls the code a moment into the game, after a fast setup gets here.
    for(i = 0; i < 400 && !(isdefined(level.a_nixie_tube_solution) && isdefined(level.a_nixie_tube_solution[3])); i++)
        wait 0.05;
    a = level.a_nixie_tube_solution[1];
    b = level.a_nixie_tube_solution[2];
    c = level.a_nixie_tube_solution[3];
    level notify("nixie_" + (a * 100 + b * 10 + c));
}

mob_activate_generators()
{
    for(i = 1; i < 4; i++)
        level notify("generator_panel_" + i + "_afterlife");
}

// Opens the citadel elevator door, which ends the nixie countdown (vanilla
// nixie_tube_elevator_door). Waits for the countdown to start after a code was
// entered, so it counts as completed rather than reset (at most 5 s).
mob_open_elevator()
{
    for(i = 0; i < 100 && flag("nixie_puzzle_solved") && !flag("nixie_countdown_started"); i++)
        wait 0.05;
    t_elevator_door = getent("nixie_elevator_door", "targetname");
    if(isdefined(t_elevator_door)) t_elevator_door notify("trigger", self);
}

// The game opens in afterlife; waits for it (at most 20 s), so the setup can
// use the ghost.
mob_wait_for_afterlife()
{
    for(i = 0; i < 400 && !(is_true(self.afterlife) && isdefined(self.e_afterlife_corpse)); i++)
        wait 0.05;
}

// Revives the player from afterlife without touching the body. The body is a
// clone, and vanilla revive_success on a clone only notifies "player_revived";
// afterlife_laststand then returns the player to it with afterlife_leave.
// afterlife_laststand only starts listening after afterlife_fake_revive (wait 1),
// afterlife_enter and another 0.5 s, and a notify before that is lost, so this
// repeats it every frame until the player is out (at most 10 s).
mob_revive_from_afterlife()
{
    for(i = 0; i < 200 && is_true(self.afterlife); i++)
    {
        if(isdefined(self.e_afterlife_corpse))
            self.e_afterlife_corpse notify("player_revived", self);
        wait 0.05;
    }
    if(is_true(self.afterlife)) iprintln("^1Plane setup: the scripted revive did not work");
}

// Shocks every afterlife door's box, with lightning hands lent for the moment.
mob_unlock_afterlife_doors()
{
    primaries = [];
    if(!is_true(self.afterlife))
    {
        primaries = self getweaponslistprimaries();
        foreach(weapon in primaries)
            self takeweapon(weapon);
        self giveweapon("lightning_hands_zm");
    }
    wait 0.5;

    level.afterlife_interact_dist = 9999999;
    foreach(door in getentarray("zombie_door", "targetname"))
    {
        if(!isdefined(door.script_noteworthy) || door.script_noteworthy != "afterlife_door") continue;
        s_struct = getstruct(door.target, "targetname");
        m_shockbox = getent(s_struct.target, "targetname");
        m_shockbox notify("damage", 5001, self);
        s_struct notify("damage", 5001, self);
        door notify("damage", 5001, self);
    }
    wait 0.5;

    if(!is_true(self.afterlife))
    {
        self takeweapon("lightning_hands_zm");
        foreach(weapon in primaries)
            self giveweapon(weapon);
    }
    level.afterlife_interact_dist = 256;
}

// Opens the five master key doors from anywhere: for each closed lock, what
// vanilla master_key_door_trigger_thread does when the key holder uses it
// (zm_alcatraz_sq setup_key_doors keeps each stub on key_door_<n>_trigger).
mob_open_key_locks()
{
    for(n_door_index = 1; n_door_index <= 5; n_door_index++)
    {
        s_door = getstruct("key_door_" + n_door_index + "_trigger", "targetname");
        if(!isdefined(s_door) || !isdefined(s_door.unitrigger_stub)) continue;
        stub = s_door.unitrigger_stub;
        if(is_true(stub.master_key_door_opened)) continue;
        stub.master_key_door_opened = 1;
        stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();
        level thread maps\mp\zm_alcatraz_sq::open_custom_door_master_key(n_door_index, self);
        level thread maps\mp\zombies\_zm_unitrigger::unregister_unitrigger(stub);
    }
}

/*##############################################################################
                              HUDs
##############################################################################*/
// Souls in each soul catcher once it has started, until all three are charged.
mob_wolves_hud()
{
    labels = array(&"docks^1\n    ", &"roof^1\n   ", &"mid^1\n  ");
    huds = [];
    for(i = 0; i < 3; i++)
    {
        huds[i] = createserverfontstring("default", 1.4);
        huds[i] setpoint("TOP", "CENTER", -40 + i * 40, -200);
        huds[i].label = labels[i];
        huds[i].alpha = 0;
        huds[i].hidewheninmenu = 1;
    }
    huds[2].x -= 2;

    while(!flag("soul_catchers_charged"))
    {
        for(i = 0; i < level.soul_catchers.size && i < 3; i++)
        {
            huds[i].alpha = 0;
            if(get_cfg_int("hud_wolves") && level.soul_catchers[i].souls_received > 0)
            {
                huds[i].alpha = 0.8;
                huds[i] setvalue(level.soul_catchers[i].souls_received);
            }
        }
        wait 0.05;
    }
    foreach(hud in huds)
        hud destroy();
}

// Afterlife mana while in afterlife (vanilla manacur, 200 is full).
mob_mana_hud()
{
    level endon("end_game");
    while(true)
    {
        foreach(player in get_players())
        {
            if(!isdefined(player.practice_mana_hud))
            {
                player.practice_mana_hud = player createfontstring("default", 1.4);
                player.practice_mana_hud setpoint("CENTER", "CENTER", 0, 195);
                player.practice_mana_hud.color = (0.45, 0.74, 0.83);
                player.practice_mana_hud.hidewheninmenu = 1;
            }
            show = get_cfg_int("hud_mana") && is_true(player.afterlife) && isdefined(player.manacur);
            player.practice_mana_hud.alpha = 0;
            if(show)
            {
                player.practice_mana_hud.alpha = 0.8;
                player.practice_mana_hud setvalue(int(player.manacur));
            }
        }
        wait 0.05;
    }
}

/*##############################################################################
                              Afterlife spawn prediction
##############################################################################*/
// Where vanilla afterlife_get_spawnpoint would put this player if they died now.
// Its steps (_zm_afterlife.gsc, _zm.gsc):
//   1. check_for_valid_spawn_in_zone: the death zone's spawn group, closest
//      first; the first spot 500+ units away that no player stands on, else the
//      farthest free one. Fixed by the death spot.
//   2. If the zone has no group or no spot (zone_infirmary_roof, under the
//      plane, has none): check_for_valid_spawn_near_position picks the nearest
//      unlocked group (fixed by the death spot), and get_valid_spawn_location a
//      spot in it: the one already claimed by this player (.plyr = entity
//      number), else a random free one, which it then claims. So the first death
//      that uses a group rolls the spot; later ones reuse it.
// Returns a struct: zone; group (the spawn group's struct, step 2); spawns (its
// spots in map order); index (predicted spot, step 1); claimed (this player's
// claimed spot, step 2: their spawn there, else a random roll).
mob_predict_afterlife_spawn()
{
    prediction = spawnstruct();
    prediction.spawns = [];
    prediction.zone = self mob_afterlife_death_zone();

    // Step 1: the zone's own group.
    if(isdefined(prediction.zone))
    {
        foreach(spawn_point in maps\mp\gametypes_zm\_zm_gametype::get_player_spawns_for_gametype())
        {
            if(spawn_point.script_noteworthy != prediction.zone) continue;
            spawns = getstructarray(spawn_point.target, "targetname");
            index = self mob_zone_spawn_index(spawns);
            if(isdefined(index))
            {
                prediction.spawns = spawns;
                prediction.index = index;
                return prediction;
            }
        }
    }

    // Step 2: the nearest group.
    prediction.group = mob_nearest_spawn_group(self.origin);
    if(!isdefined(prediction.group)) return prediction;
    prediction.spawns = getstructarray(prediction.group.target, "targetname");
    num = self getentitynumber();
    for(i = 0; i < prediction.spawns.size; i++)
        if(isdefined(prediction.spawns[i].plyr) && prediction.spawns[i].plyr == num && !positionwouldtelefrag(prediction.spawns[i].origin))
            prediction.claimed = i;
    return prediction;
}

// Step 1 of mob_predict_afterlife_spawn: vanilla check_for_valid_spawn_in_zone's
// pick from the zone's spots, or undefined.
mob_zone_spawn_index(spawns)
{
    closest = get_array_of_closest(self.origin, spawns);
    foreach(s_spawn in closest)
    {
        if(!flag("afterlife_start_over") && isdefined(s_spawn.en_num) && s_spawn.en_num != self.playernum) continue;
        if(positionwouldtelefrag(s_spawn.origin) || distancesquared(self.origin, s_spawn.origin) < 250000) continue;
        return mob_array_index(spawns, s_spawn);
    }
    foreach(s_spawn in maps\mp\zm_alcatraz_utility::get_array_of_farthest(self.origin, closest, undefined, 250000))
    {
        if(positionwouldtelefrag(s_spawn.origin)) continue;
        return mob_array_index(spawns, s_spawn);
    }
    return undefined;
}

// COPY: maps\mp\zombies\_zm::check_for_valid_spawn_near_position's group choice
// (its quirks included), returning the group instead of a spot in it.
mob_nearest_spawn_group(v_position)
{
    spawn_points = maps\mp\gametypes_zm\_zm_gametype::get_player_spawns_for_gametype();

    if ( spawn_points.size == 0 )
        return undefined;

    closest_group = undefined;
    closest_distance = 100000000;
    backup_group = undefined;
    backup_distance = 100000000;

    for ( i = 0; i < spawn_points.size; i++ )
    {
        if ( isdefined( spawn_points[i].script_int ) )
            ideal_distance = spawn_points[i].script_int;
        else
            ideal_distance = 1000;

        if ( spawn_points[i].locked == 0 )
        {
            dist = distancesquared( v_position, spawn_points[i].origin );

            if ( dist < ideal_distance * ideal_distance )
            {
                if ( dist < closest_distance )
                {
                    closest_distance = dist;
                    closest_group = i;
                }
            }
            else if ( dist < backup_distance )
            {
                backup_group = i;
                backup_distance = dist;
            }
        }

        if ( !isdefined( closest_group ) )
            closest_group = backup_group;
    }

    if ( !isdefined( closest_group ) ) //MODIFIED: return the group itself.
        return undefined;
    return spawn_points[closest_group];
}

// The zone vanilla uses: on a moving gondola, the end it is heading to.
mob_afterlife_death_zone()
{
    if(isdefined(level.e_gondola) && is_true(level.e_gondola.is_moving) && self maps\mp\zm_alcatraz_travel::is_player_on_gondola())
    {
        switch(level.e_gondola.destination)
        {
            case "roof":  return "zone_cellblock_west_gondola";
            case "docks": return "zone_dock";
        }
    }
    return self maps\mp\zombies\_zm_zonemgr::get_player_zone();
}

mob_array_index(array, item)
{
    for(i = 0; i < array.size; i++)
        if(array[i] == item)
            return i;
    return undefined;
}

/*##############################################################################
                              Best roof spawn (under the plane)
##############################################################################*/
// Dying under the plane (zone_infirmary_roof) uses the nearest spawn group, where
// the first death rolls a spot and later ones reuse it (see above). "Best Roof
// Spawn" claims a spot for the player before every death, as if they had rolled
// it: the spawn struct nearest the plane, or the one saved in game (die there until
// the ghost lands on the spot wanted, then "Save Last Spawn"). Keys keep the old
// mantle names.

// After each afterlife spawn, remembers the spawn struct the ghost landed on
// (afterlife_fake_revive puts the player on it 1 s after the corpse appears).
mob_track_afterlife_spawns()
{
    level endon("end_game");
    flag_wait("initial_players_connected");
    foreach(player in get_players())
        player thread mob_track_afterlife_spawn();
}

mob_track_afterlife_spawn()
{
    self endon("disconnect");
    level endon("end_game");
    while(true)
    {
        self waittill("player_fake_corpse_created");
        wait 1.1;
        best = undefined;
        best_dist = 10000; // 100 units squared: a spawn struct the ghost stands on.
        foreach(spawn_point in maps\mp\gametypes_zm\_zm_gametype::get_player_spawns_for_gametype())
        {
            foreach(s_spawn in getstructarray(spawn_point.target, "targetname"))
            {
                dist = distance2dsquared(self.origin, s_spawn.origin);
                if(dist < best_dist)
                {
                    best = s_spawn;
                    best_dist = dist;
                }
            }
        }
        self.practice_last_afterlife_spawn = best;
    }
}

// Menu action: saves the spot of the player's last afterlife spawn as the mantle
// spawn.
mob_set_mantle_spawn()
{
    s_spawn = self.practice_last_afterlife_spawn;
    if(!isdefined(s_spawn))
    {
        self iprintln("No afterlife spawn yet");
        return;
    }
    level.base_cfg["mantle_spawn_x"] = int(s_spawn.origin[0]);
    level.base_cfg["mantle_spawn_y"] = int(s_spawn.origin[1]);
    level.base_cfg["mantle_spawn_z"] = int(s_spawn.origin[2]);
    self cfg_set_int("mantle_spawn_set", 1);
    self iprintln("Best roof spawn saved: " + int(s_spawn.origin[0]) + " " + int(s_spawn.origin[1]) + " " + int(s_spawn.origin[2]));
}

// The spawn struct nearest the plane and its group's spots.
mob_roof_spawn()
{
    best = undefined;
    best_dist = undefined;
    foreach(spawn_point in maps\mp\gametypes_zm\_zm_gametype::get_player_spawns_for_gametype())
    {
        spawns = getstructarray(spawn_point.target, "targetname");
        foreach(s_spawn in spawns)
        {
            dist = distancesquared(s_spawn.origin, ROOF_SPOT);
            if(isdefined(best_dist) && dist >= best_dist) continue;
            best_dist = dist;
            if(!isdefined(best)) best = spawnstruct();
            best.spot = s_spawn;
            best.spawns = spawns;
        }
    }
    return best;
}

// The saved spawn struct and its group's spots, else the one nearest the plane.
mob_mantle_spawn()
{
    if(!get_cfg_int("mantle_spawn_set")) return mob_roof_spawn();
    origin = (get_cfg_int("mantle_spawn_x"), get_cfg_int("mantle_spawn_y"), get_cfg_int("mantle_spawn_z"));
    foreach(spawn_point in maps\mp\gametypes_zm\_zm_gametype::get_player_spawns_for_gametype())
    {
        spawns = getstructarray(spawn_point.target, "targetname");
        foreach(s_spawn in spawns)
        {
            if(distancesquared(s_spawn.origin, origin) > 4) continue;
            mantle = spawnstruct();
            mantle.spot = s_spawn;
            mantle.spawns = spawns;
            return mantle;
        }
    }
    return mob_roof_spawn();
}

// Keeps the mantle spot claimed for the host while the setting is on, and no
// other spot in its group (vanilla returns the first claimed one it finds).
mob_force_mantle_spawn()
{
    level endon("end_game");
    flag_wait("initial_blackscreen_passed");
    while(true)
    {
        player = get_players()[0];
        if(isdefined(player) && get_cfg_int("force_mantle_spawn"))
        {
            mantle = mob_mantle_spawn();
            if(isdefined(mantle))
            {
                num = player getentitynumber();
                foreach(s_spawn in mantle.spawns)
                    if(s_spawn != mantle.spot && isdefined(s_spawn.plyr) && s_spawn.plyr == num)
                        s_spawn.plyr = undefined;
                mantle.spot.plyr = num;
            }
        }
        wait 0.25;
    }
}

mob_mantle_spawn_text()
{
    if(!get_cfg_int("mantle_spawn_set")) return "^3nearest plane";
    return "^3saved";
}

// Timescale 10 from boarding until a zombie is on the map after the crash, when the
// setting is on (user, 2026-11-06). The cap is for a crash with none left to spawn.
mob_plane_timescale()
{
    level endon("end_game");
    while(true)
    {
        flag_wait("plane_boarded");
        if(get_cfg_int("plane_timescale"))
            setdvar("timescale", SETUP_TIMESCALE);
        flag_wait("plane_crashed");
        for(i = 0; i < 1200 && !get_current_zombie_count(); i++) wait 0.05;
        setdvar("timescale", 1);
        wait 60;
    }
}

// The dryer's 33 s cycle, once it starts.
mob_countdown_dryer()
{
    hud = mob_countdown_hud(145, &"dryer ^3");
    while(level getclientfield("dryer_stage") < 2)
        wait 0.05;
    if(get_cfg_int("hud_autoscroll") && !is_true(level.practice_hide_dryer_timer))
    {
        hud.alpha = 0.8;
        hud settimer(33);
        wait 33;
    }
    hud destroy();
}

// The bridge's 60 s, each time a player lands on it.
mob_countdown_bridge()
{
    level endon("end_game");
    hud = mob_countdown_hud(160, &"bridge ^3");
    while(true)
    {
        while(!maps\mp\zm_alcatraz_sq_vo::get_players_touching("zone_golden_gate_bridge"))
            wait 0.05;
        wait 0.4;
        if(get_cfg_int("hud_autoscroll"))
        {
            hud.alpha = 0.8;
            hud settimer(60);
        }
        wait 60;
        hud.alpha = 0;
        while(maps\mp\zm_alcatraz_sq_vo::get_players_touching("zone_golden_gate_bridge"))
            wait 0.05;
    }
}

mob_countdown_hud(y, label)
{
    hud = newhudelem();
    hud.alignx = "center";
    hud.aligny = "bottom";
    hud.horzalign = "center";
    hud.vertalign = "top";
    hud.y = y;
    hud.fontscale = 1.4;
    hud.alpha = 0;
    hud.hidewheninmenu = 1;
    hud.label = label;
    return hud;
}

/*##############################################################################
                              Overrides
##############################################################################*/
// Starts the dryer and, for the setup cheats, finishes its cycle at once
// (mob_dryer_trigger_thread). Call after "laundry_power_switch_afterlife":
// vanilla setup_dryer_challenge then reads the trigger's origin 1 s later, and a
// skipped cycle deletes the trigger, so this waits that second out first.
mob_run_dryer_skipped()
{
    wait 1.1;
    level.practice_skip_dryer = true;
    level.practice_hide_dryer_timer = true;
    t_dryer = getent("dryer_trigger", "targetname");
    if(isdefined(t_dryer)) t_dryer notify("trigger");
}

// OVERRIDE: maps\mp\zm_alcatraz_sq::dryer_trigger_thread
mob_dryer_trigger_thread()
{
    self endon( "death" );
    n_dryer_cycle_duration = 30;
    a_dryer_spawns = [];
    sndent = spawn( "script_origin", ( 1613, 10599, 1203 ) );
    self waittill( "trigger" );
    b_skip = is_true( level.practice_skip_dryer ); //MODIFIED: Open Doors and plane setups skip the cycle.
    self trigger_off();
    level setclientfield( "dryer_stage", 2 );
    dryer_playerclip = getent( "dryer_playerclip", "targetname" );
    dryer_playerclip moveto( dryer_playerclip.origin + vectorscale( ( 0, 0, 1 ), 104.0 ), 0.05 );
    level clientnotify( "sndFF" );

    if ( !( isdefined( level.music_override ) && level.music_override ) )
    {
        level notify( "sndStopBrutusLoop" );
        level thread maps\mp\zombies\_zm_audio::sndmusicstingerevent( "laundry_defend" );
    }

    exploder( 1000 );
    if ( !b_skip ) //MODIFIED: no countdown beeps when skipped.
    sndent thread maps\mp\zm_alcatraz_sq::snddryercountdown( n_dryer_cycle_duration );
    sndent playsound( "evt_dryer_start" );
    sndent playloopsound( "evt_dryer_lp" );
    level clientnotify( "fxanim_dryer_start" );
    //MODIFIED: dryer_zombies_thread raises zombie_total to 20 in solo when the
    // cycle starts; a skipped cycle keeps the round's count.
    n_zombie_total = level.zombie_total;
    //MODIFIED END
    flag_set( "dryer_cycle_active" );
    //MODIFIED: skipped, the cycle ends in the same frame (no waits).
    if ( b_skip )
    {
        waittillframeend;
        level.zombie_total = n_zombie_total;
        sndset = maps\mp\zm_alcatraz_sq::sndmusicvariable();
        level clientnotify( "fxanim_dryer_idle_start" );
        level clientnotify( "fxanim_dryer_end_start" );
    }
    else
    {
    //MODIFIED END
    wait 1;
    sndset = maps\mp\zm_alcatraz_sq::sndmusicvariable();
    level clientnotify( "fxanim_dryer_idle_start" );

    for ( i = 3; i > 0; i-- )
    {
        wait( n_dryer_cycle_duration / 3 );
    }

    level clientnotify( "fxanim_dryer_end_start" );
    wait 2;
    } //MODIFIED
    flag_clear( "dryer_cycle_active" );
    dryer_playerclip = getent( "dryer_playerclip", "targetname" );
    dryer_playerclip delete();
    sndent stoploopsound();
    sndent playsound( "evt_dryer_stop" );

    if ( isdefined( sndset ) && sndset )
        level.music_override = 0;

    level clientnotify( "sndFF" );
    level setclientfield( "dryer_stage", 3 );
    stop_exploder( 900 );
    stop_exploder( 1000 );
    m_sheets = maps\mp\zombies\_zm_craftables::get_craftable_piece_model( "plane", "cloth" );
    m_sheets.origin = ( 1586.16, 10598.3, 1192 );
    m_sheets setvisibletoall();
    m_sheets ghost();
    self delete();
    sndent thread maps\mp\zm_alcatraz_sq::delaysndenddelete();
}

// OVERRIDE: maps\mp\zombies\_zm_afterlife::afterlife_remove
mob_afterlife_remove( b_afterlife_death )
{
    if ( !isdefined( b_afterlife_death ) )
        b_afterlife_death = 0;

    //MODIFIED: Infinite afterlives keeps the count.
    if ( !get_cfg_int( "infinite_afterlives" ) )
    {
    //MODIFIED END
    if ( isdefined( b_afterlife_death ) && b_afterlife_death )
        self.lives = 0;
    else if ( self.lives > 0 )
        self.lives--;
    } //MODIFIED

    self notify( "sndLifeGone" );
    self setclientfieldtoplayer( "player_lives", self.lives );
}

// OVERRIDE: maps\mp\zombies\_zm_weap_tomahawk::tomahawk_return_player
mob_tomahawk_return_player( m_tomahawk, num_zombie_hit )
{
    self endon( "disconnect" );
    n_dist = distance2dsquared( m_tomahawk.origin, self.origin );

    if ( !isdefined( num_zombie_hit ) )
        num_zombie_hit = 5;

    while ( n_dist > 4096 )
    {
        m_tomahawk moveto( self geteye(), 0.25 );

        if ( num_zombie_hit < 5 )
        {
            self maps\mp\zombies\_zm_weap_tomahawk::tomahawk_check_for_zombie( m_tomahawk );
            num_zombie_hit++;
        }

        wait 0.1;
        n_dist = distance2dsquared( m_tomahawk.origin, self geteye() );
    }

    if ( isdefined( m_tomahawk.a_has_powerup ) )
    {
        foreach ( powerup in m_tomahawk.a_has_powerup )
        {
            if ( isdefined( powerup ) )
                powerup.origin = self.origin;
        }
    }

    m_tomahawk delete();
    self playsoundtoplayer( "wpn_tomahawk_catch_plr", self );
    self playsound( "wpn_tomahawk_catch_npc" );
    if ( !get_cfg_int( "no_tomahawk_cooldown" ) ) //MODIFIED: Zero cooldown skips the wait.
    wait 5;
    self playsoundtoplayer( "wpn_tomahawk_cooldown_done", self );
    self givemaxammo( self.current_tomahawk_weapon );
    a_zombies = getaispeciesarray( "axis", "all" );

    foreach ( ai_zombie in a_zombies )
        ai_zombie.hit_by_tomahawk = 0;

    self setclientfieldtoplayer( "tomahawk_in_use", 3 );
}

// OVERRIDE: maps\mp\zm_prison_sq_bg::tomahawk_the_macguffin
mob_tomahawk_the_macguffin( grenade, n_grenade_charge_power )
{
    if ( !isdefined( level.sq_bg_macguffins ) || level.sq_bg_macguffins.size <= 0 )
        return false;

    foreach ( macguffin in level.sq_bg_macguffins )
    {
        if ( distancesquared( macguffin.origin, grenade.origin ) < 10000 )
        {
            m_tomahawk = maps\mp\zombies\_zm_weap_tomahawk::tomahawk_spawn( grenade.origin );
            m_tomahawk.n_grenade_charge_power = n_grenade_charge_power;
            macguffin notify( "caught_by_tomahawk" );
            v_home = macguffin.origin; //MODIFIED: Respawning skulls go back here.
            macguffin.origin = grenade.origin;
            macguffin linkto( m_tomahawk );
            macguffin thread maps\mp\zombies\_zm_afterlife::disable_afterlife_prop();
            self thread maps\mp\zombies\_zm_weap_tomahawk::tomahawk_return_player( m_tomahawk );
            self thread mob_give_player_macguffin_upon_receipt( m_tomahawk, macguffin, v_home ); //MODIFIED: passes v_home
            return true;
        }
    }

    return false;
}

// OVERRIDE: maps\mp\zm_prison_sq_bg::give_player_macguffin_upon_receipt
mob_give_player_macguffin_upon_receipt( m_tomahawk, m_macguffin, v_home )
{
    self endon( "disconnect" );

    while ( isdefined( m_tomahawk ) )
        wait 0.05;

    //MODIFIED: With respawning skulls, the first catch counts as vanilla's and
    // the skull goes back to its spot to be caught again.
    if ( get_cfg_int( "respawning_skull" ) && isdefined( v_home ) )
    {
        if ( !is_true( m_macguffin.practice_collected ) )
        {
            m_macguffin.practice_collected = true;
            m_macguffin notify( "sq_bg_macguffin_received_by_player" );
            level notify( "sq_bg_macguffin_collected", self );
        }
        m_macguffin unlink();
        m_macguffin.origin = v_home;
        play_sound_at_pos( "purchase", self.origin );
        return;
    }
    if ( is_true( m_macguffin.practice_collected ) )
    {
        // Counted on an earlier catch while skulls respawned.
        arrayremovevalue( level.sq_bg_macguffins, m_macguffin );
        m_macguffin delete();
        play_sound_at_pos( "purchase", self.origin );
        return;
    }
    //MODIFIED END

    m_macguffin notify( "sq_bg_macguffin_received_by_player" );
    arrayremovevalue( level.sq_bg_macguffins, m_macguffin );
    m_macguffin delete();
    play_sound_at_pos( "purchase", self.origin );
    level notify( "sq_bg_macguffin_collected", self );
}

// OVERRIDE: maps\mp\zm_alcatraz_distance_tracking::zombie_tracking_init
mob_zombie_tracking_init()
{
    level.zombie_respawned_health = [];

    if ( !isdefined( level.zombie_tracking_dist ) )
        level.zombie_tracking_dist = 1500;

    if ( !isdefined( level.zombie_tracking_high ) )
        level.zombie_tracking_high = 600;

    if ( !isdefined( level.zombie_tracking_wait ) )
        level.zombie_tracking_wait = 10;

    //MODIFIED: plane starts: real-run timing from the Plane Time clock (core
    // practice_check_phasing); every other mode is vanilla
    aligned = true;
    if(isdefined(level.practice_phasing))
    {
        practice_checks_hold();
        aligned = false;
    }
    //MODIFIED END

    while ( true )
    {
        level.practice_despawned = 0; //MODIFIED: Despawn printer count for this check.
        zombies = get_round_enemy_array();

        if ( !isdefined( zombies ) || isdefined( level.ignore_distance_tracking ) && level.ignore_distance_tracking )
        {
            aligned = practice_despawn_wait(aligned); //MODIFIED: real-run timing in plane starts (core)
            continue;
        }
        else
        {
            level thread mob_print_despawns(); //MODIFIED: Despawn printer.

            for ( i = 0; i < zombies.size; i++ )
            {
                if ( isdefined( zombies[i] ) && !( isdefined( zombies[i].ignore_distance_tracking ) && zombies[i].ignore_distance_tracking ) )
                    zombies[i] thread maps\mp\zm_alcatraz_distance_tracking::delete_zombie_noone_looking( level.zombie_tracking_dist, level.zombie_tracking_high );
            }
        }

        aligned = practice_despawn_wait(aligned); //MODIFIED: real-run timing in plane starts (core)
    }
}

// Each distance check: the game time and how many zombies it deleted. The
// checks finish 0.1 s after they start.
mob_print_despawns()
{
    wait 0.15;
    if(!get_cfg_int("hud_despawns")) return;
    color = "^7";
    if(level.practice_despawned > 0) color = "^3";
    foreach(player in get_players())
        player iprintln("Distance tracking " + game_time_string(0) + " | " + color + level.practice_despawned + "^7 zombies deleted");
}

// OVERRIDE: maps\mp\zm_alcatraz_distance_tracking::delete_zombie_noone_looking
mob_delete_zombie_noone_looking( how_close, how_high )
{
    self endon( "death" );

    if ( !isdefined( how_close ) )
        how_close = 1500;

    if ( !isdefined( how_high ) )
        how_close = 600;

    distance_squared_check = how_close * how_close;
    too_far_dist = distance_squared_check * 3;

    if ( isdefined( level.zombie_tracking_too_far_dist ) )
        too_far_dist = level.zombie_tracking_too_far_dist * level.zombie_tracking_too_far_dist;

    self.inview = 0;
    self.player_close = 0;
    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        if ( players[i].sessionstate == "spectator" )
            continue;

        if ( isdefined( level.only_track_targeted_players ) )
        {
            if ( !isdefined( self.favoriteenemy ) || self.favoriteenemy != players[i] )
                continue;
        }

        can_be_seen = self maps\mp\zm_alcatraz_distance_tracking::player_can_see_me( players[i] );

        if ( can_be_seen && distancesquared( self.origin, players[i].origin ) < too_far_dist )
            self.inview++;

        if ( distancesquared( self.origin, players[i].origin ) < distance_squared_check && abs( self.origin[2] - players[i].origin[2] ) < how_high )
            self.player_close++;
    }

    wait 0.1;

    if ( self.inview == 0 && self.player_close == 0 )
    {
        if ( !isdefined( self.animname ) || isdefined( self.animname ) && self.animname != "zombie" )
            return;

        if ( isdefined( self.electrified ) && self.electrified == 1 )
            return;

        if ( isdefined( self.in_the_ground ) && self.in_the_ground == 1 )
            return;

        zombies = getaiarray( "axis" );

        if ( ( !isdefined( self.damagemod ) || self.damagemod == "MOD_UNKNOWN" ) && self.health < self.maxhealth )
        {
            if ( !( isdefined( self.exclude_distance_cleanup_adding_to_total ) && self.exclude_distance_cleanup_adding_to_total ) && !( isdefined( self.isscreecher ) && self.isscreecher ) )
            {
                level.zombie_total++;
                level.zombie_respawned_health[level.zombie_respawned_health.size] = self.health;
            }
        }
        else if ( zombies.size + level.zombie_total > 24 || zombies.size + level.zombie_total <= 24 && self.health >= self.maxhealth )
        {
            if ( !( isdefined( self.exclude_distance_cleanup_adding_to_total ) && self.exclude_distance_cleanup_adding_to_total ) && !( isdefined( self.isscreecher ) && self.isscreecher ) )
            {
                level.zombie_total++;

                if ( self.health < level.zombie_health )
                    level.zombie_respawned_health[level.zombie_respawned_health.size] = self.health;
            }
        }

        if ( isdefined( level.practice_despawned ) ) level.practice_despawned++; //MODIFIED: Despawn printer.
        self maps\mp\zombies\_zm_spawner::reset_attack_spot();
        self notify( "zombie_delete" );
        self delete();
        recalc_zombie_array();
    }
}
