#include maps\mp\_utility;
#include common_scripts\utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;

/*##############################################################################
                              Save slots
##############################################################################*/
// Every mode with a settings menu has SAVESLOT_COUNT saved copies of its
// settings, one cfg file each next to the mode's own (O_PRAC/prewind_slot1.cfg).
// A slot file holds the mode cfg's keys plus slot_name, the name given in chat.
// A slot that holds no setting is empty, even when it has a name.
//
// Only the mode cfg is saved. The HUD and general settings in basegame.cfg are
// shared by every mode and stay as they are. Loading lays the slot over the mode's
// defaults (a setting added after the save keeps its default), saves that as the
// mode cfg and restarts the map, so every setting applies.
//
// Slot 1 starts with the mode's defaults, called Default, unless the mode fills it
// itself (Fullgame's Normal 29 RNG). Restore Defaults puts it back.
//
// A slot's row is green with a star while the mode's settings match that slot, so it
// shows what is loaded and goes the moment a setting changes (user, 2026-11-06).
//
// Chat "slot <n> <name>" names slot n of the current mode, "slot <n>" clears it.
#define SAVESLOT_COUNT      4
#define SAVESLOT_NAME_MAX   16  // Longer names run past the menu's right edge.
#define SAVESLOT_DEFAULT_NAME   "Default"

// ">Slot n" rows of Presets, above Restore Defaults.
add_saveslots_menu()
{
	if(!saveslots_available()) return;
	if(!saveslot_has_settings(saveslot_get(1))) saveslot_put_default();
	for(slot = 1; slot <= SAVESLOT_COUNT; slot++)
	{
		saved = saveslot_get(slot);
		label = "Slot " + slot;
		name = saveslot_name(saved);
		if(name != "") label += ": " + name;
		if(!saveslot_has_settings(saved)) label += " ^9(empty)";
		else if(saveslot_is_active(saved)) label = "^2" + label + " *^7";

		menu = add_submenu("presets", "saveslot" + slot, label, "Slot " + slot);
			create_option(menu, "Load & Restart", ::saveslot_load, slot);
			if(saveslot_has_settings(saved))
				create_confirm_option(menu, "Save Settings", "Confirm Overwrite", ::saveslot_save, slot);
			else
				create_option(menu, "Save Settings", ::saveslot_save, slot);
			create_option(menu, "Rename (Chat)", ::saveslot_rename_help, slot);
	}
}

// Modes without a Settings menu have nothing to save. A map or a mode can turn slots
// off (no_slots), which hides Presets.
saveslots_available()
{
	if(is_true(level.mode.no_slots) || is_true(level.practice_map.no_slots)) return false;
	return isDefined(level.mode_cfg_str) && isDefined(self.menu) && isDefined(self.menu.option_text["mapsettings"]);
}

// "O_PRAC/prewind.cfg" gives "O_PRAC/prewind_slot1.cfg".
saveslot_file(slot)
{
	base = level.mode_cfg_str;
	return getsubstr(base, 0, base.size - 4) + "_slot" + slot + ".cfg";
}

// Read from the file every time: the file is the only copy, so the menu, Load
// and a chat rename always see the same slot (a copy kept per map load showed a
// renamed and saved slot as empty, user 2026-11-02).
saveslot_get(slot)
{
	saved = [];
	file = saveslot_file(slot);
	if(fs_testfile(file)) saved = read_config(file);
	return saved;
}

// A slot with neither settings nor a name has no file.
saveslot_put(slot, saved)
{
	if(!saveslot_has_settings(saved) && saveslot_name(saved) == "")
		fs_remove(saveslot_file(slot));
	else
		write_config(saved, saveslot_file(slot));
}

// The mode's defaults into slot 1.
saveslot_put_default()
{
	saved = level.mode_cfg_defaults;
	saved["slot_name"] = SAVESLOT_DEFAULT_NAME;
	saveslot_put(1, saved);
}

// Whether the mode's settings are what loading this slot gives: the slot over the
// defaults. Keys only an old file holds do not count.
saveslot_is_active(saved)
{
	foreach(key in getarraykeys(level.mode_cfg_defaults))
	{
		value = level.mode_cfg_defaults[key];
		if(isDefined(saved[key])) value = saved[key];
		if("" + value != "" + level.mode_cfg[key]) return false;
	}
	return true;
}

saveslot_name(saved)
{
	if(isDefined(saved["slot_name"])) return saved["slot_name"];
	return "";
}

saveslot_has_settings(saved)
{
	foreach(key in getarraykeys(saved))
		if(key != "slot_name") return true;
	return false;
}

