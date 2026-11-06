#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\saveslots;

/*##############################################################################
                              Menu panel layout
##############################################################################*/
// HUD units from the screen center
#define MENU_X              250     // Left edge 146, right edge 354.
#define MENU_Y              -64     // Bottom edge 34.5: the last row's bar touches the border.
#define MENU_WIDTH          208
#define MENU_HEIGHT         157
#define MENU_BORDER         2
#define MENU_LEFT           (MENU_X - MENU_WIDTH / 2)
#define MENU_RIGHT          (MENU_X + MENU_WIDTH / 2)
#define MENU_BOTTOM         (MENU_Y + MENU_HEIGHT / 2)
#define MENU_HEADER_Y       -150
#define MENU_HEADER_HEIGHT  18
#define MENU_HEADER_TEXT_Y  (MENU_HEADER_Y - 1) // High enough that a g stays on the header: black on the black panel it looks cut off.

#define MENU_ROWS           9
#define MENU_FIRST_ROW_Y    -132
#define MENU_ROW_SPACING    17      // The font's own line height: all rows are one text.

// Plain text shows a percent sign as a dot (exe I_CleanChar) and only a hud label
// keeps it (chat test, live 2026-11-06). So a row written "3% Drops" draws the "3%"
// as a label on its own element, the text leaves room for it, and only rows on
// screen cost an element.
#define MENU_PERCENT_PAD    "      "  // Wider than "3%" in the rows' font: 4 overlapped (live 2026-11-06).

// Holding frag on a long row. The action slot buttons cannot repeat: they read true
// for one frame however long the key is held (live 2026-11-05). Frag reads as held,
// and is free while the menu blocks offhands.
#define MENU_HOLD_VALUES    10      // A row with this many values or more repeats.
#define MENU_HOLD_DELAY     400     // Milliseconds held before the first repeat.
#define MENU_HOLD_STEP      100     // Milliseconds between repeats.

// Two presses on a row that asks first must be this far apart, so a double tap
// cannot pass (milliseconds).
#define MENU_ARM_DELAY      300

#define MENU_HELP_WIDTH     MENU_WIDTH
#define MENU_HELP_HEIGHT    83
#define MENU_HELP_GAP       4       // Between the panel and the box under it.
#define MENU_ICON_SIZE      56

#define MENU_CURSOR_ALPHA   .45
#define MENU_CURSOR_HEIGHT  17

#define MENU_TEXT_COLOR        (1, 1, 1)
#define MENU_BACKGROUND_COLOR  (0, 0, 0)

/*##############################################################################
                              Menu tree
##############################################################################*/
// Builds every menu. Builds again after change, so labels always show current values.
// The root keeps one order in every mode (root_menu_order). Presets exists before the
// mode builds, so a mode can add its own presets above the save slots.
build_menu_tree()
{
	root = self.menu.root;
	create_menu(root, undefined, level.mode.label);

	self build_modes_menu(root);
	add_submenu(root, "presets", "Presets");
	if(isDefined(level.mode.build_menu))
		self [[ level.mode.build_menu ]](root);
	if(isDefined(level.practice_map.build_map_menu))
		self [[ level.practice_map.build_map_menu ]](root);
	self add_saveslots_menu();
	self add_restore_defaults_option();
	self build_hud_menu(root);
	self build_cheats_menu(root);
	self build_general_menu(root);
	self sort_root_menu();
}

// The root rows in the order of common use, by menu id. A root menu that ends up
// empty is hidden (sort_root_menu), so each mode shows only the menus it has.
root_menu_order()
{
	return array("gamemodes", "mapsettings", "loadout", "puzzles", "special_ai", "randomness", "victis", "teleport", "afterlife", "tomahawk", "HUD", "cheats", "presets", "general");
}

// Stable sort of the root menu's rows by root_menu_order, leaving out submenus with
// no rows. Rows that are not a submenu keep the rank of an unlisted menu.
sort_root_menu()
{
	root = self.menu.root;
	order = root_menu_order();
	unlisted = 0.5;
	for(i = 0; i < order.size; i++)
		if(order[i] == "mapsettings") unlisted = i + 0.5;

	count = self.menu.option_text[root].size;
	ranks = [];
	for(row = 0; row < count; row++)
	{
		ranks[row] = unlisted;
		if(self.menu.option_func[root][row] != ::enter_menu) continue;
		for(i = 0; i < order.size; i++)
			if(order[i] == self.menu.option_arg1[root][row]) ranks[row] = i;
	}

	// Insertion sort of the row numbers.
	sorted = [];
	for(row = 0; row < count; row++)
	{
		if(self.menu.option_func[root][row] == ::enter_menu && !self.menu.option_text[self.menu.option_arg1[root][row]].size) continue;
		pos = sorted.size;
		while(pos > 0 && ranks[sorted[pos - 1]] > ranks[row]) pos--;
		for(j = sorted.size; j > pos; j--) sorted[j] = sorted[j - 1];
		sorted[pos] = row;
	}

	text = [];
	func = [];
	arg1 = [];
	arg2 = [];
	for(i = 0; i < sorted.size; i++)
	{
		text[i] = self.menu.option_text[root][sorted[i]];
		func[i] = self.menu.option_func[root][sorted[i]];
		arg1[i] = self.menu.option_arg1[root][sorted[i]];
		arg2[i] = self.menu.option_arg2[root][sorted[i]];
	}
	self.menu.option_text[root] = text;
	self.menu.option_func[root] = func;
	self.menu.option_arg1[root] = arg1;
	self.menu.option_arg2[root] = arg2;
}

