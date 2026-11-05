#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\segmentutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Origins map hooks
##############################################################################*/
// Everything Origins adds to the core menus and HUD (see practice_map in
// utility_core\basegame.gsc). Settings are saved in O_PRAC/ since 2026-10-25;
// older builds keep theirs in OPRAC/, so either can be installed. The keys and
// mode dvar are the ones O-Practice always used.
shared_practice_map()
{
    map = practice_map("Huth's O-Prac", "Huth's Origins Practice Tool", "O_PRAC/", "o_menu_gamemode");
    // Run splits in SPLIT_* order (oprac.gsh); Freedom, the last, always shows.
    map.split_names = array("nml", "ice", "wind", "fire", "lightning", "freedom");
    map.split_labels = array("NML", "Ice", "Wind", "Fire", "Lightning", "Freedom");
    map.build_hud_top = ::shared_build_hud;
    map.build_cheats = ::shared_build_cheats;
    map.base_cfg_defaults = ::shared_base_cfg_defaults;
    map.say_command = ::shared_say_command;
    map.say_help = "^7, ^3blood^7, ^3parts";
    map.menu_icon = "faction_tomb";
    map.live_cfg_keys = array("cycle_tracker", "cycle_tracker_ms");
    map.set_start_time = ::shared_set_start_time;
    map.open_doors_extra = ::shared_open_tank_zones;
    map.hud_left_shift = ::shared_tablet_shift;
    map.oopa_hud_spot = ::shared_r2l_hud_spot;
    map.oopa_hud_spot_label = "R2L";
    return map;
}

// The menu runs on classic Origins only. zm_tomb has no other game mode; the
// check keeps every map's entry the same shape.
shared_map_active()
{
    return is_classic();
}

// OOPA Countdown spot (core basegame_oopa_hud_monitor): the R2L trick, until
// trig_zone_bunker_6 fires (vanilla sets activate_zone_bunker_6_tank, then
// deletes the trigger). In zone_bunker_6, or out of bounds in zone_bunker_tank_b.
shared_r2l_hud_spot()
{
    if(flag("activate_zone_bunker_6_tank")) return false;
    zone = self get_current_zone();
    if(!isdefined(zone)) return false;
    switch(zone)
    {
        case "zone_bunker_6":
            return true;
        case "zone_bunker_tank_b":
            return self basegame_out_of_playable_area();
        default:
            return false;
    }
}

shared_build_hud(hud)
{
	if(isdefined(level.segment) && is_true(level.segment.panzer_health_hud)) add_cfg_toggle(hud, "Panzer Health HUD", "hud");
	if(mode_has_robot_cycles())
	{
		create_option(hud, "Cycle Display: " + cfgint_compare("cycle_tracker"), ::shared_toggle_cycle_display);
		add_cfg_toggle(hud, "Cycle Display ms", "cycle_tracker_ms");
	}
}

shared_build_cheats(cheats)
{
	create_option(cheats, "Give Parts", ::get_all_parts);
	gems = add_submenu(cheats, "gems", "Give Gems");
		create_option(gems, "Fire", ::give_gem, FIRE);
		create_option(gems, "Wind", ::give_gem, WIND);
		create_option(gems, "Lightning", ::give_gem, LIGHTNING);
		create_option(gems, "Ice", ::give_gem, ICE);
}

shared_base_cfg_defaults(settings_ar)
{
    settings_ar["hud_oopa"] = 2; // OOPA Countdown: R2L only by default (user, 2026-10-26).
    return settings_ar;
}

shared_say_command(message)
{
    switch(message)
    {
        case "blood":
            self give_drop("zombie_blood");
            break;
        case "parts":
            self thread get_all_parts();
            break;
    }
}

// Tank-path zones open from map triggers, not doors: vanilla activate_zone_trig
// sets the zone flag and deletes the trigger once it fires (trig_zone_bunker_6
// also opens zone_bunker_1's tank flag).
shared_open_tank_zones()
{
    foreach ( name in array( "trig_zone_bunker_2", "trig_zone_bunker_4", "trig_zone_bunker_6" ) )
    {
        trig = getent( name, "targetname" );
        if ( isdefined( trig ) )
            trig notify( "trigger", self );
    }
}

// The slot left of the HP shows the G-Strike tablet while it is carried
// (vanilla zm_tomb_ee_side: stage 1 muddy, stage 4 clean).
shared_carrying_tablet()
{
    stage = self.sq_one_inch_punch_stage;
    return isdefined(stage) && (stage == 1 || stage == 4);
}

