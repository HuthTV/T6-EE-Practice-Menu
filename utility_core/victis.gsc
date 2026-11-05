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
}

victis_base_cfg_defaults(settings_ar)
{
    settings_ar["victis_madeup"] = 1;
    settings_ar["victis_fridge"] = victis_fridge_index(level.practice_map.victis_fridge_default);
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

victis_build_menu(root)
{
    victis = add_submenu(root, "victis", "Victis Settings", "Victis");
        create_option(victis, "Madeup scripts: " + cfgint_compare("victis_madeup", "^2on", "^1off"), ::victis_toggle_madeup);

        perks = add_submenu(victis, "victis_permaperks", "Permaperks");
            foreach(key in victis_permaperk_keys())
            {
                // Flopper is Buried only.
                if(!isdefined(level.pers_upgrades) || !isdefined(level.pers_upgrades[key])) continue;
                create_option(perks, victis_permaperk_label(key) + ": " + cfgint_compare("perma_" + key, "^2on", "^1off"), ::victis_toggle_permaperk, key);
            }

        options = victis_fridge_options();
        choice = get_cfg_int("victis_fridge");
        if(choice < 0 || choice >= options.weapons.size) choice = 0;
        fridge = add_submenu(victis, "victis_fridge", "Fridge: ^3" + options.labels[choice], "Fridge");
            for(i = 0; i < options.weapons.size; i++)
            {
                if(!victis_fridge_available(options.weapons[i])) continue;
                text = options.labels[i];
                if(i == choice) text = "^3" + text;
                create_option(fridge, text, ::victis_set_fridge, i);
            }
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
    self cfg_set_int("victis_fridge", choice);
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
// Weapons from the B2EE timer's fridge_list.md. The saved value is the index:
// keep the order and add new weapons at the end. The menu lists the ones the
// fridge hands out on this map (victis_fridge_available).
victis_fridge_options()
{
    options = spawnstruct();
    options.weapons = [];
    options.labels = [];
    victis_add_option(options, "", "untouched");
    victis_add_option(options, "none", "empty");
    victis_add_option(options, "usrpg_upgraded_zm", "RPG PaP");
    victis_add_option(options, "svu_zm", "SVU");
    victis_add_option(options, "svu_upgraded_zm+vzoom", "SVU PaP");
    victis_add_option(options, "tar21_upgraded_zm+mms", "MTAR PaP (MMS)");
    victis_add_option(options, "tar21_upgraded_zm+reflex", "MTAR PaP (reflex)");
    victis_add_option(options, "mp5k_zm", "MP5");
    victis_add_option(options, "mp5k_upgraded_zm", "MP5 PaP");
    victis_add_option(options, "an94_upgraded_zm+mms", "AN-94 PaP (MMS)");
    victis_add_option(options, "galil_upgraded_zm+reflex", "Galil PaP");
    victis_add_option(options, "saritch_upgraded_zm+mms", "SMR PaP (MMS)");
    victis_add_option(options, "hamr_upgraded_zm+reflex", "HAMR PaP");
    victis_add_option(options, "rpd_upgraded_zm", "RPD PaP");
    victis_add_option(options, "m32_upgraded_zm", "War Machine PaP");
    victis_add_option(options, "rnma_upgraded_zm", "Remington PaP");
    victis_add_option(options, "pdw57_upgraded_zm+mms", "PDW-57 PaP (MMS)");
    victis_add_option(options, "type95_upgraded_zm+mms", "Type 25 PaP (MMS)");
    victis_add_option(options, "xm8_upgraded_zm+mms", "M8A1 PaP (MMS)");
    return options;
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
    choice = get_cfg_int("victis_fridge");
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