build_modes_menu(root)
{
	modes = add_submenu(root, "gamemodes", "Practice Modes", "Modes");
	// Setups are written for one player: co-op gets the first mode, Fullgame (user, 2026-11-06).
	count = level.modes.size;
	if(get_players().size > 1) count = 1;
	for(i = 0; i < count; i++)
	{
		mode = level.modes[i];
		if(mode_is_implemented(mode))
			create_option(modes, mode.label + " " + gamemode_live_tag(mode.name), ::set_gamemode, mode.name);
		else
			create_option(modes, "-" + mode.label + " ", ::menu_not_implemented);
	}
}

// Last row of Presets, for a mode with settings (every mode builds them as "mapsettings").
// It deletes the mode's saved cfg and writes a new one from the defaults, so every
// setting of the mode resets, not only that menu's, and keys left by older
// versions go too. It asks once before doing it.
add_restore_defaults_option()
{
	if(!isDefined(self.menu.option_text["mapsettings"]) || !isDefined(level.mode_cfg_defaults)) return;
	// A mode without slots has no Presets menu.
	menu = "presets";
	if(!saveslots_available()) menu = "mapsettings";
	create_confirm_option(menu, "Restore " + level.mode.label + " Defaults", "Confirm Restore Defaults", ::restore_mode_defaults);
}

// A row that asks first: the first press arms it, a second press runs func.
// Leaving the row cancels (menu_disarm). label and func stay with the row, keyed by
// menu and label, because a row carries only two arguments.
create_confirm_option(menu, label, confirm_label, func, arg1, arg2)
{
	id = menu + "/" + label;
	confirm = spawnstruct();
	confirm.func = func;
	confirm.arg1 = arg1;
	confirm.arg2 = arg2;
	self.menu.confirm[id] = confirm;
	if(isDefined(self.menu.armed) && self.menu.armed == id) label = "^1" + confirm_label;
	create_option(menu, label, ::menu_confirm_press, id);
}

menu_confirm_press(id)
{
	if(!isDefined(self.menu.armed) || self.menu.armed != id)
	{
		self.menu.armed = id;
		self.menu.armed_time = getTime();
		self refresh_menu();
		return;
	}
	if(getTime() - self.menu.armed_time < MENU_ARM_DELAY) return;
	self.menu.armed = undefined;
	confirm = self.menu.confirm[id];
	self thread [[ confirm.func ]](confirm.arg1, confirm.arg2);
	self refresh_menu();
}

menu_disarm()
{
	if(!isDefined(self.menu.armed)) return;
	self.menu.armed = undefined;
	self refresh_menu();
}

restore_mode_defaults()
{
	fs_remove(level.mode_cfg_str);
	level.mode_cfg = level.mode_cfg_defaults;
	write_config(level.mode_cfg, level.mode_cfg_str);
	if(isDefined(level.restore_slots)) [[ level.restore_slots ]](true);
	else if(self saveslots_available()) saveslot_put_default();
	self iprintln(level.mode.label + " defaults restored");
	self refresh_menu();
}

// Modes that declare a timer (mode_timer). Split changes apply on restart.
build_timer_menu(parent)
{
	timer = level.mode.timer;
	if(!isDefined(timer)) return;
	labels = level.practice_map.split_labels;
	menu = add_submenu(parent, "timer", "Timer");
		create_option(menu, "HUD Timer: " + cfgint_compare("timer_main"), ::toggle_timer_main);
		if(timer.segment) create_option(menu, "Segment Timer: " + cfgint_compare("timer_segment"), ::toggle_timer_segment);
		if(is_true(level.practice_map.fixed_splits)) return;
		for(i = timer.first_split; i < labels.size - 1; i++)
			add_cfg_toggle(menu, labels[i], split_setting(i));
		create_option(menu, labels[labels.size - 1] + ": ^2always", ::timer_last_split_fixed);
}

timer_last_split_fixed()
{
	self iprintln("The last split always shows");
}

// Loads another map's classic game with Plutonium's zmmap (user, 2026-11-04: a
// plain map command with the gametype dvars gives the Victis maps no session
// with permaperks). Each map's practice script loads with its map, so the new
// map opens with its own menu when that map's script is installed.
build_change_map_menu(parent)
{
	menu = add_submenu(parent, "changemap", "Change Map");
		add_change_map_option(menu, "Origins", "zm_tomb", "tomb");
		add_change_map_option(menu, "Mob of the Dead", "zm_prison", "prison");
		add_change_map_option(menu, "TranZit", "zm_transit", "transit");
		add_change_map_option(menu, "Die Rise", "zm_highrise", "rooftop");
		add_change_map_option(menu, "Buried", "zm_buried", "processing");
}

add_change_map_option(menu, label, map, location)
{
	confirm_label = "Confirm " + label;
	if(getdvar("mapname") == map) label += " ^9[^3live^9]";
	create_confirm_option(menu, label, confirm_label, ::change_map, map, location);
}

