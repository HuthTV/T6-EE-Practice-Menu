#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;

/*##############################################################################
                              Victis maps
##############################################################################*/
// What TranZit, Die Rise and Buried share and the B2EE timer sets up for a run:
// the permaperks (persistent upgrades), the fridge and the madeup scripts that
// let fewer than four players finish the Easter egg. The settings are map-wide,
// saved in the map's basegame.cfg, and shown in the root menu "Victis Settings".
// The madeup replacefuncs name map scripts, so each map hands its own over.
// The B2EE timer does not run beside a practice tool (level.oprac_version), so
// these are the only ones in the game.

// Call from a Victis map's descriptor. fridge_default is a weapon of
// victis_fridge_options (the run's fridge on that map), madeup_install installs
// the map's madeup replacefuncs.
victis_practice_map(map, fridge_default, madeup_install)
{
    map.initialize = ::victis_initialize;
    map.base_cfg_defaults = ::victis_base_cfg_defaults;
    map.build_map_menu = ::victis_build_menu;
    map.victis_fridge_default = fridge_default;
    map.victis_madeup_install = madeup_install;
    map.character_names = array("Russman", "Stuhlinger", "Misty", "Marlton");
}

victis_base_cfg_defaults(settings_ar)
{
    settings_ar["victis_madeup"] = 1;
    settings_ar["victis_fridge_gun"] = victis_fridge_index(level.practice_map.victis_fridge_default);
    // The B2EE timer's defaults: every upgrade but Insta-Kill.
    foreach(key in victis_permaperk_keys())
        settings_ar["perma_" + key] = 1;
    settings_ar["perma_insta_kill"] = 0;
    return settings_ar;
}

// The map's initialize hook, while the map loads (before any init).
victis_initialize()
{
    if(get_cfg_int("victis_madeup"))
    {
        [[ level.practice_map.victis_madeup_install ]]();
        level thread victis_madeup_players();
    }
    level thread victis_on_player_connect();
}

// EE Progress states, the values of sq_<map>_last_completed.
#define VICTIS_EE_INCOMPLETE  0
#define VICTIS_EE_RICHTOFEN   1
#define VICTIS_EE_MAXIS       2

victis_build_menu(root)
{
    victis = add_submenu(root, "victis", "Victis Settings", "Victis");
        create_option(victis, "Madeup Scripts: " + cfgint_compare("victis_madeup"), ::victis_toggle_madeup);

        ee = add_submenu(victis, "victis_ee", "EE Progress");
            labels = array("TranZit", "Die Rise", "Buried");
            for(i = 0; i < labels.size; i++)
                create_option(ee, labels[i] + ": " + victis_ee_state_label(self victis_ee_state(i)), ::victis_ee_next, i);
            create_confirm_option(ee, "All Incomplete", "Confirm All Incomplete", ::victis_ee_set_all, VICTIS_EE_INCOMPLETE);
            create_confirm_option(ee, "All Richtofen", "Confirm All Richtofen", ::victis_ee_set_all, VICTIS_EE_RICHTOFEN);
            create_confirm_option(ee, "All Maxis", "Confirm All Maxis", ::victis_ee_set_all, VICTIS_EE_MAXIS);

        perks = add_submenu(victis, "victis_permaperks", "Permaperks");
            foreach(key in victis_permaperk_keys())
            {
                // Flopper is Buried only.
                if(!isdefined(level.pers_upgrades) || !isdefined(level.pers_upgrades[key])) continue;
                create_option(perks, victis_permaperk_label(key) + ": " + cfgint_compare("perma_" + key), ::victis_toggle_permaperk, key);
            }

        options = victis_fridge_options();
        choice = get_cfg_int("victis_fridge_gun");
        if(choice < 0 || choice >= options.weapons.size) choice = 0;
        fridge = add_submenu(victis, "victis_fridge", "Fridge: ^3" + options.labels[choice], "Fridge");
            foreach(i in victis_fridge_rows())
            {
                text = options.labels[i];
                if(i == choice) text = "^3" + text;
                create_option(fridge, text, ::victis_set_fridge, i);
            }
}

