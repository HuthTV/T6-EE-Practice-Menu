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
#define MENU_Y              -15     // Top edge -125, under the header; bottom edge 95.
#define MENU_WIDTH          208
#define MENU_HEIGHT         220     // Last row (77) plus the same margin as the first row.
#define MENU_BORDER         2
#define MENU_LEFT           (MENU_X - MENU_WIDTH / 2)
#define MENU_RIGHT          (MENU_X + MENU_WIDTH / 2)
#define MENU_BOTTOM         (MENU_Y + MENU_HEIGHT / 2)
#define MENU_HEADER_Y       -131
#define MENU_HEADER_HEIGHT  18

#define MENU_ROWS           9
#define MENU_FIRST_ROW_Y    -107
#define MENU_ROW_SPACING    23
#define MENU_ARROW_OVERLAP  1.5     // How far each slash of a scroll arrow reaches past the centre.

// Holding Enter on a long row
#define MENU_HOLD_VALUES    10      // A row with this many values or more repeats.
#define MENU_HOLD_DELAY     400     // Milliseconds held before the first repeat.
#define MENU_HOLD_STEP      100     // Milliseconds between repeats.

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
	return array("gamemodes", "mapsettings", "loadout", "puzzles", "special_ai", "randomness", "victis", "HUD", "cheats", "presets", "general");
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
	for(i = 0; i < level.modes.size; i++)
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
	// Short: a long row runs past the menu's right edge.
	if(is_true(self.menu.restore_armed))
		create_option("presets", "^1Confirm Restore Defaults", ::restore_mode_defaults);
	else
		create_option("presets", "Restore " + level.mode.label + " Defaults", ::restore_mode_defaults);
}

// Leaving the row (cursor move, back) cancels a pending "Confirm Restore" or a
// save slot's "Confirm Overwrite".
disarm_restore()
{
	if(!is_true(self.menu.restore_armed) && !isDefined(self.menu.saveslot_armed)) return;
	self.menu.restore_armed = undefined;
	self.menu.saveslot_armed = undefined;
	self refresh_menu();
}

restore_mode_defaults()
{
	if(!is_true(self.menu.restore_armed))
	{
		self.menu.restore_armed = true;
		self refresh_menu();
		return;
	}
	self.menu.restore_armed = undefined;
	fs_remove(level.mode_cfg_str);
	level.mode_cfg = level.mode_cfg_defaults;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self iprintln(level.mode.label + " settings restored to default");
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
	if(getdvar("mapname") == map) label += " ^9[^3live^9]";
	create_option(menu, label, ::change_map, map, location);
}

change_map(map, location)
{
	if(!self ishost())
	{
		self iprintln("Only the host can change the map");
		return;
	}
	self iprintln("Loading " + map + "...");
	cmdexec("zmmap " + map + " " + location + " zclassic");
}

// Options every mode has. Anything mode specific goes in the modes own menu.
build_general_menu(root)
{
	general = add_submenu(root, "general", "General");
		self build_change_map_menu(general);
		create_option(general, "Show Identifier/Hashes: " + cfgint_compare("show_identifier"), ::basegame_toggle_show_identifier);
		add_cfg_choice(general, "Menu Key (with melee)", "menu_key", array("special grenade", "dpad slot 1"));
		create_option(general, "Rage Quit", ::fast_quit);
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
		oopa = array("^1off", "^2on");
		if(isDefined(level.practice_map.oopa_hud_spot_label)) oopa[2] = "^3" + level.practice_map.oopa_hud_spot_label;
		add_cfg_choice(hud, "OOPA Countdown", "hud_oopa", oopa);
		add_cfg_choice(hud, "Point based", "hud_points", array("^1off", "^3relative", "^3absolute"));
		add_cfg_toggle(hud, "Health Bar", "hud_health");
		add_cfg_toggle(hud, "Current Zone", "hud_zone");
		add_cfg_toggle(hud, "Active Zones", "hud_active_zones");
	if(isDefined(level.practice_map.build_hud))
		self [[ level.practice_map.build_hud ]](hud);
	// Always the last row (user, 2026-11-02).
	create_option(hud, "Active unit trigger: " + cfgint_compare("hud_unitrigger"), ::basegame_toggle_unitrigger_hud);
}