change_map(map, location)
{
	if(!self ishost())
	{
		self iprintln("Only the host can change the map");
		return;
	}
	// Each map keeps its own menu position: coming back here starts at the main page.
	setDvar(menu_state_dvar(), "");
	self iprintln("Loading...");
	cmdexec("zmmap " + map + " " + location + " zclassic");
}

// Chat "map <name>", the Change Map menu without the confirm. Words after "map" are
// joined, so "die rise" works. Returns whether the message was this command.
change_map_say_command(message)
{
	words = strtok(message, " ");
	if(!words.size || words[0] != "map") return false;

	name = "";
	for(i = 1; i < words.size; i++)
		name += words[i];

	switch(name)
	{
		case "origins":
			self change_map("zm_tomb", "tomb");
			break;
		case "mob":
			self change_map("zm_prison", "prison");
			break;
		case "tranzit":
		case "transit":
			self change_map("zm_transit", "transit");
			break;
		case "dierise":
			self change_map("zm_highrise", "rooftop");
			break;
		case "buried":
			self change_map("zm_buried", "processing");
			break;
		default:
			self iprintln("^3map <origins, mob, tranzit, die rise, buried>^7: loads that map");
			break;
	}
	return true;
}

// Options every mode has. Anything mode specific goes in the modes own menu.
build_general_menu(root)
{
	general = add_submenu(root, "general", "General");
		self build_change_map_menu(general);
		if(isDefined(level.practice_map.character_names))
		{
			names = combinearrays(array("default"), level.practice_map.character_names);
			create_option(general, "Character: ^3" + names[get_cfg_int("player_character")], ::basegame_next_character, names.size - 1);
		}
		create_option(general, "Identifier/Hashes: " + cfgint_compare("show_identifier"), ::basegame_toggle_show_identifier);
		add_cfg_choice(general, "Menu Key", "menu_key", array("melee + special", "melee + slot 1"));
		create_confirm_option(general, "Rage Quit", "Confirm Rage Quit", ::fast_quit);
}

// >Timer when the mode has one, core rows, the map's top rows (build_hud_top) after
// the Speedometer, then the map's rows (build_hud). Order by the user, 2026-11-02.
build_hud_menu(root)
{
	label = "HUD";
	if(isDefined(level.mode.timer)) label = "HUD & Timer";
	hud = add_submenu(root, "HUD", label);
		self build_timer_menu(hud);
		add_cfg_toggle(hud, "Zombies Spawned", "hud_spawned");
		add_cfg_toggle(hud, "Zombies Remaining", "hud_remaning");
		create_option(hud, "Speedometer: " + cfgint_compare("hud_speed"), ::cfg_toggle_speedometer);
		if(isDefined(level.practice_map.build_hud_top))
			self [[ level.practice_map.build_hud_top ]](hud);
		oopa = array("^3off", "^2on");
		if(isDefined(level.practice_map.oopa_hud_spot_label)) oopa[2] = "^3" + level.practice_map.oopa_hud_spot_label;
		add_cfg_choice(hud, "OOPA Countdown", "hud_oopa", oopa);
		add_cfg_choice(hud, "Point Drops", "hud_points", array("^3off", "^3relative", "^3absolute"));
		add_cfg_toggle(hud, "Health Bar", "hud_health");
		add_cfg_toggle(hud, "Current Zone", "hud_zone");
		add_cfg_toggle(hud, "Active Zones", "hud_active_zones");
	if(isDefined(level.practice_map.build_hud))
		self [[ level.practice_map.build_hud ]](hud);
	// Always the last row (user, 2026-11-02).
	create_option(hud, "Active Trigger: " + cfgint_compare("hud_unitrigger"), ::basegame_toggle_unitrigger_hud);
}

// Core rows, then the map's rows (level.practice_map.build_cheats).
build_cheats_menu(root)
{
	cheats = add_submenu(root, "cheats", "Cheats");
		add_cfg_toggle(cheats, "OOPA Death", "oopa");
		create_option(cheats, "Demigod: " + int_compare(self.demigod), ::toggle_demigod);
		drops = add_submenu(cheats, "drops", "Give Drop");
			add_drop_option(drops, "Nuke", "nuke");
			add_drop_option(drops, "Max Ammo", "full_ammo");
			add_drop_option(drops, "Double Points", "double_points");
			add_drop_option(drops, "Insta-Kill", "insta_kill");
			add_drop_option(drops, "Zombie Blood", "zombie_blood");
			add_drop_option(drops, "Fire Sale", "fire_sale");
			add_drop_option(drops, "Blood Money", "bonus_points_player");
		create_option(cheats, "PaP Weapon", ::upgrade_weapon);
		create_option(cheats, "Max Points", ::set_points, 1000000);
		create_option(cheats, "Open Doors", ::open_all_doors);
	if(isDefined(level.practice_map.build_cheats))
		self [[ level.practice_map.build_cheats ]](cheats);
}

// Lists a drop only on maps that have it (Zombie Blood is Origins only).
add_drop_option(menu, label, drop)
{
	if(isDefined(level.zombie_include_powerups[drop]))
		create_option(menu, label, ::give_drop, drop);
}