// Indexes of the options this map's fridge hands out. Built once: the menu rebuilds
// on every change.
victis_fridge_rows()
{
    if(isdefined(level.victis_fridge_shown)) return level.victis_fridge_shown;

    options = victis_fridge_options();
    rows = [];
    for(i = 0; i < options.weapons.size; i++)
        if(victis_fridge_available(options.weapons[i])) rows[rows.size] = i;
    level.victis_fridge_shown = rows;
    return rows;
}

/*##############################################################################
                              EE progress
##############################################################################*/
// The player's real saved Victis progress, the stats Buried's endgame machine reads
// and clears (user, 2026-11-06). All three maps can write all three: every stat is
// in the player's global list. A map reads them at start, so a change applies on
// restart. The rows show the stats, nothing of this is in a cfg.
//   sq_<map>_last_completed    the state below
//   navcard_applied_zm_<map>   the card went in that map's computer
//   navcard_held_zm_<map>      the card is held, not yet applied
//   sq_<map>_started           the map's computer is built
victis_ee_stat_map(index)
{
    maps = array("transit", "highrise", "buried");
    return maps[index];
}

victis_ee_state(index)
{
    return self maps\mp\zombies\_zm_stats::get_global_stat("sq_" + victis_ee_stat_map(index) + "_last_completed");
}

victis_ee_state_label(state)
{
    if(state == VICTIS_EE_RICHTOFEN) return "^4Richtofen";
    if(state == VICTIS_EE_MAXIS) return "^3Maxis";
    return "^9incomplete";
}

victis_ee_set(index, state)
{
    map = victis_ee_stat_map(index);
    done = 0;
    if(state != VICTIS_EE_INCOMPLETE) done = 1;
    self maps\mp\zombies\_zm_stats::set_global_stat("sq_" + map + "_last_completed", state);
    self maps\mp\zombies\_zm_stats::set_global_stat("navcard_applied_zm_" + map, done);
    self maps\mp\zombies\_zm_stats::set_global_stat("navcard_held_zm_" + map, 0);
    self maps\mp\zombies\_zm_stats::set_global_stat("sq_" + map + "_started", done);
}

// Menu action: the map's next state.
victis_ee_next(index)
{
    self victis_ee_set(index, (self victis_ee_state(index) + 1) % 3);
    self iprintln("EE progress applies on restart");
    self refresh_menu();
}

// Menu action.
victis_ee_set_all(state)
{
    for(i = 0; i < 3; i++)
        self victis_ee_set(i, state);
    self iprintln("EE progress applies on restart");
    self refresh_menu();
}

victis_toggle_madeup()
{
    self cfg_toggle_binary("victis_madeup");
    self iprintln("Madeup scripts apply on restart");
}

victis_toggle_permaperk(key)
{
    self cfg_toggle_binary("perma_" + key);
    self iprintln("Permaperks apply on restart");
}

// The fridge is read when it is used, so a new choice applies at once.
victis_set_fridge(choice)
{
    self cfg_set_int("victis_fridge_gun", choice);
    foreach(player in get_players())
        player victis_rig_fridge();
    self iprintln("Fridge: " + victis_fridge_options().labels[choice]);
}

victis_on_player_connect()
{
    level endon("end_game");
    while(true)
    {
        level waittill("connected", player);
        player thread victis_player_spawned();
    }
}

victis_player_spawned()
{
    self endon("disconnect");
    self waittill("spawned_player");
    self victis_apply_permaperks();
    self victis_rig_fridge();
}

