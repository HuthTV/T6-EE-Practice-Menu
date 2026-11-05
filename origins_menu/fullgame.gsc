#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm_powerups;
#include maps\mp\zm_tomb_dig;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\segmentutil;
#include scripts\zm\origins_menu\puzzlerng;
#inline scripts\zm\origins_menu\oprac;

fullgame_initialize()
{
	replaceFunc(maps\mp\zm_tomb_giant_robot::robot_cycling, ::shared_robot_cycling);

	replacefunc( maps\mp\zombies\_zm_craftables::generate_zombie_craftable_piece, ::shared_generate_zombie_craftable_piece);
	replacefunc( maps\mp\zm_tomb_craftables::randomize_craftable_spawns, ::shared_randomize_craftable_spawns);

	replacefunc( maps\mp\zm_tomb_capture_zones::get_recapture_zone, ::fullgame_get_recapture_zone);
	replacefunc( maps\mp\zm_tomb_capture_zones::recapture_round_tracker, ::shared_recapture_round_tracker);
	replacefunc( maps\mp\zombies\_zm_ai_mechz_ffotd::mechz_round_tracker_loop_start, ::shared_mechz_round_tracker_loop_start);

	replacefunc( maps\mp\zm_tomb_dig::dig_spots_respawn, ::fullgame_dig_spots_respawn);
	replacefunc( maps\mp\zm_tomb_dig::waittill_dug, ::fullgame_waittill_dug);
	replacefunc( maps\mp\zm_tomb_dig::bonus_points_powerup_override, ::fullgame_bonus_points_powerup_override);

	replacefunc( maps\mp\zombies\_zm_perk_random::get_weighted_random_perk, ::fullgame_get_weighted_random_perk);
	replacefunc( maps\mp\zm_tomb_quest_crypt::chamber_discs_randomize, ::fullgame_chamber_discs_randomize);

	shared_mechz_delay_install();

	replacefunc( maps\mp\zombies\_zm_powerups::randomize_powerups, ::fullgame_randomize_powerups );
	replacefunc( maps\mp\zombies\_zm_powerups::powerup_drop, ::fullgame_powerup_drop );

	flag_init("fullgame_fist_of_iron_nuke_dropped");
	flag_clear("fullgame_fist_of_iron_nuke_dropped");

	level.cycle_string = "awaiting robot cycle";
	level.first_dig_list = array("random", "bonus_points_player", "nuke", "double_points", "zombie_blood", "ballista_zm", "c96_zm", "870mcs_zm", "dsr50_zm", "srm1216_zm");
	level.robot_cycle = 0;
	level.n_disc_scrambles = 0; // First mound opening selects disc_1; each orb step selects the next.

	puzzle_rng_install(PUZZLE_RNG_ICE);
	// Crazy Place visits of the route (user, 2026-11-02), Crazy Place Walls menu.
	level.puzzle_rng_visit_labels = puzzle_rng_route_visit_labels();
	mode_cfg_load("fullgame", fullgame_default_cfg());
	shared_schedules_init(10);
}

fullgame_default_cfg()
{
	settings_ar = [];
	settings_ar["turbo_restarts"] = 0;
	settings_ar["cycle_tracker"] = 1;
    settings_ar["split_nml"] = 0; // Timer menu; off starts the splits at Ice.
	settings_ar["cycle_tracker_ms"] = 0;

	settings_ar["fullgame_first_powerup"] = 0;
	settings_ar["fullgame_fist_of_iron_nuke"] = 0;

	settings_ar["fizz_location"] = 0;
	settings_ar["fizz_1"] = 0;
	settings_ar["fizz_2"] = 0;

	settings_ar["box_location"] = 0;
	settings_ar["box_tier"] = 0;
	settings_ar["box_hit_1"] = 0;
	settings_ar["box_hit_2"] = 0;
	settings_ar["box_no_stock_mp40"] = 0;

	settings_ar["bunker_dig"] = 0;
	settings_ar["nml_dig"] = 0;
	settings_ar["village_dig"] = 0;
	settings_ar["blood_dig"] = 1;

	settings_ar["1st_dig"] = 0;
	settings_ar["250_digs"] = 0;
	settings_ar["r4_snow"] = 0;
	settings_ar["r10_digs"] = 1;
	settings_ar["early_ice"] = 0;
	settings_ar["ending_digs"] = 1;

	settings_ar["disc_1"] = 0;
	settings_ar["disc_2"] = 0;
	settings_ar["disc_3"] = 0;
	settings_ar["disc_4"] = 0;

	settings_ar["mechz_delay"] = "0";

	settings_ar["rain_robot"] = ROBOT_ODIN;
	settings_ar["rain_foot"] = FOOT_RANDOM;

	// Every cycle random, then the presets for the first ones.
	for(cycle = 1; cycle <= ROBOT_CYCLE_COUNT; cycle++)
	{
		settings_ar["cycle_" + cycle] = ROBOT_RANDOM;
		settings_ar["foot_" + cycle] = FOOT_RANDOM;
	}
	settings_ar["cycle_1"] = ROBOT_THOR;
	settings_ar["cycle_2"] = ROBOT_THOR;
	settings_ar["cycle_3"] = ROBOT_ODIN;
	settings_ar["cycle_4"] = ROBOT_FREYA;
	settings_ar["foot_4"] = FOOT_LEFT;

	settings_ar = shared_part_defaults(settings_ar);
	settings_ar = shared_schedule_defaults(settings_ar);
	settings_ar = puzzle_rng_defaults(settings_ar);

	return settings_ar;
}

fullgame_run()
{
	if(get_cfg_int("turbo_restarts")) setDvar("timescale", 10);
	level thread fullgame_force_weather();

	fizz_loc = get_cfg_int("fizz_location");
	if(fizz_loc) level thread fullgame_fizz_start_location(fizz_loc);

	box_loc = get_cfg_int("box_location");
	if(box_loc) level thread fullgame_start_box_location(box_loc - 1);

	box_tier = get_cfg_int("box_tier");
	if(box_tier) level thread fullgame_box_patch(box_tier);
	else if(get_cfg_int("box_no_stock_mp40")) level thread fullgame_box_no_stock_mp40();
	level.fullgame_box_hits = 0;
	level.customrandomweaponweights = ::fullgame_box_hit_weights;

	flag_wait("initial_blackscreen_passed");
	if(get_cfg_int("turbo_restarts"))
	{
		// Normal speed for 500 ms before the player gets control (the run clock
		// starts with it).
		player = get_players()[0];
		player freezecontrols(1);
		setDvar("timescale", 1);
		wait 0.5;
		player freezecontrols(0);
	}
    level.game_start_time = gettime();
    level thread shared_segment_timer(int_compare(split_shown(SPLIT_NML), SPLIT_NML, SPLIT_ICE));
	setDvar("timescale", 1);
	flag_set("menu_active");

	// Not the route, but Part and Vinyl Locations offer "collected" in every mode.
	get_players()[0] shared_give_collected_items();
	if(get_cfg_int("cycle_tracker")) level thread shared_cycle_tracker();
}