// Left-side HUD (zone, HP and regen) uses the tablet icon's space while no
// tablet is carried.
shared_tablet_shift()
{
    if(self shared_carrying_tablet()) return 0;
    return -24;
}

/*##############################################################################
                              Origins cheats
##############################################################################*/
get_all_parts()
{
    players = get_players();
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "upper_staff");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "middle_staff");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "lower_staff");

    players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_water", "upper_staff");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_water", "middle_staff");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_water", "lower_staff");

    players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_fire", "upper_staff");
    players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_fire", "middle_staff");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_fire", "lower_staff");

	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_lightning", "upper_staff");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_lightning", "middle_staff");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_lightning", "lower_staff");

	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("gramophone", "vinyl_player");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("gramophone", "vinyl_master");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("gramophone", "vinyl_air");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("gramophone", "vinyl_ice");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("gramophone", "vinyl_fire");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("gramophone", "vinyl_elec");

	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("equip_dieseldrone_zm", "body");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("equip_dieseldrone_zm", "engine");
    players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("equip_dieseldrone_zm", "brain");

	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("tomb_shield_zm", "top");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("tomb_shield_zm", "door");
	players[0] maps\mp\zombies\_zm_craftables::player_get_craftable_piece("tomb_shield_zm", "bracket");
}

// Cheat: puts the staff's gem (crystal) in the player's hands, as picking it up
// would. A player carries one gem at a time; taking one drops the held one.
give_gem(staff_id)
{
    switch(staff_id)
    {
        case FIRE:      staff = "fire";      break;
        case WIND:      staff = "air";       break;
        case LIGHTNING: staff = "lightning"; break;
        default:        staff = "water";     break;
    }
    piece = maps\mp\zombies\_zm_craftables::get_craftable_piece("elemental_staff_" + staff, "gem");
    if(!isdefined(piece) || is_true(piece.crafted))
    {
        self iprintln("That staff is already crafted");
        return;
    }
    if(isdefined(self.current_craftable_piece) && self.current_craftable_piece == piece) return;
    self maps\mp\zombies\_zm_craftables::player_take_piece(piece);
}

// Modes that replace the vanilla robot_cycling with shared_robot_cycling.
mode_has_robot_cycles()
{
    // Every segment start (shared_segment_install sets level.segment) installs it.
    return level.gamemode == "fullgame" || isdefined(level.segment);
}

/*##############################################################################
                              Menus shared by several segment modes
##############################################################################*/
// The root categories of every Origins mode with something to put in them. A
// category left empty is hidden, so a mode just fills the ones it needs.
shared_build_categories(root)
{
	add_submenu(root, "loadout", "Loadout & Items", "Loadout");
	add_submenu(root, "puzzles", "Puzzles & Map State", "Puzzles");
	add_submenu(root, "special_ai", "Special AI");
}

// Mound disc presets, the start's disc rows, then one submenu per scramble still
// ahead in this mode.
shared_build_disc_menu(parent, show_disc_turn = false, show_skip_first = false)
{
	// A shortcut start overwrites its scramble's dials, all but the first with Skip
	// First Disc, so that scramble has no page unless Skip First Disc leaves it one.
	first_scramble = shared_first_scramble();
	if(isdefined(level.segment) && isdefined(level.segment.disc_shortcut_gem) && !get_cfg_int("skip_first_disc")) first_scramble++;

	discs = add_submenu(parent, "discs", "Mound Discs", "Discs");
		if(first_scramble <= 4)
		{
			create_option(discs, "Optimal", ::shared_perfect_discs);
			create_option(discs, "Worst", ::shared_worst_discs);
			create_option(discs, "All Random", ::shared_random_discs);
		}
		if(show_disc_turn) shared_add_disc_turn_choice(discs);
		if(show_skip_first) add_cfg_toggle(discs, "Skip First Disc", "skip_first_disc");

	numerals = array("I", "II", "III", "IV");
	labels = array("Top: ", "2nd: ", "3rd: ", "Bot: ");
	for(scramble = first_scramble; scramble <= 4; scramble++)
	{
		numeral = numerals[scramble - 1];
		submenu = add_submenu(discs, "scramb_" + scramble, "Scramble " + numeral + " " + shared_scramble_text_line(scramble), "Scramble " + numeral);
			for(row = 0; row < 4; row++)
			{
				digit = 3 - row;
				create_option(submenu, labels[row] + shared_scramble_text(digit, scramble), ::shared_flip_scramble, digit, scramble);
			}
			create_option(submenu, "Random", ::shared_reset_scramble, scramble);
	}
}