/*##############################################################################
                              Permaperks
##############################################################################*/
// Upgrade names of pers_register_upgrade (zm_pers_upgrades), in menu order.
victis_permaperk_keys()
{
    return array("jugg", "flopper", "revive", "insta_kill", "double_points", "cash_back", "box_weapon", "sniper", "pistol_points", "multikill_headshots", "perk_lose", "carpenter", "board", "nube");
}

victis_permaperk_label(key)
{
    switch(key)
    {
        case "jugg":                return "Juggernog";
        case "flopper":             return "Flopper";
        case "revive":              return "Quick Revive";
        case "insta_kill":          return "Insta-Kill";
        case "double_points":       return "Half-Off";
        case "cash_back":           return "Cash Back";
        case "box_weapon":          return "Better Box";
        case "sniper":              return "Sniper Points";
        case "pistol_points":       return "Pistol Points";
        case "multikill_headshots": return "Headshots";
        case "perk_lose":           return "Tombstone";
        case "carpenter":           return "Carpenter";
        case "board":               return "Boards";
        case "nube":                return "Nube";
    }
    return key;
}

// As the B2EE timer's upgrades_bank: every stat of an upgrade is set to the
// value that earns it (on) or to 0 (off). pers_upgrades_monitor gives or takes
// the upgrade on its next pass, silently before the black screen ends.
victis_apply_permaperks()
{
    if(!isdefined(level.pers_upgrades)) return;
    foreach(key in victis_permaperk_keys())
    {
        upgrade = level.pers_upgrades[key];
        if(!isdefined(upgrade)) continue;
        on = get_cfg_int("perma_" + key) != 0;
        for(i = 0; i < upgrade.stat_names.size; i++)
            self maps\mp\zombies\_zm_stats::set_client_stat(upgrade.stat_names[i], on * upgrade.stat_desired_values[i]);
    }
}

/*##############################################################################
                              Fridge
##############################################################################*/
// Every weapon of the B2EE timer's fridge_list.md. The saved value is the index:
// keep the order and add new weapons at the end. The menu lists the ones the
// fridge hands out on this map (victis_fridge_available). Built once.
victis_fridge_options()
{
    if(isdefined(level.victis_fridge_list)) return level.victis_fridge_list;

    options = spawnstruct();
    options.weapons = [];
    options.labels = [];
    victis_add_option(options, "", "untouched");
    victis_add_option(options, "none", "empty");
    // Snipers first (user, 2026-11-05).
    victis_add_gun(options, "svu", "SVU", array("vzoom"));
    victis_add_gun(options, "dsr50", "DSR 50", array("is", "silencer", "vzoom"));
    victis_add_gun(options, "barretm82", "Barrett M82A1", array("vzoom"));
    victis_add_gun(options, "870mcs", "Remington 870", array("extbarrel", "reflex"));
    victis_add_gun(options, "ak74u", "AK74u", array("reflex"));
    victis_add_gun(options, "an94", "AN-94", array("grip", "mms", "rangefinder", "reflex"));
    victis_add_gun(options, "beretta93r", "B23R", array("dualclip", "extbarrel"));
    victis_add_gun(options, "fiveseven", "Five-seven", array("dualclip", "extbarrel"));
    victis_add_gun(options, "fivesevendw", "Five-seven DW");
    victis_add_gun(options, "fnfal", "FAL", array("reflex"));
    victis_add_gun(options, "galil", "Galil", array("reflex"));
    victis_add_gun(options, "hamr", "HAMR", array("acog", "grip", "reflex"));
    victis_add_gun(options, "judge", "Executioner", array("dualclip_judge", "extbarrel"));
    victis_add_gun(options, "kard", "KAP-40", array("dualclip", "extbarrel"));
    victis_add_gun(options, "lsat", "LSAT", array("acog", "grip", "rangefinder", "reflex"));
    victis_add_gun(options, "m14", "M14");
    victis_add_option(options, "m16_zm", "M16");
    victis_add_option(options, "m16_gl_upgraded_zm", "M16 PaP");
    victis_add_gun(options, "m32", "War Machine");
    victis_add_gun(options, "mp5k", "MP5");
    victis_add_gun(options, "pdw57", "PDW-57", array("mms", "rangefinder", "reflex"));
    victis_add_gun(options, "python", "Python");
    victis_add_gun(options, "qcw05", "Chicom", array("dualclip", "grip", "reflex", "sf"));
    victis_add_gun(options, "rpd", "RPD");
    victis_add_gun(options, "rnma", "Remington");
    victis_add_gun(options, "rottweil72", "Olympia");
    victis_add_gun(options, "saiga12", "S12", array("extbarrel", "reflex"));
    victis_add_gun(options, "saritch", "SMR", array("dualoptic", "mms", "rangefinder", "reflex"));
    victis_add_gun(options, "srm1216", "M1216", array("extbarrel", "reflex"));
    victis_add_gun(options, "tar21", "MTAR", array("gl", "longbreath", "mms", "rangefinder", "reflex"));
    victis_add_gun(options, "type95", "Type 25", array("gl", "longbreath", "mms", "rangefinder", "reflex"));
    victis_add_gun(options, "usrpg", "RPG");
    victis_add_gun(options, "xm8", "M8A1", array("gl", "longbreath", "mms", "rangefinder", "reflex"));
    level.victis_fridge_list = options;
    return options;
}