//##############GAME FUNCTIONS####################

fullgame_force_weather()
{
	level waittill("start_of_round");
	if(get_cfg_int("early_ice")) level.force_weather[2] = "rain";
	level waittill("start_of_round");
	if(get_cfg_int("r4_snow")) level.force_weather[4] = "snow";
}


fullgame_fizz_start_location(loc)
{
	level waittill("initial_players_connected");
	wait 3;
	machines = getentarray("random_perk_machine", "targetname");
	index = loc + 1;
	level.random_perk_start_machine = machines[index];
	foreach(machine in machines)
	{
		if(machine != level.random_perk_start_machine)
		{
			machine hidepart("j_ball");
			machine.is_current_ball_location = 0;
			machine setclientfield("turn_on_location_indicator", 0);
			continue;
		}
		machine.is_current_ball_location = 1;
		level.wunderfizz_starting_machine = machine;
		level notify("wunderfizz_setup");
		machine thread maps\mp\zombies\_zm_perk_random::machine_think();
	}
}

fullgame_start_box_location( box_loc_val )
{
	level waittill("initial_players_connected");
	if(box_loc_val)
	{
		if(box_loc_val == 1)
		{
			start_chest = "bunker_tank_chest";
		}
		else
		{
			start_chest = "bunker_cp_chest";
		}
		for(i = 0; i < level.chests.size; i++)
		{
			if(level.chests[i].script_noteworthy == start_chest)
			{
				desired_chest_index = i;
				continue;
			}
			if(level.chests[i].hidden == 0)
			{
				nondesired_chest_index = i;
			}
		}
		if(isdefined(nondesired_chest_index) && nondesired_chest_index < desired_chest_index)
		{
			level.chests[nondesired_chest_index] maps\mp\zombies\_zm_magicbox::hide_chest();
			level.chests[nondesired_chest_index].hidden = 1;
			level.chests[desired_chest_index].hidden = 0;
			level.chests[desired_chest_index] maps\mp\zombies\_zm_magicbox::show_chest();
			level.chest_index = desired_chest_index;
		}
	}
}

fullgame_box_patch(tier)
{
	box_guns = [];
	foreach(weapon in level.zombie_weapons)
		weapon.is_in_box = 0;

	mpf = fullgame_box_mp40();

	switch(tier)
	{
		case 5: box_guns = combinearrays(box_guns, array("srm1216_zm", "ksg_zm", "dsr50_zm", "python_zm")); //D
		case 4: box_guns = combinearrays(box_guns, array("fivesevendw_zm", "beretta93r_extclip_zm", "kard_zm", "qcw05_zm", "fnfal_zm")); //C
		case 3: box_guns = combinearrays(box_guns, array("pdw57_zm", "mg08_zm", "hamr_zm", "type95_zm", "thompson_zm")); //B
		case 2: box_guns = combinearrays(box_guns, array("galil_zm", "ak74u_extclip_zm", "evoskorpion_zm", mpf)); //A
		case 1: box_guns = combinearrays(box_guns, array("scar_zm")); //S
			break;

		case 6:
			level.special_weapon_magicbox_check = undefined;
			level.zombie_weapons["raygun_mark2_zm"].is_in_box = 1;
			break;
	}

	foreach(weapon in box_guns)
		level.zombie_weapons[weapon].is_in_box = 1;
}

// The box's MP40. Vanilla boxes only the stock MP40 (mp40_stalker_zm); the MP40
// no-stock setting swaps in mp40_zm.
fullgame_box_mp40()
{
	if(get_cfg_int("box_no_stock_mp40")) return "mp40_zm";
	return "mp40_stalker_zm";
}

// Normal box tier with MP40 no-stock on: swap the box's MP40.
fullgame_box_no_stock_mp40()
{
	level.zombie_weapons["mp40_stalker_zm"].is_in_box = 0;
	level.zombie_weapons["mp40_zm"].is_in_box = 1;
}

// Every gun the box can give on Origins, for the Hit 1 and Hit 2 settings. The
// saved value is the index; 0 is random.
fullgame_box_hit_options()
{
	options = spawnstruct();
	options.weapons = [];
	options.labels = [];
	fullgame_add_box_hit_option(options, "", "random");
	fullgame_add_box_hit_option(options, "scar_zm", "SCAR-H");
	fullgame_add_box_hit_option(options, "galil_zm", "Galil");
	fullgame_add_box_hit_option(options, "ak74u_extclip_zm", "AK74u");
	fullgame_add_box_hit_option(options, "evoskorpion_zm", "Skorpion EVO");
	fullgame_add_box_hit_option(options, fullgame_box_mp40(), "MP40"); // The no-stock one only with MP40 no-stock.
	fullgame_add_box_hit_option(options, "pdw57_zm", "PDW-57");
	fullgame_add_box_hit_option(options, "mg08_zm", "MG08/15");
	fullgame_add_box_hit_option(options, "hamr_zm", "HAMR");
	fullgame_add_box_hit_option(options, "type95_zm", "Type 25");
	fullgame_add_box_hit_option(options, "thompson_zm", "M1927");
	fullgame_add_box_hit_option(options, "fivesevendw_zm", "Five-seven DW");
	fullgame_add_box_hit_option(options, "beretta93r_extclip_zm", "B23R");
	fullgame_add_box_hit_option(options, "kard_zm", "KAP-40");
	fullgame_add_box_hit_option(options, "qcw05_zm", "Chicom CQB");
	fullgame_add_box_hit_option(options, "fnfal_zm", "FAL");
	fullgame_add_box_hit_option(options, "srm1216_zm", "M1216");
	fullgame_add_box_hit_option(options, "ksg_zm", "KSG");
	fullgame_add_box_hit_option(options, "dsr50_zm", "DSR 50");
	fullgame_add_box_hit_option(options, "python_zm", "Python");
	fullgame_add_box_hit_option(options, "m32_zm", "War Machine");
	fullgame_add_box_hit_option(options, "ray_gun_zm", "Ray Gun");
	fullgame_add_box_hit_option(options, "raygun_mark2_zm", "Ray Gun Mark II");
	fullgame_add_box_hit_option(options, "cymbal_monkey_zm", "Monkey Bombs");
	return options;
}