// Absolute scramble IDs match disc_N configuration keys and native orb progress.
shared_first_scramble()
{
    if(isdefined(level.segment)) return level.segment.first_scramble;
    return 1;
}

// The first Templars attack still ahead of a start, 1 to 3: the ones behind it have
// no rows. A held start works this out once, so its rows stay put when the setup or
// a live attack moves the schedule.
shared_templars_first_set()
{
	if(!isdefined(level.templar_schedule)) return 1;
	schedule = level.templar_schedule;
	if(!isdefined(level.segment) || !isdefined(level.segment.round))
	{
		if(schedule.count > 1) return 3;
		return schedule.count + 1;
	}
	if(!isdefined(level.shared_templars_first_set))
	{
		segment = level.segment;
		first_live_round = segment.round;
		if(isdefined(segment.round_zombies) || isdefined(segment.round_kills) || isdefined(segment.round_zombies_keys)) first_live_round++;
		behind = schedule.count;
		next_round = schedule.next_round;
		while(behind < 2 && next_round < first_live_round)
		{
			next_round += schedule.gaps[behind];
			behind++;
		}
		if(behind > 2) behind = 2;
		level.shared_templars_first_set = behind + 1;
	}
	return level.shared_templars_first_set;
}

shared_build_templar_menu(parent)
{
	numerals = array("I", "II", "III");
	for(set = shared_templars_first_set(); set <= 3; set++)
	{
		gens = add_submenu(parent, "templars_" + set, "Templars " + numerals[set - 1], "Temps " + numerals[set - 1]);
			for(gen = 1; gen <= 6; gen++)
				add_cfg_toggle(gens, "Gen " + gen, "temps_" + set + "_gen_" + gen);
			// Rounds after the attack before it. Templars I has none.
			if(set > 1) create_option(gens, "Gap: ^3" + shared_templar_round_text(set), ::shared_toggle_templar_round, set);
	}
}

// Where each Maxis drone and shield part spawns.
shared_build_parts_menu(parent)
{
	parts = add_submenu(parent, "parts", "Part Locations", "Parts");
		self shared_add_part_choice(parts, "maxis_body");
		self shared_add_part_choice(parts, "maxis_engine");
		create_option(parts, "Maxis Brain", ::shared_maxis_brain);
		self shared_add_part_choice(parts, "shield_gen2");
		self shared_add_part_choice(parts, "shield_gen3");
		self shared_add_part_choice(parts, "shield_nml");
		create_option(parts, "All random", ::shared_reset_locations, shared_part_keys());
}

// Where each gramophone vinyl spawns.
shared_build_vinyls_menu(parent)
{
	vinyls = add_submenu(parent, "vinyls", "Vinyl Locations", "Vinyls");
		foreach(key in shared_vinyl_keys())
			self shared_add_part_choice(vinyls, key);
		create_option(vinyls, "All random", ::shared_reset_locations, shared_vinyl_keys());
}

// Steps random, each spot, collected.
shared_add_part_choice(menu, key)
{
	part = shared_part(key);
	if(shared_item_required(key))
	{
		create_option(menu, part.label + ": ^2collected ^7(route)", ::shared_item_fixed);
		return;
	}
	if(shared_drone_crafted() && part.craftable == "equip_dieseldrone_zm")
	{
		create_option(menu, part.label + ": ^2in drone", ::shared_part_in_drone);
		return;
	}
	create_option(menu, part.label + ": ^3" + shared_part_location_text(part, get_cfg_int(key)), ::cfg_increment_int, key, array(PART_RANDOM, shared_part_collected_value(key)));
}

shared_item_fixed()
{
	self iprintln("This start always has it collected");
}

shared_part_in_drone()
{
	self iprintln("Maxis Drone is crafted (Loadout & Items)");
}

shared_maxis_brain()
{
	self iprintln("You have no brain?");
}