// A gun and its PaP versions: one with no attachment list, else one per attachment
// (the attachment shows in the label only when there is a choice).
victis_add_gun(options, gun, label, attachments)
{
    victis_add_option(options, gun + "_zm", label);
    if(!isdefined(attachments))
    {
        victis_add_option(options, gun + "_upgraded_zm", label + " PaP");
        return;
    }
    foreach(attachment in attachments)
    {
        text = label + " PaP";
        if(attachments.size > 1) text += " (" + victis_attachment_label(attachment) + ")";
        victis_add_option(options, gun + "_upgraded_zm+" + attachment, text);
    }
}

victis_attachment_label(attachment)
{
    switch(attachment)
    {
        case "acog":            return "ACOG";
        case "dualclip":
        case "dualclip_judge":  return "Fast Mags";
        case "dualoptic":       return "Hybrid";
        case "extbarrel":       return "Long Barrel";
        case "gl":              return "GL";
        case "grip":            return "Grip";
        case "is":              return "Iron Sights";
        case "longbreath":      return "Long Breath";
        case "mms":             return "MMS";
        case "rangefinder":     return "Target Finder";
        case "reflex":          return "Reflex";
        case "sf":              return "Select Fire";
        case "silencer":        return "Suppressor";
        case "vzoom":           return "Variable Zoom";
    }
    return attachment;
}

victis_add_option(options, value, label)
{
    options.weapons[options.weapons.size] = value;
    options.labels[options.labels.size] = label;
}

// Index of weapon in victis_fridge_options, 0 (untouched) if it is not there.
victis_fridge_index(weapon)
{
    options = victis_fridge_options();
    for(i = 0; i < options.weapons.size; i++)
        if(options.weapons[i] == weapon) return i;
    return 0;
}

// The fridge gives a stored weapon back only if the map includes it and it is
// not limited (zm_weapon_locker triggerweaponslockerisvalidweapon). A weapon of
// another Victis map that this map swaps for its own (add_weapon_locker_mapping)
// is left out as well.
victis_fridge_available(weapon)
{
    if(weapon == "" || weapon == "none") return true;
    parts = strtok(weapon, "+");
    if(isdefined(level.remap_weapon_locker_weapons) && isdefined(level.remap_weapon_locker_weapons[parts[0]])) return false;
    base = maps\mp\zombies\_zm_weapons::get_base_weapon_name(parts[0], 1);
    return maps\mp\zombies\_zm_weapons::is_weapon_included(base) && !is_limited_weapon(base);
}