fullgame_add_box_hit_option(options, weapon, label)
{
	options.weapons[options.weapons.size] = weapon;
	options.labels[options.labels.size] = label;
}

// Vanilla treasure_chest_chooseweightedrandomweapon calls this once per box hit
// with the shuffled weapon list and gives the first weapon in it the player can
// receive. On the first two hits, the Hit 1/Hit 2 gun goes to the front; if the
// player cannot receive it (not in the box, already owned, limit reached), the
// box picks randomly as usual.
fullgame_box_hit_weights(keys)
{
	level.fullgame_box_hits++;
	if(level.fullgame_box_hits > 2) return keys;

	choice = get_cfg_int("box_hit_" + level.fullgame_box_hits);
	options = fullgame_box_hit_options();
	if(choice <= 0 || choice >= options.weapons.size) return keys;

	forced = [];
	forced[0] = options.weapons[choice];
	foreach(key in keys) forced[forced.size] = key;
	return forced;
}

//##############MENU FUNCTIONS####################

fullgame_build_menu(root)
{
	settings = add_submenu(root, "mapsettings", level.mode.label + " Start", level.mode.label);
		add_cfg_toggle(settings, "Super Fast Restarts", "turbo_restarts"); // Other modes handle setup timescale themselves.

	create_option("presets", "Normal 29 rng", ::fullgame_apply_preset, "normal");
	create_option("presets", "Perfect 29 rng", ::fullgame_apply_preset, "perfect");
	create_option("presets", "Fast 4 box slushie", ::fullgame_apply_preset, "slushie");
	create_option("presets", "Fast 4 box snowy", ::fullgame_apply_preset, "snowy");

	self shared_build_categories(root);
	self shared_build_parts_menu("loadout");
	self shared_build_vinyls_menu("loadout");

	self shared_build_disc_menu("puzzles");
	self puzzle_rng_build_menus("puzzles");

	self shared_build_robot_menus("special_ai", ::fullgame_all_random_cycles);
	self shared_build_panzer_menu("special_ai");
	self shared_build_templar_menu("special_ai");

	randomness = add_submenu(root, "randomness", "RNG");
		digs = add_submenu(randomness, "digs", "Digs");
			add_cfg_toggle(digs, "Trenches", "bunker_dig", "^3early", "^3normal");
			add_cfg_toggle(digs, "NML", "nml_dig", "^3early", "^3normal");
			add_cfg_toggle(digs, "Church", "village_dig", "^3early", "^3normal");
			add_cfg_choice(digs, "First Dig", "1st_dig", array("random", "blood money", "nuke", "double points", "zombie blood", "ballista", "mauser", "remington", "DSR50", "M1216"));
			add_cfg_toggle(digs, "Ending Blood", "blood_dig");
			add_cfg_toggle(digs, "Round 10 Spots", "r10_digs");
			add_cfg_toggle(digs, "Ending Spots", "ending_digs");
			add_cfg_toggle(digs, "Early Ice Spots", "early_ice");
			add_cfg_toggle(digs, "Round 4 Snow", "r4_snow");
			add_cfg_toggle(digs, "Points Always 250", "250_digs");

		box = add_submenu(randomness, "box", "Mystery Box", "Box");
			add_cfg_choice(box, "Location", "box_location", array("random", "gen 3", "gen 2"));
			add_cfg_choice(box, "Box tier", "box_tier", array("normal", "S", "A", "B", "C", "D", "MK2"));
			add_cfg_toggle(box, "MP40 no-stock", "box_no_stock_mp40");
			box_guns = fullgame_box_hit_options();
			add_cfg_choice(box, "Hit 1", "box_hit_1", box_guns.labels);
			add_cfg_choice(box, "Hit 2", "box_hit_2", box_guns.labels);

		fizz = add_submenu(randomness, "fizz", "Wunderfizz", "Fizz");
			perks = array("^1r^3a^2n^5d^4o^1m ^3p^2e^5r^4k", "^3double tap", "^2speed cola", "^8deadshot", "^1juggernog", "^3stamin-up", "^2mule kick", "^6PhD flopper", "^9electric cherry", "^5quick revive");
			add_cfg_choice(fizz, "Location", "fizz_location", array("random", "gen 4", "gen 5"));
			add_cfg_choice(fizz, "Fizz 1", "fizz_1", perks);
			add_cfg_choice(fizz, "Fizz 2", "fizz_2", perks);

		powerups = add_submenu(randomness, "powerups", "Powerups");
			add_cfg_choice(powerups, "First Powerup", "fullgame_first_powerup", array("random", "nuke", "double points", "max ammo", "zombie blood", "insta kill"));
			add_cfg_toggle(powerups, "Fist of Iron Nuke", "fullgame_fist_of_iron_nuke");
}


fullgame_all_random_cycles()
{
	level.mode_cfg["rain_robot"] = ROBOT_RANDOM;
	for(i = 1; i <= ROBOT_CYCLE_COUNT; i++)
		level.mode_cfg["cycle_" + i] = ROBOT_RANDOM;
	write_config(level.mode_cfg, level.mode_cfg_str);
    self refresh_menu();
}


// Game presets. A preset resets every RNG setting to the Normal 29 rng values (the
// mode's defaults), then applies its own. Timer, split, cycle display and Super
// Fast Restarts settings are not RNG and stay as they are.
fullgame_apply_preset(preset)
{
	cfg = fullgame_default_cfg();
	label = "Normal 29 rng";
	if(preset == "perfect")
	{
		cfg = fullgame_preset_perfect(cfg);
		label = "Perfect 29 rng";
	}
	else if(preset == "snowy")
	{
		cfg = fullgame_preset_snowy(cfg);
		label = "Fast 4 box snowy";
	}
	else if(preset == "slushie")
	{
		cfg = fullgame_preset_slushie(cfg);
		label = "Fast 4 box slushie";
	}

	foreach(key in getArrayKeys(cfg))
	{
		if(key == "turbo_restarts" || key == "cycle_tracker" || key == "cycle_tracker_ms" || key == "split_nml") continue;
		level.mode_cfg[key] = cfg[key];
	}
	write_config(level.mode_cfg, level.mode_cfg_str);
	self iprintln("Preset: " + label);
	self refresh_menu();
}