/*##############################################################################
                              Building menus
##############################################################################*/
// Every menu is a string id. Its options live in parallel arrays indexed by row:
// option_text, option_func, option_arg1 and option_arg2.
create_menu(menu, parent, title)
{
	self.menu.title[menu] = title;
	self.menu.parent[menu] = parent;
	self.menu.cursor[menu] = 0;
	// A rebuild can produce fewer options than last time; drop the old ones.
	self.menu.option_text[menu] = [];
	self.menu.option_func[menu] = [];
	self.menu.option_arg1[menu] = [];
	self.menu.option_arg2[menu] = [];
}

create_option(menu, text, func, arg1, arg2)
{
	index = self.menu.option_text[menu].size;
	self.menu.option_text[menu][index] = text;
	self.menu.option_func[menu][index] = func;
	self.menu.option_arg1[menu][index] = arg1;
	self.menu.option_arg2[menu][index] = arg2;
}

// Adds a ">label" row to parent that opens the new submenu id, and returns id.
// title is the heading shown inside the submenu; it defaults to label.
add_submenu(parent, id, label, title)
{
	if(!isDefined(title)) title = label;
	create_option(parent, ">" + label, ::enter_menu, id);
	create_menu(id, parent, title);
	return id;
}

// A setting switched on and off by selecting it.
add_cfg_toggle(menu, label, key, on_text, off_text)
{
	create_option(menu, label + ": " + cfgint_compare(key, on_text, off_text), ::cfg_toggle_binary, key);
}

// A setting that steps through names; the saved value is the index into names.
add_cfg_choice(menu, label, key, names)
{
	create_option(menu, label + ": ^3" + names[get_cfg_int(key)], ::cfg_increment_int, key, array(0, names.size - 1));
}


/*##############################################################################
                              Settings
##############################################################################*/
// Saves a setting to the cfg that owns it (the mode's, else the base cfg) and
// redraws the menu.
cfg_set_int(setting, value)
{
    if(isDefined(level.mode_cfg) && isDefined(level.mode_cfg[setting]))
        level.mode_cfg[setting] = value;
    else if(isDefined(level.base_cfg))
        level.base_cfg[setting] = value;

    // A held row saves once, on release (menu_hold_steps).
    if(is_true(self.menu.holding_step))
        self.menu.hold_unsaved = setting;
    else
        self cfg_save(setting);

    self refresh_menu();
}

// Writes the cfg that owns the setting.
cfg_save(setting)
{
    if(isDefined(level.mode_cfg) && isDefined(level.mode_cfg[setting]))
        write_config(level.mode_cfg, level.mode_cfg_str);
    else if(isDefined(level.base_cfg))
        write_config(level.base_cfg, level.base_cfg_str);
}

cfg_toggle_binary(setting)
{
    self cfg_set_int(setting, 1 - get_cfg_int(setting));
}

// Steps to the next value in range, wrapping from range[1] back to range[0]. A range
// of MENU_HOLD_VALUES or more also repeats while Enter is held.
cfg_increment_int(setting, range)
{
    if(range[1] - range[0] + 1 >= MENU_HOLD_VALUES) self.menu.step_repeats = true;

    value = get_cfg_int(setting) + 1;
    if(value > range[1]) value = range[0];
    if(value < range[0]) value = range[1];
    self cfg_set_int(setting, value);
}

// cfg_increment_int for a row that repeats while held whatever its range.
cfg_increment_held(setting, range)
{
    self.menu.step_repeats = true;
    self cfg_increment_int(setting, range);
}

/*##############################################################################
                              Menu engine
##############################################################################*/
initialize_menu()
{
	self endon("disconnect");
	level endon("game_ended");

	self.menu = spawnstruct();
	self.menu.root = level.gamemode;
	self.menu.current = self.menu.root;
	self.demigod = 0;
	// What the map loaded with, for Restart to apply (menu_restart_pending).
	if(isDefined(level.mode_cfg) && !isDefined(level.mode_cfg_loaded)) level.mode_cfg_loaded = level.mode_cfg;

	self build_menu_tree();
	self menu_load_state();

	while(true)
	{
		self menu_offhand_guard();
		if(self menu_open()) self menu_clear_actionslots();
		// The game ended its own ignoreme while the menu is open (Zombie Blood ran
		// out): keep ignoring for now, and leave it off on close.
		if(self menu_open() && !is_true(self.ignoreme))
		{
			self.menu.saved_ignoreme = false;
			self.ignoreme = 1;
		}
		// A fresh melee press closes the menu from any depth. It stays on the same
		// row, so opening it again goes back there.
		if(self menu_open())
		{
			melee = self meleebuttonpressed();
			if(melee && !is_true(self.menu.melee_held)) self close_menu();
			self.menu.melee_held = melee;
		}
		if(get_open_buttons() && !isDefined(self.menu.open) && flag("menu_active"))
		{
			self thread open_menu();
			self.menu.melee_held = true; // The open chord's melee does not close it.
			wait .15;
			// The open chord may share a button with the navigation: it acts only
			// once released.
			while(self menu_button_pressed()) wait .05;
		}
		if(self menu_open() && self menu_button_pressed())
		{
			if(self actionslotfourbuttonpressed())
			{
				// Back: return to the parent menu, or close the menu at the top level.
				self menu_disarm();
				parent = self.menu.parent[self.menu.current];
				if(isDefined(parent))
					self enter_menu(parent);
				else
					self thread close_menu();
			}
			else if(self actionslotonebuttonpressed() || self actionslottwobuttonpressed())
			{
				// Up and down pressed together cancel out.
				self.menu.cursor[self.menu.current] += self actionslottwobuttonpressed() - self actionslotonebuttonpressed();
				self menu_disarm();
				self update_scrollbar();
			}
			else if(self actionslotthreebuttonpressed() || self fragbuttonpressed())
			{
				menu = self.menu.current;
				index = self.menu.cursor[menu];
				func = self.menu.option_func[menu][index];
				arg1 = self.menu.option_arg1[menu][index];
				arg2 = self.menu.option_arg2[menu][index];

				// A thread runs at once up to its first wait, so a row that repeats
				// has raised step_repeats by the next line.
				self.menu.step_repeats = undefined;
				self thread [[ func ]](arg1, arg2);
				if(is_true(self.menu.step_repeats)) self menu_hold_steps(func, arg1, arg2);
			}

			// Each press acts once, however long the button is held, unless
			// menu_hold_steps repeated it above.
			while(self menu_button_pressed())
				wait .05;
		}
		wait .05;
	}
}