shared_reset_locations(keys)
{
	foreach(key in keys)
		level.mode_cfg[key] = PART_RANDOM;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

// Returns the menu so a mode can add its own rows below the shared ones. The AFD (Ascend from Darkness)
// delay is in every mode with the Panzer menu (user, 2026-11-02).
shared_build_panzer_menu(parent)
{
	panzer = add_submenu(parent, "panzer", "Panzer");
		create_option(panzer, "Panzer 2: ^3" + cfgint_compare("panzer_2", get_cfg_int("panzer_2") + " rounder", "random"), ::shared_cycle_panzer, 2);
		create_option(panzer, "Panzer 3: ^3" + cfgint_compare("panzer_3", get_cfg_int("panzer_3") + " rounder", "random"), ::shared_cycle_panzer, 3);
		create_option(panzer, "AFD Delay: ^3" + shared_mechz_delay_text(), ::shared_mechz_delay_step);
	return panzer;
}

/*##############################################################################
                              Panzer AFD (Ascend from Darkness) delay
##############################################################################*/
// The EE mech fight (step 4) spawns 8 Panzers, at most 4 alive, waiting 0.5 to
// 1 s between spawns. mechz_delay "0" keeps it random, "0.5" or "1" fixes it.
// Installed by Full Game and every segment start (shared_segment_install).
shared_mechz_delay_install()
{
	replacefunc( maps\mp\zm_tomb_ee_main_step_4::stage_logic, ::shared_mechz_stage_logic);
}

shared_mechz_delay_text()
{
	switch("" + get_cfg_float("mechz_delay"))
	{
		case "0.5": return "0.5s";
		case "1": return "1s";
		default: return "random";
	}
}

shared_mechz_delay_step()
{
	switch("" + get_cfg_float("mechz_delay"))
	{
		case "0.5": level.mode_cfg["mechz_delay"] = "1"; break;
		case "1": level.mode_cfg["mechz_delay"] = "0"; break;
		default: level.mode_cfg["mechz_delay"] = "0.5"; break;
	}
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

// Vanilla zm_tomb_ee_main_step_4 stage_logic with the spawn delay setting.
shared_mechz_stage_logic()
{
/#
    iprintln( level._cur_stage_name + " of little girl lost started" );
#/
    flag_wait( "ee_quadrotor_disabled" );
    level thread maps\mp\zm_tomb_ee_main_step_4::sndee4music();

    if ( !flag( "ee_mech_zombie_fight_completed" ) )
    {
        while ( level.ee_mech_zombies_spawned < 8 )
        {
            if ( level.ee_mech_zombies_alive < 4 )
            {
                ai = spawn_zombie( level.mechz_spawners[0] );
                ai thread maps\mp\zm_tomb_ee_main_step_4::ee_mechz_spawn( level.ee_mech_zombies_spawned % 4 );
                level.ee_mech_zombies_alive++;
                level.ee_mech_zombies_spawned++;
            }

            //MODIFIED: the AFD delay setting, vanilla random when 0.
            val = get_cfg_float("mechz_delay");
            if(!val) wait( randomfloatrange( 0.5, 1 ) );
            else wait val;
        }
    }

    flag_wait( "ee_mech_zombie_fight_completed" );
    wait_network_frame();
    maps\mp\zombies\_zm_sidequests::stage_completed( "little_girl_lost", level._cur_stage_name );
}

// all_random_cycles is the "All random" action for Robot Cycles; Full Game's
// also randomizes Rain fire, the segment starts' keeps it. Cycles before
// first_cycle cannot happen in the mode and get no rows.
shared_build_robot_menus(parent, all_random_cycles, first_cycle = 1, show_rain_robot = true)
{
	cycles = add_submenu(parent, "cycles", "Robot Cycles", "Cycles");
		if(show_rain_robot) create_option(cycles, "Rain Fire: ^3" + level.robot[get_cfg_int("rain_robot")], ::cfg_increment_int, "rain_robot", array(ROBOT_RANDOM, ROBOT_FREYA));
		for(cycle = first_cycle; cycle <= ROBOT_CYCLE_COUNT; cycle++)
			create_option(cycles, "Cycle " + cycle + ": ^3" + level.robot[get_cfg_int("cycle_" + cycle)], ::cfg_increment_int, "cycle_" + cycle, array(ROBOT_RANDOM, ROBOT_FREYA));
		create_option(cycles, "All random", all_random_cycles);

	feet = add_submenu(parent, "feet", "Robot Feet", "Feet");
		create_option(feet, "Rain Foot: ^3" + rain_foot_text(), ::cfg_increment_int, "rain_foot", array(FOOT_RANDOM, FOOT_RIGHT));
		for(cycle = first_cycle; cycle <= ROBOT_CYCLE_COUNT; cycle++)
			create_option(feet, "Cycle " + cycle + ": ^3" + level.foot[get_cfg_int("foot_" + cycle)], ::cfg_increment_int, "foot_" + cycle, array(FOOT_RANDOM, FOOT_RIGHT));
		create_option(feet, "All random", ::shared_all_random_feet);
}

rain_foot_text()
{
    foot = get_cfg_int("rain_foot");
    if(foot == 0 || foot == 1) return level.foot[foot];
    return level.foot[-1]; // Legacy 2 and other fallback values behave as Random.
}

shared_random_discs()
{
	if(shared_first_scramble() <= 1) level.mode_cfg["disc_1"] = 0;
	if(shared_first_scramble() <= 2) level.mode_cfg["disc_2"] = 0;
	if(shared_first_scramble() <= 3) level.mode_cfg["disc_3"] = 0;
	if(shared_first_scramble() <= 4) level.mode_cfg["disc_4"] = 0;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

shared_perfect_discs()
{
	if(shared_first_scramble() <= 1) level.mode_cfg["disc_1"] = 2222;
	if(shared_first_scramble() <= 2) level.mode_cfg["disc_2"] = 1222;
	if(shared_first_scramble() <= 3) level.mode_cfg["disc_3"] = 2112;
	if(shared_first_scramble() <= 4) level.mode_cfg["disc_4"] = 1121;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

shared_worst_discs()
{
	if(shared_first_scramble() <= 1) level.mode_cfg["disc_1"] = 2122;
	if(shared_first_scramble() <= 2) level.mode_cfg["disc_2"] = 1122;
	if(shared_first_scramble() <= 3) level.mode_cfg["disc_3"] = 1211;
	if(shared_first_scramble() <= 4) level.mode_cfg["disc_4"] = 2222;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

shared_all_random_feet()
{
	level.mode_cfg["rain_foot"] = FOOT_RANDOM;
	for(i = 1; i <= ROBOT_CYCLE_COUNT; i++)
		level.mode_cfg["foot_" + i] = FOOT_RANDOM;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

shared_cycle_panzer( num )
{
	setting = "panzer_" + num;
	switch(get_cfg_int(setting))
	{
		case 0: level.mode_cfg[setting] = 4; break;
		case 4: level.mode_cfg[setting] = 5; break;
        case 5:
		default: level.mode_cfg[setting] = 0; break;
	}
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

shared_toggle_templar_round(set)
{
	setting = "temps_" + set + "_round";
	templar_round = get_cfg_int(setting);
	switch(templar_round)
	{
		case 0: level.mode_cfg[setting] = 3; break;
		case 3: level.mode_cfg[setting] = 4; break;
		case 4: level.mode_cfg[setting] = 5; break;
		case 5:
		default: level.mode_cfg[setting] = 0; break;
	}
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

shared_templar_round_text(set)
{
	setting = "temps_" + set + "_round";
	val = get_cfg_int(setting);

	if(val) return val + " rounder";
	else 	return "random";
}

shared_reset_scramble( num )
{
	setting = "disc_" + num;
	level.mode_cfg[setting] = 0;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

shared_flip_scramble(index, num)
{
	setting = "disc_" + num;
	scramble = get_cfg_int(setting);
	if(!isDefined(scramble))
		scramble = 0;
	if(scramble < 1)
	{
		level.mode_cfg[setting] = 1111;
		write_config(level.mode_cfg, level.mode_cfg_str);
		self refresh_menu();
		return;
	}

	pow = pow( 10, (3 - index) );
	val = int(scramble / pow) % 10;

	if(val == 1)
		scramble = scramble + pow;
	else
		scramble = scramble - pow;

	level.mode_cfg[setting] = scramble;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

shared_scramble_text( index, num )
{
	setting = "disc_" + num;
	scramble = get_cfg_int(setting);
	if(scramble)
	{
		color = array("blue", "purple", "red", "yellow");
		colors = array("^4", "^6", "^1", "^3");
		decoded = [];
		prev_disc_pos = 0;
		for( i = 1; i < 5; i++)
		{
			turn = int(scramble / pow( 10, 4 - i )) % 10;
			decoded[i - 1] = (prev_disc_pos + turn) % 4;
			prev_disc_pos = decoded[i - 1];
		}
		return colors[decoded[index]] + "[" + "] " + color[decoded[index]];
	}
	else
	{
		return "^8[] random";
	}
}

shared_scramble_text_line( num )
{
	setting = "disc_" + num;
	scramble = get_cfg_int(setting);
	if(scramble)
	{
		inline = "^8]";
		color = array("B", "P", "R", "Y");
		colors = array("^4", "^6", "^1", "^3");
		decoded = [];
		prev_disc_pos = 0;
		for( i = 1; i < 5; i++)
		{
			turn = int(scramble / pow( 10, 4 - i )) % 10;
			prev_disc_pos = (prev_disc_pos + turn) % 4;
			inline = colors[prev_disc_pos] + color[prev_disc_pos] + inline;
		}
		inline = "^8[" + inline;
		return inline;
	}
	else
	{
		return "^8[random]";
	}
}