// "Slot 2" or "Slot 2 (Wind fast)", for messages.
saveslot_title(slot)
{
	name = saveslot_name(saveslot_get(slot));
	if(name == "") return "Slot " + slot;
	return "Slot " + slot + " (" + name + ")";
}

// Overwriting a slot that holds settings asks once (leaving the row cancels it).
saveslot_save(slot)
{
	name = saveslot_name(saveslot_get(slot));
	saved = [];
	foreach(key in getarraykeys(level.mode_cfg))
		saved[key] = level.mode_cfg[key];
	saved["slot_name"] = name;
	saveslot_put(slot, saved);
	self iprintln(level.mode.label + " settings saved to " + saveslot_title(slot));
	self refresh_menu();
}

saveslot_load(slot)
{
	saved = saveslot_get(slot);
	if(!saveslot_has_settings(saved))
	{
		self iprintln(saveslot_title(slot) + " is empty");
		return;
	}

	cfg = level.mode_cfg_defaults;
	foreach(key in getarraykeys(saved))
		if(key != "slot_name") cfg[key] = saved[key];
	level.mode_cfg = cfg;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self set_gamemode(level.gamemode);
}

saveslot_rename_help(slot)
{
	self iprintln("Type in chat: ^3slot " + slot + " <name>^7 (up to " + SAVESLOT_NAME_MAX + " characters)");
	self iprintln("^3slot " + slot + "^7 alone clears the name");
}

// Chat "slot <n> <name>". Gets the message as typed, so the name keeps its case.
// Returns whether the message was this command.
saveslot_say_command(message)
{
	words = strtok(message, " ");
	if(!words.size) return false;
	command = tolower(words[0]);
	if(command != "slot" && command != "save" && command != "load") return false;
	if(!self saveslots_available())
	{
		self iprintln(level.mode.label + " has no save slots");
		return true;
	}
	if(words.size < 2)
	{
		self saveslot_say_usage(command);
		return true;
	}

	// "load <name>" finds the slot by its name.
	if(command == "load")
	{
		slot = saveslot_find(saveslot_words_name(words, 1));
		if(slot == 0) slot = saveslot_number(words[1]);
		if(slot == 0) self saveslot_say_usage(command);
		else self saveslot_load(slot);
		return true;
	}

	slot = saveslot_number(words[1]);
	if(slot == 0)
	{
		self saveslot_say_usage(command);
		return true;
	}
	name = saveslot_words_name(words, 2);
	if(command == "save")
	{
		self saveslot_save(slot);
		if(name == "") return true;
	}

	saved = saveslot_get(slot);
	saved["slot_name"] = name;
	saveslot_put(slot, saved);
	if(name == "") self iprintln(level.mode.label + " Slot " + slot + " name cleared");
	else self iprintln(level.mode.label + " Slot " + slot + " renamed to " + name);
	self refresh_menu();
	return true;
}

saveslot_say_usage(command)
{
	switch(command)
	{
		case "save":
			self iprintln("^3save <1-" + SAVESLOT_COUNT + "> <name>^7: saves to that slot, the name is optional");
			break;
		case "load":
			self iprintln("^3load <1-" + SAVESLOT_COUNT + " or name>^7: loads that slot and restarts");
			break;
		default:
			self iprintln("^3slot <1-" + SAVESLOT_COUNT + "> <name>^7: renames that slot, no name clears it");
			break;
	}
}

// The slot number word says, or 0.
saveslot_number(word)
{
	slot = int(word);
	if(word != "" + slot || slot < 1 || slot > SAVESLOT_COUNT) return 0;
	return slot;
}

// The slot called name, or 0.
saveslot_find(name)
{
	for(slot = 1; slot <= SAVESLOT_COUNT; slot++)
		if(name != "" && tolower(saveslot_name(saveslot_get(slot))) == tolower(name)) return slot;
	return 0;
}

// Words from first on, joined by single spaces, without the characters that break
// the cfg format (=) or colour the menu (^), cut to SAVESLOT_NAME_MAX.
saveslot_words_name(words, first)
{
	name = "";
	for(i = first; i < words.size; i++)
	{
		word = saveslot_clean_word(words[i]);
		if(word == "") continue;
		if(name != "") name += " ";
		name += word;
	}
	if(name.size > SAVESLOT_NAME_MAX) name = getsubstr(name, 0, SAVESLOT_NAME_MAX);
	if(name.size > 0 && getsubstr(name, name.size - 1, name.size) == " ") name = getsubstr(name, 0, name.size - 1);
	return name;
}

saveslot_clean_word(word)
{
	clean = "";
	for(i = 0; i < word.size; i++)
	{
		c = getsubstr(word, i, i + 1);
		if(c != "=" && c != "^") clean += c;
	}
	return clean;
}