// From the saved cfg prefect_29_fullgame.cfg (2026-10-29). Robot 0 Odin, 1 Thor,
// 2 Freya, foot 0 left, 1 right (oprac.gsh).
fullgame_preset_perfect(cfg)
{
	cfg["panzer_3"] = 5;
	cfg["panzer_2"] = 5;
	cfg["temps_3_gen_6"] = 0;
	cfg["temps_2_gen_6"] = 0;
	cfg["temps_1_gen_6"] = 0;
	cfg["temps_3_gen_5"] = 1;
	cfg["temps_2_gen_5"] = 0;
	cfg["temps_1_gen_5"] = 0;
	cfg["temps_3_gen_4"] = 1;
	cfg["temps_2_gen_4"] = 0;
	cfg["temps_1_gen_4"] = 0;
	cfg["temps_3_gen_3"] = 1;
	cfg["temps_2_gen_3"] = 1;
	cfg["temps_1_gen_3"] = 1;
	cfg["temps_3_gen_2"] = 1;
	cfg["temps_2_gen_2"] = 0;
	cfg["temps_1_gen_2"] = 0;
	cfg["temps_3_gen_1"] = 0;
	cfg["temps_2_gen_1"] = 0;
	cfg["temps_1_gen_1"] = 0;
	cfg["temps_3_round"] = 5;
	cfg["temps_2_round"] = 3;
	cfg["vinyl_elec"] = 1;
	cfg["vinyl_fire"] = 0;
	cfg["vinyl_air"] = 2;
	cfg["vinyl_ice"] = 2;
	cfg["vinyl_master"] = 1;
	cfg["vinyl_player"] = 1;
	cfg["shield_nml"] = -1;
	cfg["shield_gen3"] = -1;
	cfg["shield_gen2"] = -1;
	cfg["maxis_engine"] = 0;
	cfg["maxis_body"] = 0;
	cfg["foot_17"] = -1;
	cfg["cycle_17"] = -1;
	cfg["foot_16"] = -1;
	cfg["cycle_16"] = -1;
	cfg["foot_15"] = -1;
	cfg["cycle_15"] = -1;
	cfg["foot_14"] = -1;
	cfg["cycle_14"] = -1;
	cfg["foot_13"] = -1;
	cfg["cycle_13"] = -1;
	cfg["foot_12"] = -1;
	cfg["cycle_12"] = -1;
	cfg["foot_11"] = -1;
	cfg["cycle_11"] = -1;
	cfg["foot_10"] = -1;
	cfg["cycle_10"] = -1;
	cfg["foot_9"] = -1;
	cfg["cycle_9"] = -1;
	cfg["foot_8"] = -1;
	cfg["cycle_8"] = -1;
	cfg["foot_7"] = -1;
	cfg["cycle_7"] = -1;
	cfg["foot_6"] = -1;
	cfg["cycle_6"] = -1;
	cfg["foot_5"] = -1;
	cfg["cycle_5"] = -1;
	cfg["foot_4"] = 0;
	cfg["cycle_4"] = 2;
	cfg["foot_3"] = -1;
	cfg["cycle_3"] = 0;
	cfg["foot_2"] = -1;
	cfg["cycle_2"] = 1;
	cfg["foot_1"] = -1;
	cfg["cycle_1"] = 1;
	cfg["rain_foot"] = 1;
	cfg["rain_robot"] = 0;
	cfg["mechz_delay"] = "0.5";
	cfg["disc_4"] = 1121;
	cfg["disc_3"] = 2112;
	cfg["disc_2"] = 1222;
	cfg["disc_1"] = 2222;
	cfg["ending_digs"] = 1;
	cfg["early_ice"] = 1;
	cfg["r10_digs"] = 1;
	cfg["r4_snow"] = 1;
	cfg["250_digs"] = 1;
	cfg["1st_dig"] = 2;
	cfg["blood_dig"] = 1;
	cfg["village_dig"] = 1;
	cfg["nml_dig"] = 1;
	cfg["bunker_dig"] = 1;
	cfg["box_no_stock_mp40"] = 0;
	cfg["box_hit_2"] = 0;
	cfg["box_hit_1"] = 0;
	cfg["box_tier"] = 0;
	cfg["box_location"] = 0;
	// Wunderfizz at Gen 4, Double Tap then Stamin-Up (user, 2026-11-02).
	cfg["fizz_2"] = 5;
	cfg["fizz_1"] = 1;
	cfg["fizz_location"] = 1;
	cfg["fullgame_fist_of_iron_nuke"] = 0;
	cfg["fullgame_first_powerup"] = 0;
	return puzzle_rng_best(cfg);
}

