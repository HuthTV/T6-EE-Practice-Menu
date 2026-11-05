#include maps\mp\_utility;
#include common_scripts\utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;

/*##############################################################################
                              Save slots
##############################################################################*/
// Every mode with a "<mode> Settings" menu has SAVESLOT_COUNT saved copies of its
// settings, one cfg file each next to the mode's own (O_PRAC/prewind_slot1.cfg).
// A slot file holds the mode cfg's keys plus slot_name, the name given in chat.
// A slot that holds no setting is empty, even when it has a name.
//
// Only the mode cfg is saved. The HUD and general settings in basegame.cfg are
// shared by every mode and stay as they are. Loading lays the slot over the mode's
// defaults (a setting added after the save keeps its default), saves that as the
// mode cfg and restarts the map, so every setting applies.
//
// Chat "slot <n> <name>" names slot n of the current mode, "slot <n>" clears it.
#define SAVESLOT_COUNT      4
#define SAVESLOT_NAME_MAX   16  // Longer names run past the menu's right edge.

// ">Save Slots" row of the mode's Settings, above Restore Defaults.
add_saveslots_menu()
{
	if(!saveslots_available()) return;
	slots = add_submenu("mapsettings", "saveslots", "Save Slots");
	for(slot = 1; slot <= SAVESLOT_COUNT; slot++)
	{
		saved = saveslot_get(slot);
		label = "Slot " + slot;
		name = saveslot_name(saved);
		if(name != "") label += ": " + name;
		if(!saveslot_has_settings(saved)) label += " ^9(empty)";

		menu = add_submenu(slots, "saveslot" + slot, label, "Slot " + slot);
			create_option(menu, "Load and Restart", ::saveslot_load, slot);
			if(isDefined(self.menu.saveslot_armed) && self.menu.saveslot_armed == slot)
				create_option(menu, "^1Confirm Overwrite", ::saveslot_save, slot);
			else
				create_option(menu, "Save Current Settings", ::saveslot_save, slot);
			create_option(menu, "Rename (chat)", ::saveslot_rename_help, slot);
	}
}

// Modes without a Settings menu (the skeleton Freeroams) have nothing to save.
saveslots_available()
{
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
	saved = saveslot_get(slot);
	armed = isDefined(self.menu.saveslot_armed) && self.menu.saveslot_armed == slot;
	if(saveslot_has_settings(saved) && !armed)
	{
		self.menu.saveslot_armed = slot;
		self refresh_menu();
		return;
	}
	self.menu.saveslot_armed = undefined;

	name = saveslot_name(saved);
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
	if(words.size < 2 || tolower(words[0]) != "slot") return false;
	if(!self saveslots_available())
	{
		self iprintln(level.mode.label + " has no save slots");
		return true;
	}
	slot = int(words[1]);
	if(words[1] != "" + slot || slot < 1 || slot > SAVESLOT_COUNT)
	{
		self iprintln("Usage: ^3slot <1-" + SAVESLOT_COUNT + "> <name>");
		return true;
	}

	// Words joined by single spaces, without the characters that break the cfg
	// format (=) or colour the menu (^), cut to SAVESLOT_NAME_MAX.
	name = "";
	for(i = 2; i < words.size; i++)
	{
		word = saveslot_clean_word(words[i]);
		if(word == "") continue;
		if(name != "") name += " ";
		name += word;
	}
	if(name.size > SAVESLOT_NAME_MAX) name = getsubstr(name, 0, SAVESLOT_NAME_MAX);
	if(name.size > 0 && getsubstr(name, name.size - 1, name.size) == " ") name = getsubstr(name, 0, name.size - 1);

	saved = saveslot_get(slot);
	saved["slot_name"] = name;
	saveslot_put(slot, saved);
	if(name == "") self iprintln(level.mode.label + " Slot " + slot + " name cleared");
	else self iprintln(level.mode.label + " Slot " + slot + " renamed to " + name);
	self refresh_menu();
	return true;
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