// Repeats a long row while frag stays held. The rebuild runs every step, but the cfg
// is written once, on release, so a hold does not rewrite the file ten times a second.
menu_hold_steps(func, arg1, arg2)
{
	self.menu.holding_step = true;
	self.menu.hold_unsaved = undefined;
	// getTime runs with timescale (10 during a held setup): the hold keeps real time.
	timescale = float(getdvar("timescale"));
	if(timescale < 1) timescale = 1;
	next_step = getTime() + MENU_HOLD_DELAY * timescale;

	while(self menu_open() && self fragbuttonpressed())
	{
		if(getTime() >= next_step)
		{
			self [[ func ]](arg1, arg2);
			next_step = getTime() + MENU_HOLD_STEP * timescale;
		}
		wait .05;
	}

	self.menu.holding_step = undefined;
	if(isDefined(self.menu.hold_unsaved)) self cfg_save(self.menu.hold_unsaved);
}

// Offhand throws (special and lethal) are blocked while the menu is open, and with
// the special grenade chord also while melee is held, so the chord cannot toss it and
// releasing melee leaves the block on until the menu closes. Only this guard
// re-enables what it disabled. With the equipment chord, holding melee empties the
// equipment slot until it is released, so the chord cannot use the equipment.
menu_offhand_guard()
{
	holding_chord_key = self meleebuttonpressed();
	if(menu_equipment_chord())
	{
		self menu_equipment_slot_guard(holding_chord_key);
		holding_chord_key = false;
	}
	if(self menu_open() || holding_chord_key)
	{
		if(isDefined(self.menu.offhand_blocked)) return;
		self disableoffhandweapons();
		self.menu.offhand_blocked = true;
	}
	else if(isDefined(self.menu.offhand_blocked))
	{
		// A perk drink or last stand holds its own block, and gives it back itself.
		if(!self menu_offhand_held_by_game()) self enableoffhandweapons();
		self.menu.offhand_blocked = undefined;
	}
}

menu_offhand_held_by_game()
{
	if(isDefined(self.is_drinking) && self.is_drinking > 0) return true;
	return self maps\mp\zombies\_zm_laststand::player_is_in_laststand();
}

menu_equipment_slot_guard(melee_held)
{
	if(self menu_open()) return; // The menu empties and restores every slot.
	if(melee_held && !isDefined(self.menu.slot_emptied))
	{
		slot = menu_chord_slot();
		self setactionslot(slot, "");
		self.menu.slot_emptied = slot;
	}
	else if(!melee_held && isDefined(self.menu.slot_emptied))
	{
		self menu_restore_slot(self.menu.slot_emptied);
		self.menu.slot_emptied = undefined;
	}
}

// The navigation buttons are also the game's equipment slots. While the menu is
// open the slots are emptied (the buttons are still read, so navigation works) and
// close_menu hands them back. GSC cannot read a slot, so the restore rebuilds each
// one from the vanilla rule that sets it. Shooting, aiming and movement are untouched.
menu_clear_actionslots()
{
	for(slot = 1; slot <= 4; slot++)
		self setactionslot(slot, "");
}

// Slot 1 and 2, the two the opening chord can use.
menu_restore_slot(slot)
{
	if(slot == 1)
	{
		// The current equipment (shield, turret, drone, gas mask) once picked up again.
		equipment = self get_player_equipment();
		if(isDefined(equipment)) self setactionslot(1, "weapon", equipment);
	}
	else if(slot == 2)
	{
		// Origins Maxis drone, Buried time bomb.
		if(self hasweapon("equip_dieseldrone_zm")) self setactionslot(2, "weapon", "equip_dieseldrone_zm");
		else if(self hasweapon("time_bomb_detonator_zm")) self setactionslot(2, "weapon", "time_bomb_detonator_zm");
		else if(self hasweapon("time_bomb_zm")) self setactionslot(2, "weapon", "time_bomb_zm");
	}
}