// From the saved cfg fullgame_f4b_snowy.cfg (2026-10-29).
fullgame_preset_snowy(cfg)
{
	cfg["panzer_3"] = 5;
	cfg["panzer_2"] = 5;
	cfg["temps_3_gen_6"] = 0;
	cfg["temps_2_gen_6"] = 0;
	cfg["temps_1_gen_6"] = 0;
	cfg["temps_3_gen_5"] = 1;
	cfg["temps_2_gen_5"] = 1;
	cfg["temps_1_gen_5"] = 0;
	cfg["temps_3_gen_4"] = 1;
	cfg["temps_2_gen_4"] = 0;
	cfg["temps_1_gen_4"] = 0;
	cfg["temps_3_gen_3"] = 1;
	cfg["temps_2_gen_3"] = 0;
	cfg["temps_1_gen_3"] = 1;
	cfg["temps_3_gen_2"] = 1;
	cfg["temps_2_gen_2"] = 0;
	cfg["temps_1_gen_2"] = 0;
	cfg["temps_3_gen_1"] = 0;
	cfg["temps_2_gen_1"] = 0;
	cfg["temps_1_gen_1"] = 0;
	cfg["temps_3_round"] = 5;
	cfg["temps_2_round"] = 3;
	cfg["vinyl_elec"] = 0;
	cfg["vinyl_fire"] = 0;
	cfg["vinyl_air"] = 2;
	cfg["vinyl_ice"] = 2;
	cfg["vinyl_master"] = 1;
	cfg["vinyl_player"] = 1;
	cfg["shield_nml"] = -1;
	cfg["shield_gen3"] = -1;
	cfg["shield_gen2"] = -1;
	cfg["maxis_engine"] = 0;
	cfg["maxis_body"] = 0;
	cfg["foot_17"] = -1;
	cfg["cycle_17"] = -1;
	cfg["foot_16"] = -1;
	cfg["cycle_16"] = -1;
	cfg["foot_15"] = -1;
	cfg["cycle_15"] = -1;
	cfg["foot_14"] = -1;
	cfg["cycle_14"] = 0;
	cfg["foot_13"] = -1;
	cfg["cycle_13"] = 1;
	cfg["foot_12"] = -1;
	cfg["cycle_12"] = 2;
	cfg["foot_11"] = -1;
	cfg["cycle_11"] = 1;
	cfg["foot_10"] = -1;
	cfg["cycle_10"] = 2;
	cfg["foot_9"] = -1;
	cfg["cycle_9"] = 1;
	cfg["foot_8"] = -1;
	cfg["cycle_8"] = 2;
	cfg["foot_7"] = -1;
	cfg["cycle_7"] = 1;
	cfg["foot_6"] = -1;
	cfg["cycle_6"] = 0;
	cfg["foot_5"] = 0;
	cfg["cycle_5"] = 2;
	cfg["foot_4"] = 1;
	cfg["cycle_4"] = 1;
	cfg["foot_3"] = -1;
	cfg["cycle_3"] = 0;
	cfg["foot_2"] = -1;
	cfg["cycle_2"] = 1;
	cfg["foot_1"] = 0;
	cfg["cycle_1"] = 1;
	cfg["rain_foot"] = 0;
	cfg["rain_robot"] = 0;
	cfg["mechz_delay"] = "0.5";
	cfg["disc_4"] = 1121;
	cfg["disc_3"] = 2112;
	cfg["disc_2"] = 1222;
	cfg["disc_1"] = 2222;
	cfg["ending_digs"] = 1;
	cfg["early_ice"] = 1;
	cfg["r10_digs"] = 1;
	cfg["r4_snow"] = 1;
	cfg["250_digs"] = 1;
	cfg["1st_dig"] = 2;
	cfg["blood_dig"] = 1;
	cfg["village_dig"] = 1;
	cfg["nml_dig"] = 1;
	cfg["bunker_dig"] = 1;
	cfg["box_no_stock_mp40"] = 0;
	cfg["box_hit_2"] = 0;
	cfg["box_hit_1"] = 1;
	cfg["box_tier"] = 1;
	cfg["box_location"] = 2;
	cfg["fizz_2"] = 5;
	cfg["fizz_1"] = 1;
	cfg["fizz_location"] = 1;
	cfg["fullgame_fist_of_iron_nuke"] = 1;
	cfg["fullgame_first_powerup"] = 1;
	cfg = puzzle_rng_best(cfg);
	return fullgame_preset_early_feet(cfg);
}

// Fast 4 box feet (user, 2026-10-29): every cycle the preset sets to Freya gets the
// left foot and every Odin the right foot. Thor and random cycles keep theirs.
fullgame_preset_early_feet(cfg)
{
	for(cycle = 1; cycle <= ROBOT_CYCLE_COUNT; cycle++)
	{
		if(cfg["cycle_" + cycle] == ROBOT_FREYA) cfg["foot_" + cycle] = FOOT_LEFT;
		if(cfg["cycle_" + cycle] == ROBOT_ODIN) cfg["foot_" + cycle] = FOOT_RIGHT;
	}
	return cfg;
}

// Snowy with cycles 3 to 7 changed (user's screenshot, 2026-10-29).
fullgame_preset_slushie(cfg)
{
	cfg = fullgame_preset_snowy(cfg);
	cfg["cycle_3"] = 2; // freya
	cfg["cycle_4"] = 0; // odin
	cfg["cycle_5"] = 2; // freya
	cfg["cycle_6"] = 0; // odin
	cfg["cycle_7"] = 1; // thor
	return fullgame_preset_early_feet(cfg);
}

//##############hud elements####################

//##############overrides####################
fullgame_bonus_points_powerup_override()
{
	points = 250;
	if(!get_cfg_int("250_digs"))
		points = randomintrange( 1, 6 ) * 50;
    level thread maps\mp\zombies\_zm_audio_announcer::leaderdialog( "blood_money" );
    return points;
}