// The chosen weapon, "none" for empty, undefined for untouched.
victis_fridge_weapon()
{
    options = victis_fridge_options();
    choice = get_cfg_int("victis_fridge_gun");
    if(choice <= 0 || choice >= options.weapons.size) return undefined;
    return options.weapons[choice];
}

// The fridge reads the weaponLocker stats of level.weapon_locker_map (zm_transit
// on every Victis map) in an online game, else self.stored_weapon_data
// (zm_weapon_locker wl_* functions). Both are set, the stats as the B2EE timer's
// player_rig_fridge does. Ammo is full.
victis_rig_fridge()
{
    weapon = victis_fridge_weapon();
    if(!isdefined(weapon)) return;

    locker_map = "zm_transit";
    if(isdefined(level.weapon_locker_map)) locker_map = level.weapon_locker_map;
    if(weapon == "none")
    {
        self maps\mp\zombies\_zm_stats::clear_stored_weapondata(locker_map);
        self.stored_weapon_data = undefined;
        return;
    }

    wpn = [];
    wpn["name"] = weapon;
    wpn["clip"] = weaponclipsize(weapon);
    wpn["stock"] = weaponmaxammo(weapon);
    dw_name = weapondualwieldweaponname(weapon);
    alt_name = weaponaltweaponname(weapon);
    wpn["lh_clip"] = 0;
    if(dw_name != "none") wpn["lh_clip"] = weaponclipsize(dw_name);
    wpn["alt_clip"] = 0;
    wpn["alt_stock"] = 0;
    if(alt_name != "none")
    {
        wpn["alt_clip"] = weaponclipsize(alt_name);
        wpn["alt_stock"] = weaponmaxammo(alt_name);
    }

    self maps\mp\zombies\_zm_stats::set_stored_weapondata(wpn, locker_map);
    self.stored_weapon_data = wpn;
    println("Prac: fridge " + weapon + " clip " + wpn["clip"] + " stock " + wpn["stock"]);
}

/*##############################################################################
                              Madeup scripts
##############################################################################*/
// As the B2EE timer's madeup_replaces: the map's nav card counts as built and
// applied, and level.starting_player_count (vanilla never sets it) holds the
// player count the map's madeup scripts scale to.
victis_madeup_players()
{
    flag_wait("initial_players_connected");
    map = getsubstr(level.script, 3);
    stats = array("sq_" + map + "_started", "navcard_applied_zm_" + map);
    foreach(player in get_players())
    {
        foreach(stat in stats)
        {
            if(player maps\mp\zombies\_zm_stats::get_global_stat(stat)) continue;
            player maps\mp\gametypes_zm\_globallogic_score::initpersstat(stat, 0);
            player maps\mp\zombies\_zm_stats::increment_client_stat(stat, 0);
        }
    }
    level.starting_player_count = get_players().size;
}

/*##############################################################################
                              Forced box guns
##############################################################################*/
// With the Better Box permaperk vanilla picks from the upgrade's own list and never
// reaches level.customrandomweaponweights, where a mode forces its guns. A mode hands
// over due_func, which returns the gun due on this hit or undefined. A forced hit
// then takes the normal path, the other hits run the upgrade as vanilla.
victis_box_install(due_func)
{
    level.victis_box_due = due_func;
    replacefunc(maps\mp\zombies\_zm_pers_upgrades_functions::pers_treasure_chest_choosespecialweapon, ::victis_pers_choose_weapon);
}

// The hit about to be rolled on the first box, 0 once the box has moved. A hit counts
// when it ends, so level.chest_accessed is the hits before this one.
victis_box_hit()
{
    if(level.chest_moves > 0) return 0;
    return level.chest_accessed + 1;
}