menu_restore_actionslots()
{
	self.menu.slot_emptied = undefined;

	// 1: the equipment. 2: Origins Maxis drone, Buried time bomb.
	self menu_restore_slot(1);
	self menu_restore_slot(2);

	// 3: alt mode, or the revive staff when the held weapon has none and it is owned
	// (the rule of Origins watch_staff_usage).
	weapon = self getcurrentweapon();
	upgraded_staff = issubstr(weapon, "staff_") && issubstr(weapon, "_upgraded_zm");
	if(!self hasweapon("staff_revive_zm") || (!upgraded_staff && weapon != "none" && weaponaltweaponname(weapon) != "none"))
		self setactionslot(3, "altmode");
	else
		self setactionslot(3, "weapon", "staff_revive_zm");

	// 4: claymores.
	if(self hasweapon("claymore_zm")) self setactionslot(4, "weapon", "claymore_zm");
}

menu_button_pressed()
{
	return self actionslotonebuttonpressed() || self actionslottwobuttonpressed() || self actionslotthreebuttonpressed() || self actionslotfourbuttonpressed() || self fragbuttonpressed();
}

get_open_buttons()
{
	if(!self meleebuttonpressed()) return false;
	slot = menu_chord_slot();
	if(slot == 1) return self actionslotonebuttonpressed();
	return self secondaryoffhandbuttonpressed();
}

// The Menu Key setting (General Settings): 0 melee + the special grenade opens the
// menu, 1 melee + dpad slot 1 (the shield on Origins). A saved value past 1 counts as 1.
menu_chord_slot()
{
	if(get_cfg_int("menu_key") > 1) return 1;
	return get_cfg_int("menu_key");
}

menu_equipment_chord()
{
	return menu_chord_slot() > 0;
}

// Zombies ignore the player while the menu is open. Closing gives back what the
// game had set, so Zombie Blood and last stand keep theirs.
open_menu()
{
	self.menu.saved_ignoreme = is_true(self.ignoreme);
	self.ignoreme = 1;
	self.menu.open = true;
	self menu_clear_actionslots();
	self draw_menu();
	self refresh_menu();
}

close_menu()
{
	self.ignoreme = self.menu.saved_ignoreme;
	self menu_restore_actionslots();
	self.menu.open = undefined;
	self.menu.armed = undefined;
	self destroy_array(self.menu.hud);
}

menu_open()
{
	return isDefined(self.menu) && isDefined(self.menu.open);
}

enter_menu(menu)
{
	self.menu.current = menu;
	self.menu.hud["SubTitle"] setTextUnlimited(self.menu.title[menu]);
	self update_scrollbar();
}

refresh_menu()
{
	// Rebuilding moves every cursor back to the top; keep where the player was.
	saved_cursor = [];
	foreach(menu in getArrayKeys(self.menu.cursor))
		saved_cursor[menu] = self.menu.cursor[menu];
	self build_menu_tree();
	foreach(menu in getArrayKeys(saved_cursor))
	{
		self.menu.cursor[menu] = saved_cursor[menu];
		// A list that got shorter keeps the cursor on its last row.
		if(isDefined(self.menu.option_text[menu]) && self.menu.option_text[menu].size > 0 && saved_cursor[menu] >= self.menu.option_text[menu].size)
			self.menu.cursor[menu] = self.menu.option_text[menu].size - 1;
	}
	if(self menu_open())
		self update_scrollbar();
}

// A mode setting differs from what the map loaded with.
menu_restart_pending()
{
	if(!isDefined(level.mode_cfg) || !isDefined(level.mode_cfg_loaded)) return false;
	foreach(key in getArrayKeys(level.mode_cfg))
		if(!menu_cfg_applies_live(key) && (!isDefined(level.mode_cfg_loaded[key]) || "" + level.mode_cfg[key] != "" + level.mode_cfg_loaded[key])) return true;
	return false;
}

// Mode settings that take effect at once, named by the map (live_cfg_keys).
menu_cfg_applies_live(key)
{
	if(key == "timer_main" || key == "timer_segment") return true;
	if(!isDefined(level.practice_map.live_cfg_keys)) return false;
	foreach(live_key in level.practice_map.live_cfg_keys)
		if(live_key == key) return true;
	return false;
}

// The open menu and every row kept in a dvar, so they survive map_restart.
menu_state_dvar()
{
	return level.practice_map.mode_dvar + "_state";
}

menu_save_state()
{
	state = level.gamemode + "|" + self.menu.current + "|";
	foreach(menu in getArrayKeys(self.menu.cursor))
		if(self.menu.cursor[menu] > 0) state += menu + "=" + self.menu.cursor[menu] + ",";
	setDvar(menu_state_dvar(), state);
}

menu_load_state()
{
	parts = strtok(getDvar(menu_state_dvar()), "|");
	if(parts.size < 2 || parts[0] != level.gamemode) return;
	if(isDefined(self.menu.option_text[parts[1]]) && self.menu.option_text[parts[1]].size > 0) self.menu.current = parts[1];
	if(parts.size < 3) return;
	foreach(pair in strtok(parts[2], ","))
	{
		entry = strtok(pair, "=");
		if(entry.size == 2 && isDefined(self.menu.cursor[entry[0]])) self.menu.cursor[entry[0]] = int(entry[1]);
	}
}