fullgame_waittill_dug(s_dig_spot)
{
	while(true)
	{
		self waittill("trigger", player);
		if(isDefined(player.dig_vars["has_shovel"]) && player.dig_vars["has_shovel"])
		{
			player playsound("evt_dig");
			s_dig_spot.dug = 1;
			level.n_dig_spots_cur--;
			playfx(level._effect["digging"], self.origin);
			player setclientfieldtoplayer("player_rumble_and_shake", 1);
			player maps\mp\zombies\_zm_stats::increment_client_stat("tomb_dig", 0);
			player maps\mp\zombies\_zm_stats::increment_player_stat("tomb_dig");
			s_staff_piece = s_dig_spot fullgame_dig_spot_get_staff_piece(player);
			if(isDefined(s_staff_piece))
			{
				s_staff_piece maps\mp\zm_tomb_main_quest::show_ice_staff_piece(self.origin);
				player maps\mp\zm_tomb_dig::dig_reward_dialog("dig_staff_part");
			}
			else
			{
				n_good_chance = 50;
				if(player.dig_vars["n_spots_dug"] == 0 || player.dig_vars["n_losing_streak"] == 3)
				{
					player.dig_vars["n_losing_streak"] = 0;
					n_good_chance = 100;
				}
				if(player.dig_vars["has_upgraded_shovel"])
				{
					if(!player.dig_vars["has_helmet"])
					{
						n_helmet_roll = randomint(100);
						if(n_helmet_roll >= 95)
						{
							player.dig_vars["has_helmet"] = 1;
							n_player = player getentitynumber() + 1;
							level setclientfield("helmet_player" + n_player, 1);
							player playsoundtoplayer("zmb_squest_golden_anything", player);
							player maps\mp\zombies\_zm_stats::increment_client_stat("tomb_golden_hard_hat", 0);
							player maps\mp\zombies\_zm_stats::increment_player_stat("tomb_golden_hard_hat");
							return;
						}
					}
					n_good_chance = 70;
				}
				n_prize_roll = randomint(100);
				if(flag("ee_mech_zombie_hole_opened") && !level.dig_n_zombie_bloods_spawned && get_cfg_int("blood_dig"))
				{
					self thread first_dig(player, "zombie_blood");
				}
				else if(player.dig_vars["n_spots_dug"] == 0 && get_cfg_int("1st_dig"))
				{
					value = get_cfg_int("1st_dig");
					if(value < 5)
						self thread first_dig(player, level.first_dig_list[value]);
					else if(value < 10)
						self thread weapon_first(player, level.first_dig_list[value]);
				}
				else if(get_cfg_int("250_digs"))
				{
					self thread first_dig(player, "bonus_points_player");
				}
				else if(n_prize_roll > n_good_chance)
				{
					if(cointoss())
					{
						player maps\mp\zm_tomb_dig::dig_reward_dialog("dig_grenade");
						self thread maps\mp\zm_tomb_dig::dig_up_grenade(player);
					}
					else
					{
						player maps\mp\zm_tomb_dig::dig_reward_dialog("dig_zombie");
						self thread maps\mp\zm_tomb_dig::dig_up_zombie(player, s_dig_spot);
					}
					player.dig_vars["n_losing_streak"]++;
				}
				else if(cointoss())
				{
					self thread maps\mp\zm_tomb_dig::dig_up_powerup(player);
				}
				else
				{
					player maps\mp\zm_tomb_dig::dig_reward_dialog("dig_gun");
					self thread maps\mp\zm_tomb_dig::dig_up_weapon(player);
				}
			}
			if(!player.dig_vars["has_upgraded_shovel"])
			{
				player.dig_vars["n_spots_dug"]++;
				if(player.dig_vars["n_spots_dug"] >= 30)
				{
					player.dig_vars["has_upgraded_shovel"] = 1;
					player thread maps\mp\zm_tomb_dig::ee_zombie_blood_dig();
					n_player = player getentitynumber() + 1;
					level setclientfield("shovel_player" + n_player, 2);
					player playsoundtoplayer("zmb_squest_golden_anything", player);
					player maps\mp\zombies\_zm_stats::increment_client_stat("tomb_golden_shovel", 0);
					player maps\mp\zombies\_zm_stats::increment_player_stat("tomb_golden_shovel");
				}
			}
			return;
		}
	}
}

first_dig( player, powerup_item)
{
    powerup = spawn( "script_model", self.origin );
    powerup endon( "powerup_grabbed" );
    powerup endon( "powerup_timedout" );

	if( powerup_item == "zombie_blood")
	{
		level.dig_n_zombie_bloods_spawned++;
		level.dig_n_powerups_spawned++;
		level.dig_last_prize_rare = 0;
		player maps\mp\zm_tomb_dig::dig_reward_dialog( "dig_powerup" );
	}
	else if( powerup_item == "bonus_points_player")
	{
		level.dig_last_prize_rare = 0;
		player maps\mp\zm_tomb_dig::dig_reward_dialog( "dig_cash" );
	}
    else
    {
        level.dig_last_prize_rare = 1;
        level.dig_n_powerups_spawned++;
        player maps\mp\zm_tomb_dig::dig_reward_dialog( "dig_powerup" );
        maps\mp\zm_tomb_dig::dig_set_powerup_spawned( powerup_item );
    }

    powerup maps\mp\zombies\_zm_powerups::powerup_setup( powerup_item );
    powerup movez( 40, 0.6 );

    powerup waittill( "movedone" );

    powerup thread maps\mp\zombies\_zm_powerups::powerup_timeout();
    powerup thread maps\mp\zombies\_zm_powerups::powerup_wobble();
    powerup thread maps\mp\zombies\_zm_powerups::powerup_grab();
}

weapon_first( digger, weapon )
{
	str_spec_model = undefined;
	v_spawnpt = self.origin + ( 0, 0, 40 );
    v_angles = digger getplayerangles();
    v_angles = ( 0, v_angles[1], 0 ) + vectorscale( ( 0, 1, 0 ), 90.0 ) + ( 0, 0, 0 );
    m_weapon = spawn_weapon_model( weapon, str_spec_model, v_spawnpt, v_angles );

    m_weapon.angles = v_angles;
    m_weapon playloopsound( "evt_weapon_digup" );
    m_weapon thread maps\mp\zm_tomb_dig::timer_til_despawn( v_spawnpt, 40 * -1 );
    m_weapon endon( "dig_up_weapon_timed_out" );
    playfxontag( level._effect["special_glow"], m_weapon, "tag_origin" );
    m_weapon.trigger = maps\mp\zm_tomb_utility::tomb_spawn_trigger_radius( v_spawnpt, 100, 1 );
    m_weapon.trigger.hint_string = &"ZM_TOMB_X2PU";
    m_weapon.trigger.hint_parm1 = getweapondisplayname( weapon );

    m_weapon.trigger waittill( "trigger", player );

    m_weapon.trigger notify( "weapon_grabbed" );
    m_weapon.trigger thread swap_weapon( weapon, player );

    if ( isDefined( m_weapon.trigger ) )
    {
        m_weapon.trigger maps\mp\zm_tomb_utility::tomb_unitrigger_delete();
        m_weapon.trigger = undefined;
    }

    if ( isDefined( m_weapon ) )
        m_weapon delete();

    if ( player != digger )
        digger notify( "dig_up_weapon_shared" );
}

fullgame_dig_spot_get_staff_piece(e_player)
{
	level notify("sam_clue_dig", e_player);
	str_zone = self.str_zone;
	foreach(s_staff in level.ice_staff_pieces)
	{
		if(!isDefined(s_staff.num_misses))
			s_staff.num_misses = 0;

		if(issubstr(str_zone, s_staff.zone_substr))
		{
			miss_chance = 100 / (s_staff.num_misses + 1);
			if(level.weather_snow <= 0)
				miss_chance = 101;

			switch(s_staff.zone_substr)
			{
				case "bunker":
					if(get_cfg_int("bunker_dig") && miss_chance < 100) return s_staff;
					break;

				case "nml":
					if(get_cfg_int("nml_dig") && miss_chance < 100) return s_staff;
					break;

				case "village":
					if(get_cfg_int("village_dig") && miss_chance < 100) return s_staff;
					break;
			}

			if(randomint(100) > miss_chance || s_staff.num_misses > 3 && miss_chance < 100)
			{
				return s_staff;
			}
			s_staff.num_misses++;
			break;
		}
	}
	return undefined;
}