// Core rows, then the map's rows (level.practice_map.build_cheats).
build_cheats_menu(root)
{
	cheats = add_submenu(root, "cheats", "Cheats");
		add_cfg_toggle(cheats, "OOPA Death", "oopa");
		create_option(cheats, "Demigod: " + int_compare(self.demigod), ::toggle_demigod);
		drops = add_submenu(cheats, "drops", "Give drop");
			add_drop_option(drops, "Nuke", "nuke");
			add_drop_option(drops, "Max Ammo", "full_ammo");
			add_drop_option(drops, "Double Points", "double_points");
			add_drop_option(drops, "Insta kill", "insta_kill");
			add_drop_option(drops, "Zombie Blood", "zombie_blood");
			add_drop_option(drops, "Fire Sale", "fire_sale");
			add_drop_option(drops, "Blood Money", "bonus_points_player");
		create_option(cheats, "Pap weapon", ::upgrade_weapon);
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

	self build_menu_tree();

	while(true)
	{
		self menu_offhand_guard();
		if(self menu_open()) self menu_clear_actionslots();
		if(get_open_buttons() && !isDefined(self.menu.open) && flag("menu_active"))
		{
			self thread open_menu();
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
				self disarm_restore();
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
				self disarm_restore();
				self update_scrollbar();
			}
			else if(self actionslotthreebuttonpressed())
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

// Repeats a long row while Enter stays held. The rebuild runs every step, but the cfg
// is written once, on release, so a hold does not rewrite the file ten times a second.
menu_hold_steps(func, arg1, arg2)
{
	self.menu.holding_step = true;
	self.menu.hold_unsaved = undefined;
	next_step = getTime() + MENU_HOLD_DELAY;

	while(self menu_open() && self actionslotthreebuttonpressed())
	{
		if(getTime() >= next_step)
		{
			self [[ func ]](arg1, arg2);
			next_step = getTime() + MENU_HOLD_STEP;
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
		self enableoffhandweapons();
		self.menu.offhand_blocked = undefined;
	}
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
	return self actionslotonebuttonpressed() || self actionslottwobuttonpressed() || self actionslotthreebuttonpressed() || self actionslotfourbuttonpressed();
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

open_menu()
{
	self.ignoreme = 1;
	self.menu.open = true;
	self menu_clear_actionslots();
	self draw_menu();
	self refresh_menu();
}

close_menu()
{
	self.ignoreme = 0;
	self menu_restore_actionslots();
	self.menu.open = undefined;
	self.menu.restore_armed = undefined;
	self.menu.saveslot_armed = undefined;
	self destroy_array(self.menu.hud);
	for(row = 0; row < self.menu.rows.size; row++)
		self.menu.rows[row] destroy();
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
		self.menu.cursor[menu] = saved_cursor[menu];
	if(self menu_open())
		self update_scrollbar();
}

draw_menu()
{
	self.menu.hud["Background"] = self create_rectangle(MENU_X, MENU_Y, MENU_WIDTH, MENU_HEIGHT, MENU_BACKGROUND_COLOR, "lui_soldier", 0, .5);
	self.menu.hud["Leftline"] = self create_rectangle(MENU_LEFT, MENU_Y, MENU_BORDER, MENU_HEIGHT, level.practice_map.accent_color, "white", 5, 1);
	self.menu.hud["Rightline"] = self create_rectangle(MENU_RIGHT, MENU_Y, MENU_BORDER, MENU_HEIGHT, level.practice_map.accent_color, "white", 5, 1);
	self.menu.hud["Bottomline"] = self create_rectangle(MENU_X, MENU_BOTTOM - MENU_BORDER / 2, MENU_WIDTH, MENU_BORDER, level.practice_map.accent_color, "white", 5, 1);
	// Header bar, wide enough to cover both side borders.
	self.menu.hud["Topline"] = self create_rectangle(MENU_X, MENU_HEADER_Y, MENU_WIDTH + MENU_BORDER, MENU_HEADER_HEIGHT, level.practice_map.accent_color, "white", 5, 1);

	self.menu.hud["Title"] = self create_text(level.menu_title, "default", 1.4, "LEFT", MENU_LEFT + 4, MENU_HEADER_Y + 1, 1);
	self.menu.hud["Title"].glowAlpha = 1;
	self.menu.hud["Title"].glowColor = level.practice_map.accent_color;

	// Right-aligned so a long submenu title never runs into the main title.
	self.menu.hud["SubTitle"] = self create_text(self.menu.title[self.menu.current], "big", 1.5, "RIGHT", MENU_RIGHT - 4, MENU_HEADER_Y + 1, 0);
	self.menu.hud["SubTitle"] thread hud_fade(1, .1);

	// Controls, under the window and aligned with its left edge (two lines).
	self.menu.hud["Help"] = self create_text("^7UP/DOWN ^3[{+actionslot 1}]/[{+actionslot 2}]\n^7ENTER/EXIT ^3[{+actionslot 3}]/[{+actionslot 4}]", "small", 1.4, "TOPLEFT", MENU_LEFT, MENU_BOTTOM + 4, 1);

	for(row = 0; row < MENU_ROWS; row++)
		self.menu.rows[row] = self create_text("", "small", 1.4, "LEFT", MENU_LEFT + 7, MENU_FIRST_ROW_Y + row * MENU_ROW_SPACING, 1);

	// More options above or below the visible rows, on the first and last row
	// lines (update_scrollbar shows them).
	self.menu.hud["MoreUp"] = self create_arrow(MENU_RIGHT - 12, MENU_FIRST_ROW_Y, true);
	self.menu.hud["MoreDown"] = self create_arrow(MENU_RIGHT - 12, MENU_FIRST_ROW_Y + (MENU_ROWS - 1) * MENU_ROW_SPACING, false);
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

	for(row = 0; row < MENU_ROWS; row++)
	{
		index = first + row;
		text = "";
		if(isDefined(self.menu.option_text[menu][index])) text = self.menu.option_text[menu][index];
		self.menu.rows[row] setTextUnlimited(text);

		if(index == cursor) self.menu.rows[row].color = level.practice_map.accent_color;
		else self.menu.rows[row].color = MENU_TEXT_COLOR;
	}

	if(!isDefined(self.menu.hud["MoreUp"])) return;
	foreach(bar in self.menu.hud["MoreUp"]) bar.alpha = int(first > 0);
	foreach(bar in self.menu.hud["MoreDown"]) bar.alpha = int(first + MENU_ROWS < count);
}

// A "/\" or "\/" arrow centred on (x, y). Typed as one string the font's spacing
// leaves a gap at the point, so each slash is its own text piece, pushed together
// by MENU_ARROW_OVERLAP until the strokes meet. Returns both halves
// (destroy_array handles arrays).
create_arrow(x, y, pointing_up)
{
	left = "/";
	right = "\\";
	if(!pointing_up)
	{
		left = "\\";
		right = "/";
	}
	halves = [];
	halves[0] = self create_text(left, "small", 1.2, "RIGHT", x + MENU_ARROW_OVERLAP, y, 0);
	halves[1] = self create_text(right, "small", 1.2, "LEFT", x - MENU_ARROW_OVERLAP, y, 0);
	return halves;
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
        self setmaxhealth(max_health);
        self.health = max_health;
    }
    self refresh_menu();
}