// Adds " [tag]" to the row that opens menu.
set_menu_tag(menu, tag)
{
	parent = self.menu.parent[menu];
	for(row = 0; row < self.menu.option_text[parent].size; row++)
		if(self.menu.option_func[parent][row] == ::enter_menu && self.menu.option_arg1[parent][row] == menu)
			self.menu.option_text[parent][row] += " ^9[^3" + tag + "^9]";
}

// The game draws only so many HUD elements, and the player's own HUDs share them:
// past the limit, rows and bars go missing (live 2026-11-05, at 36 here). The menu
// stays at 12. So all rows are one text, and a frame is 2 elements, an accent rectangle
// under a solid black one. Count before adding one.
menu_draw_frame(name, left, right, top, bottom)
{
	x = (left + right) / 2;
	y = (top + bottom) / 2;
	// Whole numbers: the macros divide, and a shader size must be an int.
	width = int(right - left);
	height = int(bottom - top);
	self.menu.hud[name + "Edge"] = self create_rectangle(x, y, width + MENU_BORDER, height + MENU_BORDER, level.practice_map.accent_color, "white", 0, 1);
	self.menu.hud[name + "Back"] = self create_rectangle(x, y, width - MENU_BORDER, height - MENU_BORDER, MENU_BACKGROUND_COLOR, "white", 1, 1);
}

draw_menu()
{
	// One frame holds the header and the rows, a second the controls.
	self menu_draw_frame("Help", MENU_LEFT, MENU_LEFT + MENU_HELP_WIDTH, MENU_BOTTOM + MENU_HELP_GAP, MENU_BOTTOM + MENU_HELP_GAP + MENU_HELP_HEIGHT);
	self menu_draw_frame("Panel", MENU_LEFT, MENU_RIGHT, MENU_HEADER_Y - MENU_HEADER_HEIGHT / 2, MENU_BOTTOM - MENU_BORDER / 2);
	self.menu.hud["Cursor"] = self create_rectangle(MENU_X, MENU_FIRST_ROW_Y, MENU_WIDTH - MENU_BORDER, MENU_CURSOR_HEIGHT, level.practice_map.cursor_color, "white", 2, MENU_CURSOR_ALPHA);
	self.menu.hud["Header"] = self create_rectangle(MENU_X, MENU_HEADER_Y, MENU_WIDTH + MENU_BORDER, MENU_HEADER_HEIGHT, level.practice_map.accent_color, "white", 5, 1);

	self.menu.hud["Title"] = self create_text(level.menu_title, "default", 1.4, "LEFT", MENU_LEFT + 4, MENU_HEADER_TEXT_Y, 1);
	self.menu.hud["Title"].color = level.practice_map.header_text_color;

	// Right-aligned so a long submenu title never runs into the main title. Same font
	// and size as the title: the big font is taller than the header and hung into the rows.
	self.menu.hud["SubTitle"] = self create_text(self.menu.title[self.menu.current], "default", 1.4, "RIGHT", MENU_RIGHT - 4, MENU_HEADER_TEXT_Y, 0);
	self.menu.hud["SubTitle"].color = level.practice_map.header_text_color;
	self.menu.hud["SubTitle"] thread hud_fade(1, .1);

	self.menu.hud["Help"] = self create_text("^7HOLD [^3[{+frag}]^7] REPEAT\n^7UP/DOWN [^3[{+actionslot 1}]^7]/[^3[{+actionslot 2}]^7]\n^7SELECT/EXIT [^3[{+actionslot 3}]^7]/[^3[{+actionslot 4}]^7]\n^7CLOSE [^3[{+melee}]^7]\n^3\"help\" ^7IN CHAT", "small", 1.2, "TOPLEFT", MENU_LEFT + 5, MENU_BOTTOM + MENU_HELP_GAP + 5, 1);
	// The map's emblem, right of the controls.
	if(isDefined(level.practice_map.menu_icon))
		self.menu.hud["Icon"] = self create_rectangle(MENU_RIGHT - MENU_ICON_SIZE / 2 - 10, MENU_BOTTOM + MENU_HELP_GAP + MENU_HELP_HEIGHT / 2, MENU_ICON_SIZE, MENU_ICON_SIZE, MENU_TEXT_COLOR, level.practice_map.menu_icon, 6, 1);

	self.menu.hud["Rows"] = self create_text("", "objective", 1.4, "TOPLEFT", MENU_LEFT + 7, MENU_FIRST_ROW_Y - MENU_ROW_SPACING / 2, 1);

	// "5/13" on a list longer than the visible rows, in the last row's right corner.
	self.menu.hud["Position"] = self create_text("", "small", 1.2, "RIGHT", MENU_RIGHT - 6, MENU_FIRST_ROW_Y + (MENU_ROWS - 1) * MENU_ROW_SPACING, 1);
}