fullgame_get_recapture_zone(s_last_recapture_zone)
{
	a_s_player_zones = [];
	foreach ( str_key, s_zone in level.zone_capture.zones )
	{
		if(s_zone ent_flag("player_controlled"))
		{
			a_s_player_zones[str_key] = s_zone;
		}
	}
	s_recapture_zone = undefined;
	if(a_s_player_zones.size)
	{
		if(isDefined(s_last_recapture_zone))
		{
			n_distance_closest = undefined;
			foreach(s_zone in a_s_player_zones)
			{
				n_distance = distancesquared(s_zone.origin, s_last_recapture_zone.origin);
				if(!isDefined(n_distance_closest) || n_distance < n_distance_closest)
				{
					s_recapture_zone = s_zone;
					n_distance_closest = n_distance;
				}
			}
		}
		else if(level.n_templar_rounds < 4)
		{
			possible_gens = [];
			possible_gens[possible_gens.size] = "generator_start_bunker";
			possible_gens[possible_gens.size] = "generator_tank_trench";
			possible_gens[possible_gens.size] = "generator_mid_trench";
			possible_gens[possible_gens.size] = "generator_nml_right";
			possible_gens[possible_gens.size] = "generator_nml_left";
			possible_gens[possible_gens.size] = "generator_church";
			non_wanted_gens = [];
			for(i = 1; i < 7; i++)
			{
				setting = "temps_" + level.n_templar_rounds + "_gen_" + i;
				gen_enabled = get_cfg_int(setting);
				if(gen_enabled == 0)
				{
					non_wanted_gens[non_wanted_gens.size] = possible_gens[i - 1];
				}
			}
			invalid_gen = 1;
			timeout = 0;
			while(invalid_gen)
			{
				if(timeout == 30)
				{
					s_recapture_zone = random(a_s_player_zones);
					break;
				}
				invalid_gen = 0;
				s_recapture_zone = random(a_s_player_zones);
				foreach(loc in non_wanted_gens)
				{
					if(s_recapture_zone == level.zone_capture.zones[loc])
					{
						invalid_gen = 1;
					}
				}
				timeout++;
			}
		}
		else
		{
			s_recapture_zone = random(a_s_player_zones);
		}
	}
	return s_recapture_zone;
}

fullgame_dig_spots_respawn( a_dig_spots )
{
	while(!isDefined(level.a_dig_spots)) wait 0.05;
	o_dig_spots = level.a_dig_spots;

    while ( true )
    {
        level waittill( "end_of_round" );

        wait 2;
        a_dig_spots = array_randomize( level.a_dig_spots );
        n_respawned = 0;
        n_respawned_max = 3;

        if ( level.weather_snow > 0 )
            n_respawned_max = 0;
        else if ( level.weather_rain > 0 )
            n_respawned_max = 5;

        if ( level.weather_snow == 0 )
            n_respawned_max += randomint( get_players().size );

		override_dig_spots = undefined;
        //custom logic
		if(get_cfg_int("early_ice") && level.round_number < 5)
		{
			//exca box, mp40, nml door
			override_dig_spots = array(1, 17, 21);
		}
		else if(get_cfg_int("r10_digs") && level.round_number < 11)
		{
			//slow fast dig, cutch box, fast dig, far freya, front tank
			override_dig_spots = array(2, 12, 13, 14, 27);
		}
		else if(get_cfg_int("ending_digs") && level.round_number < 16)
		{
			// slow foot, rain dig, gen5 box, old bulb2 line
			override_dig_spots = array(16, 18, 19, 20);
		}

		if(isDefined(override_dig_spots))
		{
			for ( i = 0; i < override_dig_spots.size; i++ )
			{
				dig_index = override_dig_spots[i];
				if ( isDefined( o_dig_spots[dig_index].dug ) && o_dig_spots[dig_index].dug && n_respawned < n_respawned_max && level.n_dig_spots_cur <= level.n_dig_spots_max )
				{
					o_dig_spots[dig_index].dug = undefined;
					o_dig_spots[dig_index] thread maps\mp\zm_tomb_dig::dig_spot_spawn();
					wait_network_frame();
					n_respawned++;
				}
			}
		}

        for ( i = 0; i < a_dig_spots.size; i++ )
        {
            if ( isDefined( a_dig_spots[i].dug ) && a_dig_spots[i].dug && n_respawned < n_respawned_max && level.n_dig_spots_cur <= level.n_dig_spots_max )
            {
                a_dig_spots[i].dug = undefined;
                a_dig_spots[i] thread maps\mp\zm_tomb_dig::dig_spot_spawn();
                wait_network_frame();
                n_respawned++;
            }
        }

        if ( level.weather_snow > 0 && level.ice_staff_pieces.size > 0 )
        {
            foreach ( s_staff in level.ice_staff_pieces )
            {
                a_staff_spots = [];
                n_active_mounds = 0;

                foreach ( s_dig_spot in level.a_dig_spots )
                {
                    if ( isDefined( s_dig_spot.str_zone ) && issubstr( s_dig_spot.str_zone, s_staff.zone_substr ) )
                    {
                        if ( !( isDefined( s_dig_spot.dug ) && s_dig_spot.dug ) )
                        {
                            n_active_mounds++;
                            continue;
                        }

                        a_staff_spots[a_staff_spots.size] = s_dig_spot;
                    }
                }

                if ( n_active_mounds < 2 && a_staff_spots.size > 0 && level.n_dig_spots_cur <= level.n_dig_spots_max )
                {
                    n_index = randomint( a_staff_spots.size );
                    a_staff_spots[n_index].dug = undefined;
                    a_staff_spots[n_index] thread maps\mp\zm_tomb_dig::dig_spot_spawn();
                    arrayremoveindex( a_staff_spots, n_index );
                    n_active_mounds++;
                    wait_network_frame();
                }
            }
        }
    }
}