// OVERRIDE: maps\mp\zombies\_zm_pers_upgrades_functions::pers_treasure_chest_choosespecialweapon
victis_pers_choose_weapon( player )
{
    //MODIFIED: a forced hit skips the upgrade's list.
    if ( isdefined( [[ level.victis_box_due ]]() ) )
        return maps\mp\zombies\_zm_magicbox::treasure_chest_chooseweightedrandomweapon( player );
    //MODIFIED END

    rval = randomfloat( 1 );

    if ( !isdefined( player.pers_magic_box_weapon_count ) )
        player.pers_magic_box_weapon_count = 0;

    if ( player.pers_magic_box_weapon_count < 2 && ( player.pers_magic_box_weapon_count == 0 || rval < 0.6 ) )
    {
        player.pers_magic_box_weapon_count++;

        if ( isdefined( level.pers_treasure_chest_get_weapons_array_func ) )
            [[ level.pers_treasure_chest_get_weapons_array_func ]]();
        else
            maps\mp\zombies\_zm_pers_upgrades_functions::pers_treasure_chest_get_weapons_array();

        keys = array_randomize( level.pers_box_weapons );
        pap_triggers = getentarray( "specialty_weapupgrade", "script_noteworthy" );

        for ( i = 0; i < keys.size; i++ )
        {
            if ( maps\mp\zombies\_zm_magicbox::treasure_chest_canplayerreceiveweapon( player, keys[i], pap_triggers ) )
                return keys[i];
        }

        return keys[0];
    }

    player.pers_magic_box_weapon_count = 0;
    return maps\mp\zombies\_zm_magicbox::treasure_chest_chooseweightedrandomweapon( player );
}

/*##############################################################################
                              Held Max Ammo
##############################################################################*/
// Keeps a Max Ammo for a moment of the run: while the cfg setting key is on, the Max
// is the last drop of the cycle, so it is always still ahead. victis_max_release
// moves it up to the current place, so it is the next drop. Call install while the
// map loads and victis_max_hold from the mode's run.
victis_max_install(key)
{
    level.victis_max_key = key;
    replacefunc(maps\mp\zombies\_zm_powerups::randomize_powerups, ::victis_randomize_powerups);
}

victis_max_held()
{
    return isdefined(level.victis_max_key) && !is_true(level.victis_max_done) && get_cfg_int(level.victis_max_key);
}

// Late maps add powerups after the first shuffle, so a mode's run places it again.
victis_max_hold()
{
    if(victis_max_held()) victis_place_max(false);
}

// final: no more moments to hold it for.
victis_max_release(final)
{
    if(is_true(final)) level.victis_max_done = true;
    if(!get_cfg_int(level.victis_max_key)) return;
    victis_place_max(true);
    println("Prac: Max Ammo is the next drop");
}

// OVERRIDE: maps\mp\zombies\_zm_powerups::randomize_powerups
victis_randomize_powerups()
{
    level.zombie_powerup_array = array_randomize( level.zombie_powerup_array );

    //MODIFIED: the first shuffles run before the index exists.
    if ( isdefined( level.zombie_powerup_index ) && victis_max_held() )
        victis_place_max( false );
    //MODIFIED END
}

// Takes the Max out of the cycle and puts it next (is_next) or last. The other drops
// keep their order, and the index keeps pointing at the same next drop.
victis_place_max(is_next)
{
    next = level.zombie_powerup_index;
    rest = [];
    found = false;
    for(i = 0; i < level.zombie_powerup_array.size; i++)
    {
        if(level.zombie_powerup_array[i] != "full_ammo")
        {
            rest[rest.size] = level.zombie_powerup_array[i];
            continue;
        }
        found = true;
        if(i < next) next--;
    }
    if(!found) return;

    place = rest.size;
    if(is_next) place = next;

    cycle = [];
    for(i = 0; i < rest.size; i++)
    {
        if(i == place) cycle[cycle.size] = "full_ammo";
        cycle[cycle.size] = rest[i];
    }
    if(place == rest.size) cycle[cycle.size] = "full_ammo";

    level.zombie_powerup_array = cycle;
    level.zombie_powerup_index = next;
}