update_scrollbar()
{
	menu = self.menu.current;
	count = self.menu.option_text[menu].size;

	// Wrap the cursor around either end.
	if(self.menu.cursor[menu] < 0) self.menu.cursor[menu] = count - 1;
	if(self.menu.cursor[menu] > count - 1) self.menu.cursor[menu] = 0;
	cursor = self.menu.cursor[menu];

	// Keep the cursor in the middle row without scrolling past either end of the list.
	first = cursor - int(MENU_ROWS / 2);
	if(first > count - MENU_ROWS) first = count - MENU_ROWS;
	if(first < 0) first = 0;

	// One text for all rows. ^7 each line: a colour carries over the newline.
	text = "";
	percents = 0;
	for(row = 0; row < MENU_ROWS; row++)
	{
		index = first + row;
		if(isDefined(self.menu.option_text[menu][index]))
		{
			line = self.menu.option_text[menu][index];
			if(menu_row_has_percent(line))
			{
				self menu_show_percent(percents, row, int(getsubstr(line, 0, 1)));
				percents++;
				line = MENU_PERCENT_PAD + getsubstr(line, 2, line.size);
			}
			text += "^7" + line;
		}
		text += "\n";

		if(index == cursor && isDefined(self.menu.hud["Cursor"]))
			self.menu.hud["Cursor"] setPoint("CENTER", "CENTER", MENU_X, MENU_FIRST_ROW_Y + row * MENU_ROW_SPACING);
	}
	if(isDefined(self.menu.hud["Rows"])) self.menu.hud["Rows"] setTextUnlimited(text);
	self menu_hide_percents(percents);

	self menu_save_state();
	if(!isDefined(self.menu.hud["Position"])) return;

	position = "";
	if(count > MENU_ROWS) position = "^3" + (cursor + 1) + "/" + count;
	self.menu.hud["Position"] setTextUnlimited(position);

	// The title makes way for the note: no element of its own.
	title = level.menu_title;
	if(menu_restart_pending()) title = "Restart to apply";
	self.menu.hud["Title"] setTextUnlimited(title);
}

// "3% Drops": one digit, then the percent sign.
menu_row_has_percent(line)
{
	return line.size > 1 && getsubstr(line, 1, 2) == "%";
}

// The slot-th percent on screen, on row, showing value.
menu_show_percent(slot, row, value)
{
	key = "Percent" + slot;
	if(!isDefined(self.menu.hud[key]))
	{
		hud = self createFontString("objective", 1.4);
		hud.color = MENU_TEXT_COLOR;
		hud.hidewheninmenu = 1;
		hud.sort = 10;
		hud.foreground = true;
		hud.label = &"MPUI_PERCENT";
		self.menu.hud[key] = hud;
	}
	self.menu.hud[key] setPoint("TOPLEFT", "CENTER", MENU_LEFT + 7, MENU_FIRST_ROW_Y - MENU_ROW_SPACING / 2 + row * MENU_ROW_SPACING);
	self.menu.hud[key] setValue(value);
	self.menu.hud[key].alpha = 1;
}

// Percents from slot first on are not on screen now.
menu_hide_percents(first)
{
	for(slot = first; slot < MENU_ROWS; slot++)
		if(isDefined(self.menu.hud["Percent" + slot])) self.menu.hud["Percent" + slot].alpha = 0;
}

// Menu text, positioned from the screen center.
create_text(text, font, scale, align, x, y, alpha)
{
	hud = self createFontString(font, scale);
	hud setPoint(align, "CENTER", x, y);
	hud.color = MENU_TEXT_COLOR;
	hud.alpha = alpha;
	hud.hidewheninmenu = 1;
	hud.sort = 10;
	hud.foreground = true;
	hud setTextUnlimited(text);
	return hud;
}

// A rectangle centered on (x, y) that fades in to alpha.
create_rectangle(x, y, width, height, color, shader, sort, alpha)
{
	hud = self createIcon(shader, width, height);
	hud.sort = sort;
	hud.color = color;
	hud.alpha = 0;
	hud.hidewheninmenu = 1;
	hud.foreground = true;
	hud setPoint("CENTER", "CENTER", x, y);
	hud thread hud_fade(alpha, .1);
	return hud;
}

hud_fade(alpha, time)
{
	self fadeOverTime(time);
	self.alpha = alpha;
	wait time;
}

/*##############################################################################
                              Menu actions
##############################################################################*/
menu_not_implemented()
{
	self iprintln("Not implemented");
}

gamemode_live_tag( mode )
{
	if(level.gamemode == mode)
		return "^9[^3live^9]";
	else
		return "";
}

fast_quit()
{
    KillServer();
}

toggle_demigod()
{
    if(!self.demigod)
    {
        self.demigod = 1;
        self thread demi_god();
    }
    else
    {
        self notify("disable_godmode");
        self.demigod = 0;

        max_health = 100;
        if(self hasperk("specialty_armorvest"))
            max_health = level.zombie_vars["zombie_perk_juggernaut_health"];
        // As vanilla perk_set_max_health_if_jugg, or demigod would cost the Juggernog permaperk.
        if(self maps\mp\zombies\_zm_pers_upgrades_functions::pers_jugg_active())
            max_health += level.pers_jugg_upgrade_health_bonus;
        self setmaxhealth(max_health);
        self.health = max_health;
    }
    self refresh_menu();
}