fullgame_get_weighted_random_perk(player)
{
	hits = player maps\mp\gametypes_zm\_globallogic_score::getpersstat("use_perk_random");
	hacked_perks = array("specialty_rof", "specialty_fastreload", "specialty_deadshot", "specialty_armorvest", "specialty_longersprint", "specialty_additionalprimaryweapon", "specialty_flakjacket", "specialty_grenadepulldeath", "specialty_quickrevive");
	fizz_1 = get_cfg_int("fizz_1");
	fizz_2 = get_cfg_int("fizz_2");
	if(hits == 1 && 0 < fizz_1)
	{
		perk = hacked_perks[fizz_1 - 1];
		if(!(player hasperk(perk)))
			return perk;
	}
	else if(hits == 2 && 0 < fizz_2)
	{
		perk = hacked_perks[fizz_2 - 1];
		if(!(player hasperk(perk)))
			return perk;
	}
	keys = array_randomize(getarraykeys(level._random_perk_machine_perk_list));
	if(isdefined(level.custom_random_perk_weights))
	{
		keys = player [[level.custom_random_perk_weights]]();
	}
	i = 0;
	while(i < keys.size)
	{
		key = keys[i];
		if(player hasperk(level._random_perk_machine_perk_list[key]))
		{
			continue;
		}
		else
		{
			return level._random_perk_machine_perk_list[key];
		}
		i++;
	}
	return level._random_perk_machine_perk_list[keys[0]];
}

fullgame_chamber_discs_randomize()
{
	level.n_disc_scrambles++;
	scramble = get_cfg_int("disc_" + level.n_disc_scrambles);
	if(!isDefined(scramble))
		scramble = 0;
	discs = getentarray("crypt_puzzle_disc", "script_noteworthy");
	//MODIFIED: the four dials, as vanilla picks them (the ones with levers); the
	// main disc may sit anywhere in the array and must keep its position.
	dials = [];
	foreach(disc in discs)
		if(isdefined(disc.target)) dials[dials.size] = disc;
	//MODIFIED END
	prev_disc_pos = 0;
	for( i = 1; i <= dials.size; i++)
	{
		if(scramble)
		{
			turn = int(scramble / pow( 10, 4 - i )) % 10;
			dials[i - 1].position = (prev_disc_pos + turn) % 4;
		}
		else
		{
			dials[i - 1].position = (prev_disc_pos + randomintrange(1, 3)) % 4;
		}
		prev_disc_pos = dials[i - 1].position;
	}
	maps\mp\zm_tomb_quest_crypt::chamber_discs_move_all_to_position(discs);
}

fullgame_randomize_powerups()
{
	level.zombie_powerup_array = array_randomize( level.zombie_powerup_array );

	if (get_cfg_int("fullgame_first_powerup") && level.round_number <= 1)
	{
		powerups = array("random", "nuke", "double_points", "full_ammo", "zombie_blood", "insta_kill");
		powerup = powerups[get_cfg_int("fullgame_first_powerup")];
		powerup_index = get_powerup_index(powerup);
		level.zombie_powerup_array[powerup_index] = level.zombie_powerup_array[0];
		level.zombie_powerup_array[0] = powerup;
	}

	if(get_cfg_int("fullgame_fist_of_iron_nuke") && !flag("fullgame_fist_of_iron_nuke_dropped") && level.round_number >= 13)
	{
		nuke_index = get_powerup_index("nuke");
		level.zombie_powerup_array[nuke_index] = level.zombie_powerup_array[level.zombie_powerup_array.size - 1];
		level.zombie_powerup_array[level.zombie_powerup_array.size - 1] = "nuke";
	}
}

get_powerup_index(powerup)
{
	for(i = 0; i < level.zombie_powerup_array.size; i++)
	{
		if(level.zombie_powerup_array[i] == powerup)
		{
			return i;
		}
	}
	return -1;
}

fullgame_powerup_drop( drop_point )
{
    if ( level.powerup_drop_count >= level.zombie_vars["zombie_powerup_drop_max_per_round"] )
    {
/#
        println( "^3POWERUP DROP EXCEEDED THE MAX PER ROUND!" );
#/
        return;
    }

    if ( !isdefined( level.zombie_include_powerups ) || level.zombie_include_powerups.size == 0 )
        return;

    rand_drop = randomint( 100 );

	fist_of_iron_nuke_set = 0;
	p1 = getPlayers()[0];
	if(get_cfg_int("fullgame_fist_of_iron_nuke") && !flag("fullgame_fist_of_iron_nuke_dropped") && isDefined(p1.n_ee_punch_souls) && p1.n_ee_punch_souls >= 20 && level.zombie_total <= 2)
	{
		rand_drop = 0;
		nuke_index = get_powerup_index("nuke");
		if(nuke_index >= level.zombie_powerup_index)
		{
			level.zombie_powerup_array[nuke_index] = level.zombie_powerup_array[level.zombie_powerup_index];
			level.zombie_powerup_array[level.zombie_powerup_index] = "nuke";
			fist_of_iron_nuke_set = 1;
		}
	}

    if ( rand_drop > 2 )
    {
        if ( !level.zombie_vars["zombie_drop_item"] )
            return;

        debug = "score";
    }
    else
        debug = "random";

    playable_area = getentarray( "player_volume", "script_noteworthy" );
    level.powerup_drop_count++;
    powerup = maps\mp\zombies\_zm_net::network_safe_spawn( "powerup", 1, "script_model", drop_point + vectorscale( ( 0, 0, 1 ), 40.0 ) );
    valid_drop = 0;

    for ( i = 0; i < playable_area.size; i++ )
    {
        if ( powerup istouching( playable_area[i] ) )
            valid_drop = 1;
    }

    if ( valid_drop && level.rare_powerups_active )
    {
        pos = ( drop_point[0], drop_point[1], drop_point[2] + 42 );

        if ( check_for_rare_drop_override( pos ) )
        {
            level.zombie_vars["zombie_drop_item"] = 0;
            valid_drop = 0;
        }
    }

    if ( !valid_drop )
    {
        level.powerup_drop_count--;
        powerup delete();
        return;
    }

	if(fist_of_iron_nuke_set)
	{
		flag_set("fullgame_fist_of_iron_nuke_dropped");
	}

    powerup powerup_setup();
    print_powerup_drop( powerup.powerup_name, debug );
    powerup thread powerup_timeout();
    powerup thread powerup_wobble();
    powerup thread powerup_grab();
    powerup thread powerup_move();
    powerup thread powerup_emp();
    level.zombie_vars["zombie_drop_item"] = 0;
    level notify( "powerup_dropped", powerup );
}
